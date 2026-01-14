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

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Creating: $HOSTNAME"
echo "Container ID: $CTID"
echo "IP Address: $IP"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Clone from template
echo "→ Cloning from template $TEMPLATE_ID..."
ssh root@$PROXMOX_HOST pct clone $TEMPLATE_ID $CTID \
  --full 1 \
  --hostname "$HOSTNAME"

# Configure network
echo "→ Configuring network ($IP)..."
ssh root@$PROXMOX_HOST pct set $CTID \
  --net0 name=eth0,bridge=vmbr0,ip=${IP}/24,gw=192.168.50.1

# Regenerate SSH host keys to avoid fingerprint conflicts
echo "→ Regenerating SSH host keys..."
ssh root@$PROXMOX_HOST pct start $CTID
sleep 10  # Wait for boot
ssh root@$PROXMOX_HOST pct exec $CTID -- rm -f /etc/ssh/ssh_host_*
ssh root@$PROXMOX_HOST pct exec $CTID -- ssh-keygen -A
ssh root@$PROXMOX_HOST pct stop $CTID
sleep 5

echo ""
echo "✅ Container created successfully!"
echo "⚠️  Container is STOPPED - configure mount points before starting!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Next steps:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Configure mount points on Proxmox (if needed):"
echo "   ssh root@$PROXMOX_HOST"
echo "   pct set $CTID -mp0 /mnt/storage/data,mp=/mnt/data"
echo ""
echo "2. Set resources (optional):"
echo "   ssh root@$PROXMOX_HOST pct set $CTID --cores 4 --memory 8192 --swap 2048"
echo ""
echo "3. Start container:"
echo "   ssh root@$PROXMOX_HOST pct start $CTID"
echo "   sleep 10"
echo ""
echo "4. Test SSH access:"
echo "   ssh nixadm@$IP"
echo ""
echo "5. Add to colmena.nix:"
echo "   $HOSTNAME = mkServerDeployment \"$HOSTNAME\" \"$IP\" [\"production\" \"lxc\"];"
echo ""
echo "6. Create host configuration in hosts/servers/$HOSTNAME/"
echo ""
echo "7. Deploy with Colmena:"
echo "   colmena apply --on $HOSTNAME"
echo ""
