#!/usr/bin/env bash
# scripts/deploy-cloud-apps.sh
# Simple deployment script for cloud-apps server

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Config
SERVER_NAME="cloud-apps"
SERVER_IP="192.168.50.8"
SERVER_USER="nixadm"
REBOOT=true

# Parse args
for arg in "$@"; do
    case $arg in
        --no-reboot)
            REBOOT=false
            ;;
        --help|-h)
            echo "Usage: $0 [--no-reboot]"
            echo ""
            echo "Options:"
            echo "  --no-reboot    Deploy without rebooting"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            exit 1
            ;;
    esac
done

log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✅${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}❌${NC} $1"; }

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Cloud-Apps Deployment (Homelab Edition)          ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Deploy
log_info "Deploying to ${SERVER_NAME}..."
if ! colmena apply --on "${SERVER_NAME}"; then
    log_error "Deployment failed"
    exit 1
fi
log_success "Deployed"

# Reboot if requested
if [ "${REBOOT}" = true ]; then
    log_info "Rebooting server..."
    ssh "${SERVER_USER}@${SERVER_IP}" 'sudo reboot' &>/dev/null || true
    
    sleep 10  # Wait for shutdown
    
    log_info "Waiting for server to come back (max 90s)..."
    for i in {1..18}; do  # 18 * 5s = 90s
        if ssh -o ConnectTimeout=3 -o PasswordAuthentication=no "${SERVER_USER}@${SERVER_IP}" 'exit' &>/dev/null; then
            log_success "Server is back online"
            sleep 10  # Give services time to start
            break
        fi
        [ $i -eq 18 ] && log_warning "Server taking longer than expected, but probably fine"
        sleep 5
    done
fi

# Quick service check
log_info "Checking services..."
for svc in mysql nginx phpfpm-nextcloud; do
    if ssh "${SERVER_USER}@${SERVER_IP}" "sudo systemctl is-active --quiet ${svc}.service" 2>/dev/null; then
        log_success "${svc} ✓"
    else
        log_warning "${svc} might need attention"
    fi
done

echo ""
log_success "Done! Check: https://cloud.home.lan"
echo ""
