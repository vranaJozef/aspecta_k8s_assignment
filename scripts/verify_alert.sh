#!/bin/bash
set -e

PROMETHEUS_PORT=9091
ALERT_NAME="WebappDeploymentReplicasMismatch"

echo "Starting Simple Alert Verification..."

echo "Setting up Prometheus port-forward on $PROMETHEUS_PORT..."
pkill -f "port-forward.*$PROMETHEUS_PORT" || true
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus $PROMETHEUS_PORT:9090 >/dev/null 2>&1 &
PF_PID=$!
trap "kill $PF_PID 2>/dev/null" EXIT
sleep 3 # Wait for connection

# Trigger Alert (Break the deployment)
echo "Triggering Alert: $ALERT_NAME..."
# Disable ArgoCD sync temporarily
kubectl patch application webapp -n argocd --type=merge -p '{"spec":{"syncPolicy":{"automated":null}}}'
# Patch maxUnavailable to 1 to ensure we can drop availability
kubectl patch deployment backend -n webapp -p '{"spec":{"strategy":{"rollingUpdate":{"maxUnavailable":1}}}}'
# Break the image
kubectl set image deployment/backend backend=webapp-backend:broken-tag -n webapp
echo "Waiting for deployment to degrade..."
sleep 5
echo "Deleting one pod to force availability drop..."
kubectl delete pod -n webapp -l app.kubernetes.io/name=backend --field-selector=status.phase=Running --wait=false | head -1
sleep 10 # Wait for K8s to update status

# Verify Alert in Prometheus
echo "Verifying Alert in Prometheus..."
START_TIME=$(date +%s)
TIMEOUT=120

while true; do
    ALERTS=$(curl -s http://localhost:$PROMETHEUS_PORT/api/v1/alerts)
    # Check if we have our specific alert in 'pending' or 'firing' state
    COUNT=$(echo "$ALERTS" | jq -r ".data.alerts[] | select(.labels.alertname == \"$ALERT_NAME\") | .state" | grep -E "pending|firing" | wc -l)
    
    if [ "$COUNT" -gt "0" ]; then
        STATUS=$(echo "$ALERTS" | jq -r ".data.alerts[] | select(.labels.alertname == \"$ALERT_NAME\") | .state" | head -1)
        echo "✅ SUCCESS: Alert '$ALERT_NAME' detected! Status: $STATUS"
        break
    fi

    CURRENT_TIME=$(date +%s)
    if [ $((CURRENT_TIME - START_TIME)) -gt $TIMEOUT ]; then
        echo "FAILURE: Alert not detected within $TIMEOUT seconds."
        exit 1
    fi
    echo "   ...waiting for alert ($((CURRENT_TIME - START_TIME))s)"
    sleep 5
done

echo "Cleaning up..."
# Force ArgoCD to use 'latest' tag (local) instead of what's in Git to avoid ImagePullBackOff
kubectl patch application webapp -n argocd --type=merge -p '{"spec":{"source":{"helm":{"parameters":[{"name":"backend.image.tag","value":"latest"}]}}}}'

# Re-enable ArgoCD (will fix the image automatically)
kubectl patch application webapp -n argocd --type=merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'

echo "Waiting for cluster to heal..."
kubectl rollout status deployment/backend -n webapp --timeout=60s

echo "Done."
exit 0
