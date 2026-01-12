#!/usr/bin/env bash
# Create a new NixOS server from template
# Template must exist as CT ID 9000 on Proxmox

set -euo pipefail

if [ $# -lt 3 ]; then
  echo "Usage: $0 <hostname> <ct-id> <ip-address>"
  echo "Example: $0 actual-budget 111 192.168.50.11"
  exit 1
fi

HOSTNAME=$1
CTID=$2
IP=$3
TEMPLATE_ID=9000
PROXMOX_HOST="pve.home.lan" # Adjust if needed

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Creating: $HOSTNAME"
echo "Container ID: $CTID"
echo "IP Address: $IP"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Clone from template
echo "→ Cloning from template $TEMPLATE_ID..."
ssh root@$PROXMOX_HOST pct clone $TEMPLATE_ID $CTID \
  --full 1 \
  --hostname "$HOSTNAME"

# Configure network
echo "→ Configuring network ($IP)..."
ssh root@$PROXMOX_HOST pct set $CTID \
  --net0 name=eth0,bridge=vmbr0,ip=${IP}/24,gw=192.168.50.1

# Optional: Set resources
#ssh root@$PROXMOX_HOST pct set $CTID \
#  --cores 2 \
#  --memory 2048 \
#  --swap 512

# Start container
echo "→ Starting container..."
ssh root@$PROXMOX_HOST pct start $CTID

echo ""
echo "✅ Container created successfully!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Next steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Wait for container to boot (10 seconds):"
echo "   sleep 10"
echo ""
echo "2. Test SSH access:"
echo "   ssh nixadm@$IP"
echo ""
echo "3. Add to colmena.nix:"
echo "   $HOSTNAME = mkServerDeployment \"$HOSTNAME\" \"$IP\" [\"production\" \"lxc\"];"
echo ""
echo "4. Create host configuration in hosts/servers/$HOSTNAME/"
echo ""
echo "5. Deploy with Colmena:"
echo "   colmena apply --on $HOSTNAME"
echo ""
