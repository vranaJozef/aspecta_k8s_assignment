# Webapp - Kubernetes Environment

Web application deployed on Kubernetes with features including scalability, security, monitoring, and automated deployment.

## 🏗 Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Ingress (Nginx)                             │
│                      webapp.local                               │
└───────────────────────────┬─────────────────────────────────────┘
                            │
          ┌─────────────────┴─────────────────┐
          │                                   │
          ▼                                   ▼
┌─────────────────┐                 ┌─────────────────┐
│    Frontend     │                 │     Backend     │
│  (Nginx:8080)   │────────────────▶│   (Flask:5000)  │
│   ClusterIP     │                 │    ClusterIP    │
└─────────────────┘                 └────────┬────────┘
                                             │
                                             ▼
                                    ┌─────────────────┐
                                    │   Prometheus    │
                                    │    /metrics     │
                                    └─────────────────┘
```

### Components
- **Frontend**: Nginx serving static HTML/JS and API calls to Backend
- **Backend**: Python Flask API with health/readiness probes and metrics
- **Ingress**: Nginx Ingress Controller for external access
- **HPA**: Horizontal Pod Autoscaler for both tiers
- **Monitoring**: Prometheus Stack with ServiceMonitors and Alertmanager rules
- **GitOps**: ArgoCD for continuous delivery

## 📁 Project Structure

```
.
├── apps/
│   ├── backend/         # Python Flask API
│   └── frontend/        # Nginx static server
├── charts/
│   └── webapp-chart/    # Helm chart
├── k8s/
│   ├── security/        # RBAC, NetworkPolicies
│   ├── monitoring/      # ServiceMonitor, PrometheusRule
│   └── gitops/          # ArgoCD Application
├── scripts/
│   ├── setup.sh         # One-command environment setup
│   ├── cleanup.sh       # Cleanup utility
│   └── verify_alert.sh  # Automated alert verification
├── .github/
│   └── workflows/       # CI/CD pipeline
├── Makefile             # Main entry point for commands
└── README.md
```

## 🚀 Quick Start

### Prerequisites
- Docker
- kubectl
- Helm 3.x
- Kind (Kubernetes in Docker)

### 1. Automated Setup
The entire environment (Cluster -> Ingress -> Apps -> Prometheus -> ArgoCD) is set up with a single command:

```bash
make setup
```

### 2. Access the Application
Once setup is complete:
- **URL**: http://webapp.local:8081
- **API**: http://webapp.local:8081/api
- **Prometheus**: http://localhost:9090 (requires port-forward)
- **ArgoCD**: http://localhost:8080 (requires port-forward)

*Note: Ensure `127.0.0.1 webapp.local` is in your `/etc/hosts`. Without it, use:*
```bash
kubectl port-forward -n webapp svc/frontend 8080:8080
Access at http://localhost:8080
```

### 3. Automated Verification & Alerting
To verify that the system is resilient and alerts are working (this will intentionally disrupt the cluster):

```bash
make verify_alert
```

### 4. Cleanup
To remove the cluster or specific resources:

```bash
make clean
```

## 🔒 Security Features

### RBAC
Two roles defined with least privilege:
- **webapp-monitor**: Read-only access for monitoring
- **webapp-deployer**: Deploy permissions for CI/CD

### NetworkPolicies
- Default deny all ingress/egress.
- Selective allow for Frontend→Backend communication.
- Prometheus scraping allowed from monitoring namespace.

### Container Security
- Non-root users in all containers.
- Read-only root filesystem (where possible).
- Dropped Linux capabilities.
- Seccomp profiles enabled.

## 📊 Monitoring

Prometheus stack is installed automatically.

**Alerts Configured:**
| Alert | Severity | Description |
|-------|----------|-------------|
| WebappPodDown | Critical | Pod is down for >1min |
| WebappHighCPU | Warning | CPU >80% for >5min |
| WebappHighMemory | Warning | Memory >80% for >5min |
| WebappPodRestarting | Warning | >3 restarts in 1 hour |
| WebappDeploymentReplicasMismatch | Warning | Desired != Available replicas |

## 🔄 CI/CD & GitOps

### GitHub Actions Pipeline
Located in `.github/workflows/ci-cd.yaml`:
1. **Lint**: Hadolint for Dockerfiles, Helm lint for charts.
2. **Build**: Multi-stage Docker builds.
3. **Push**: Push to GitHub Container Registry (ghcr.io).
4. **Update Chart**: Auto-update image tags in values.yaml.

### ArgoCD
ArgoCD is installed and configured to sync the `webapp` application from the Helm chart in this repository.
- **Sync Policy**: Automated (Prune, SelfHeal).
- **Note**: Auto-sync is temporarily disabled by `verify_alert.sh` during testing.

## 📝 License

MIT
