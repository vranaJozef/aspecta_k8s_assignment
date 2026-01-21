#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

CLUSTER_NAME="webapp-cluster"

log() {
    local level=$1
    shift
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $*"
}

# Resolve the repository root (assumes this script is in scripts/)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

delete_dependencies() {
    log "INFO" "Deleting application resources (namespaces: webapp, argocd, monitoring)..."
    
    # Delete ArgoCD App to remove finalizers
    kubectl delete application webapp -n argocd --ignore-not-found
    
    # Uninstall known helm releases 
    log "INFO" "Uninstalling Helm releases..."
    helm uninstall webapp -n webapp 2>/dev/null || true
    helm uninstall argocd -n argocd 2>/dev/null || true
    helm uninstall prometheus -n monitoring 2>/dev/null || true
    
    log "INFO" "Deleting namespaces..."
    kubectl delete ns webapp argocd monitoring --ignore-not-found
    
    log "INFO" "Resources deleted successfully."
}

delete_cluster() {
    log "INFO" "Deleting Kind cluster '$CLUSTER_NAME'..."
    kind delete cluster --name "$CLUSTER_NAME"
    log "INFO" "Cluster deleted successfully."
}

show_menu() {
    echo "========================================="
    echo "   Webapp Environment Cleanup"
    echo "========================================="
    echo "1. Delete Resources Only (Keep Cluster)"
    echo "2. Delete Entire Cluster (Full Reset)"
    echo "3. Cancel"
    echo "========================================="
    read -rp "Select option [1-3]: " option
    
    case $option in
        1) delete_dependencies ;;
        2) delete_cluster ;;
        3) log "INFO" "Cancelled by user."; exit 0 ;;
        *) log "ERROR" "Invalid option selected."; exit 1 ;;
    esac
}

main() {
    log "WARN" "This script can effectively remove your entire local environment."
    show_menu
}

main
