#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

CLUSTER_NAME="webapp-cluster"
GIT_SHA=$(git rev-parse --short HEAD)

log() {
    local level=$1
    shift
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $*"
}

# Resolve the repository root (assumes this script is in scripts/)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

check_dependencies() {
    log "INFO" "Checking system dependencies..."
    local deps=("kind" "kubectl" "helm" "docker")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            log "ERROR" "$dep is required but not installed."
            exit 1
        fi
    done
}

create_cluster() {
    log "INFO" "Ensuring Kind cluster '$CLUSTER_NAME' exists..."
    if kind get clusters | grep -q "^$CLUSTER_NAME$"; then
        log "INFO" "Cluster already exists."
    else
        kind create cluster --config "$REPO_ROOT/k8s/kind-config.yaml" --name "$CLUSTER_NAME"
    fi
}

install_ingress() {
    log "INFO" "Installing Nginx Ingress Controller..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    
    log "INFO" "Waiting for Ingress Controller readiness..."
    kubectl wait --namespace ingress-nginx \
      --for=condition=available deployment/ingress-nginx-controller \
      --timeout=300s
}

build_and_load_images() {
    log "INFO" "Building and loading Docker images..."
    local apps=("backend" "frontend")
    for app in "${apps[@]}"; do
        log "INFO" "Processing $app..."
        docker build -t "webapp-$app:$GIT_SHA" "$REPO_ROOT/apps/$app/"
        kind load docker-image "webapp-$app:$GIT_SHA" --name "$CLUSTER_NAME"
    done
}

install_monitoring() {
    log "INFO" "Installing Prometheus Stack..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update >/dev/null
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
      --namespace monitoring \
      --create-namespace \
      --values "$REPO_ROOT/k8s/monitoring/lightweight-values.yaml" \
      --wait

    log "INFO" "Applying Alertmanager Configuration..."
    kubectl apply -f "$REPO_ROOT/k8s/monitoring/alertmanager-config.yaml"
}

install_argocd() {
    log "INFO" "Installing ArgoCD..."
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    log "INFO" "Waiting for ArgoCD Server readiness..."
    kubectl wait --namespace argocd \
      --for=condition=ready pod \
      --selector=app.kubernetes.io/name=argocd-server \
      --timeout=300s
    
    kubectl apply -f "$REPO_ROOT/k8s/gitops/argocd-application.yaml"
}

deploy_app() {
    log "INFO" "Deploying Application via Helm..."
    helm upgrade --install webapp "$REPO_ROOT/charts/webapp-chart" \
        --namespace webapp \
        --create-namespace \
        --set backend.image.pullPolicy=IfNotPresent \
        --set frontend.image.pullPolicy=IfNotPresent \
        --set backend.image.tag=$GIT_SHA \
        --set frontend.image.tag=$GIT_SHA
}

apply_monitoring_rules() {
    log "INFO" "Applying Application Monitoring Rules..."
    # Applies rules to the 'webapp' namespace, which now exists after deploy_app
    kubectl apply -f "$REPO_ROOT/k8s/monitoring/prometheusrule.yaml"
}

main() {
    check_dependencies
    create_cluster
    install_ingress
    # build_and_load_images
    install_monitoring
    install_argocd
    deploy_app
    apply_monitoring_rules
    
    log "INFO" "Setup Complete!"
    echo "---------------------------------------------------"
    echo "Configuration Required:"
    echo "  Add '127.0.0.1 webapp.local' to your /etc/hosts file."    
    echo "  Access URL: http://webapp.local:8081"    
    echo ""
    echo "Alternative Access:"
    echo "  kubectl port-forward -n webapp svc/frontend 8080:8080"
    echo "  Then open: http://localhost:8080"
    echo "---------------------------------------------------"
}

main
