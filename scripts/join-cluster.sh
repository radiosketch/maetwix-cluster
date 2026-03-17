#!/bin/bash
set -e

# Maetwix Matrix Cluster - Node Join Script
# Usage: curl -fsSL https://setup.maetwix.org/join.sh | bash -s <location-name>

LOCATION=${1:-""}
REPO_URL="https://github.com/radiosketch/maetwix-cluster.git"  # CHANGE THIS

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Maetwix Matrix Cluster - Node Join Script${NC}"
echo "=============================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}Please run as root (use sudo)${NC}"
  exit 1
fi

# Get location name
if [ -z "$LOCATION" ]; then
  read -p "Enter location name (e.g., chicago, berlin): " LOCATION
fi

if [ -z "$LOCATION" ]; then
  echo -e "${RED}Location name is required${NC}"
  exit 1
fi

echo -e "${GREEN}📍 Location: $LOCATION${NC}"

# Get cluster join credentials
if [ -z "$K3S_URL" ] || [ -z "$K3S_TOKEN" ]; then
  echo ""
  echo -e "${YELLOW}Cluster join credentials needed.${NC}"
  echo "Get these from the cluster admin or first node:"
  echo ""
  read -p "K3S_URL (e.g., https://main.maetwix.org:6443): " K3S_URL
  read -p "K3S_TOKEN: " K3S_TOKEN
fi

if [ -z "$K3S_URL" ] || [ -z "$K3S_TOKEN" ]; then
  echo -e "${RED}K3S_URL and K3S_TOKEN are required${NC}"
  exit 1
fi

# Get Tailscale auth key
if [ -z "$TS_AUTHKEY" ]; then
  echo ""
  echo -e "${YELLOW}Tailscale auth key needed.${NC}"
  echo "Get this from: https://login.tailscale.com/admin/settings/keys"
  echo ""
  read -p "Tailscale auth key: " TS_AUTHKEY
fi

if [ -z "$TS_AUTHKEY" ]; then
  echo -e "${RED}Tailscale auth key is required${NC}"
  exit 1
fi

echo ""
echo -e "${GREEN}✓ All credentials provided${NC}"
echo ""

# Update system
echo -e "${GREEN}📦 Updating system packages...${NC}"
apt-get update -qq
apt-get upgrade -y -qq

# Install prerequisites
echo -e "${GREEN}📦 Installing prerequisites...${NC}"
apt-get install -y -qq curl wget git jq

# Install k3s
echo -e "${GREEN}🐳 Installing k3s...${NC}"
curl -sfL https://get.k3s.io | K3S_URL="$K3S_URL" \
  K3S_TOKEN="$K3S_TOKEN" \
  INSTALL_K3S_EXEC="agent --node-label topology.kubernetes.io/zone=$LOCATION" \
  sh -

# Wait for k3s to be ready
echo -e "${GREEN}⏳ Waiting for k3s to be ready...${NC}"
sleep 10

# Install Tailscale
echo -e "${GREEN}🔐 Installing Tailscale...${NC}"
curl -fsSL https://tailscale.com/install.sh | sh

# Start Tailscale
echo -e "${GREEN}🔐 Connecting to Tailscale network...${NC}"
tailscale up --authkey="$TS_AUTHKEY" --hostname="maetwix-$LOCATION"

# Get Tailscale IP
TS_IP=$(tailscale ip -4)
echo -e "${GREEN}✓ Tailscale IP: $TS_IP${NC}"

# Install Cloudflared (optional, for later)
echo -e "${GREEN}☁️  Installing Cloudflare Tunnel client...${NC}"
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb 
dpkg -i cloudflared.deb
rm cloudflared.deb

echo ""
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Node successfully joined cluster!${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo ""
echo "Node details:"
echo "  Location: $LOCATION"
echo "  Tailscale IP: $TS_IP"
echo "  Hostname: $(hostname)"
echo ""
echo "Next steps:"
echo "  1. Verify node in cluster:"
echo "     kubectl get nodes -l topology.kubernetes.io/zone=$LOCATION"
echo ""
echo "  2. Watch ArgoCD deploy workloads:"
echo "     kubectl get pods -n matrix -w"
echo ""
echo "  3. Monitor at: https://argocd.maetwix.org"
echo ""
echo "  4. Configure Cloudflare Tunnel:"
echo "     Contact admin for tunnel credentials"
echo ""
echo -e "${GREEN}Thank you for joining the Maetwix cluster! 🎉${NC}"
