# Maetwix Matrix Cluster

Distributed, high-availability Matrix homeserver using k3s, Patroni PostgreSQL, and GitOps.

## Architecture

- **3+ node k3s cluster** across multiple physical locations
- **Patroni PostgreSQL cluster** with streaming replication
- **etcd** for distributed coordination
- **Synapse** Matrix homeserver (replicated)
- **Element Web** frontend
- **ArgoCD** for GitOps deployment
- **Tailscale** mesh networking between sites
- **Cloudflare** load balancing and tunnels

## Quick Start for New Node

```bash
curl -fsSL https://setup.maetwix.org/join.sh | bash -s <location-name>
```

Replace `<location-name>` with your city/identifier (e.g., `chicago`, `berlin`)

## Manual Setup

### Prerequisites (per node)
- Ubuntu 22.04 or Debian 12
- 4+ CPU cores
- 8GB+ RAM
- 100GB+ SSD storage
- Stable internet connection

### 1. Initial Cluster Setup (First Node Only)

```bash
# Install k3s as first server
curl -sfL https://get.k3s.io | sh -s - server \
  --disable traefik \
  --write-kubeconfig-mode 644

# Save the node token
sudo cat /var/lib/rancher/k3s/server/node-token

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up
```

### 2. Bootstrap ArgoCD

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f bootstrap/argocd/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Install root application (deploys everything else)
kubectl apply -f bootstrap/argocd/root-app.yaml
```

### 3. Add Additional Nodes

On new node:
```bash
# Get K3S_URL and K3S_TOKEN from first node
curl -sfL https://get.k3s.io | K3S_URL=https://<first-node-ip>:6443 \
  K3S_TOKEN=<token-from-step-1> \
  sh -s - agent

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up --authkey=<your-authkey>

# Label node
kubectl label node $(hostname) topology.kubernetes.io/zone=<location>
```

## Repository Structure

- `bootstrap/` - Initial cluster setup (ArgoCD, Sealed Secrets)
- `infrastructure/` - Core services (etcd, PostgreSQL, Redis)
- `applications/` - Matrix stack (Synapse, Element Web)
- `networking/` - Ingress, certificates
- `monitoring/` - Prometheus, Grafana
- `scripts/` - Helper scripts

## Configuration

### Secrets Management

We use Sealed Secrets for GitOps-friendly secret management:

```bash
# Create a secret
kubectl create secret generic synapse-secrets \
  --from-literal=registration-secret=<random> \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > infrastructure/postgresql/sealed-secret.yaml
```

### Customization

Edit `infrastructure/postgresql/postgres-cluster.yaml` to adjust:
- Number of replicas
- Storage size
- Resource limits

Edit `applications/synapse/homeserver.yaml` for Matrix configuration.

## Monitoring

Access Grafana:
```bash
kubectl port-forward -n monitoring svc/grafana 3000:80
```

Default credentials: admin / (get from sealed secret)

## Backup & Recovery

### Database Backup

```bash
# Manual backup
./scripts/backup-db.sh

# Backups stored in S3-compatible storage
```

### Disaster Recovery

If a node goes down:
1. Patroni automatically promotes a replica to primary
2. ArgoCD re-deploys failed pods to healthy nodes
3. Cloudflare removes unhealthy origin from load balancer

## Troubleshooting

### Check cluster status
```bash
kubectl get nodes
kubectl get pods -A
```

### Check PostgreSQL cluster
```bash
kubectl get postgresql -n matrix
kubectl exec -n matrix synapse-postgres-0 -- patronictl list
```

### Check ArgoCD sync status
```bash
argocd app list
argocd app get <app-name>
```

### Check etcd cluster
```bash
kubectl exec -n infrastructure etcd-0 -- etcdctl member list
```

## Maintenance

### Update Synapse version
Edit `applications/synapse/kustomization.yaml`:
```yaml
images:
  - name: matrixdotorg/synapse
    newTag: v1.99.0  # Update version here
```

Commit and push - ArgoCD auto-deploys.

### Update PostgreSQL
```bash
kubectl edit postgresql synapse-postgres -n matrix
# Update spec.postgresql.version
```

## Contributing

When adding new features:
1. Create feature branch
2. Test changes in staging
3. Submit PR
4. Auto-deploys after merge to main

## Security

- All secrets encrypted with Sealed Secrets
- Tailscale mesh for inter-node communication
- PostgreSQL traffic encrypted (TLS)
- Regular automated backups
- RBAC enforced

## License

MIT

## Support

Questions? Open an issue or contact admin@maetwix.org
