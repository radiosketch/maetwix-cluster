#!/bin/bash
set -e

echo "?? Bootstrapping Maetwix Cluster..."

# 1. Install ArgoCD
echo "?? Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 2. Wait for ArgoCD
echo "? Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=600s \
  deployment/argocd-server -n argocd

# 3. Get admin password
echo "?? ArgoCD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo ""
echo ""

# 4. Apply root application
echo "?? Deploying root application..."
kubectl apply -f bootstrap/argocd/root-app.yaml

echo "? Bootstrap complete!"
echo ""
echo "Access ArgoCD:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  Then visit: https://localhost:8080"
echo "  Username: admin"
echo "  Password: (shown above)"
