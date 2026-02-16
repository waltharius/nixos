#!/usr/bin/env bash
# scripts/deploy-cloud-apps.sh
# Safe deployment script for cloud-apps server with automatic reboot
#
# This script ensures clean state activation by rebooting the server after
# configuration deployment, preventing path conflicts during Nextcloud upgrades.
#
# Usage:
#   ./scripts/deploy-cloud-apps.sh [OPTIONS]
#
# Options:
#   --no-reboot      Skip automatic reboot (not recommended for major upgrades)
#   --skip-checks    Skip pre-flight connectivity checks
#   --help, -h       Show this help message

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVER_NAME="cloud-apps"
SERVER_IP="192.168.50.8"
SERVER_USER="nixadm"
REBOOT=true
SKIP_CHECKS=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --no-reboot)
            REBOOT=false
            shift
            ;;
        --skip-checks)
            SKIP_CHECKS=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --no-reboot      Skip automatic reboot (not recommended for major upgrades)"
            echo "  --skip-checks    Skip pre-flight connectivity checks"
            echo "  --help, -h       Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✅${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}❌${NC} $1"
}

check_connectivity() {
    log_info "Checking connectivity to ${SERVER_NAME} (${SERVER_IP})..."
    
    # Check network connectivity
    if ! ping -c 1 -W 2 "${SERVER_IP}" &> /dev/null; then
        log_error "Cannot reach ${SERVER_NAME} at ${SERVER_IP}"
        log_error "Please check network connectivity"
        return 1
    fi
    
    # Check SSH connectivity with proper key handling
    # Using BatchMode=yes to use only keys (no password prompts)
    # Using ConnectTimeout for faster failure
    if ! ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "${SERVER_USER}@${SERVER_IP}" 'exit' 2>/dev/null; then
        log_error "Cannot SSH to ${SERVER_NAME}"
        log_error "Possible issues:"
        echo "  1. SSH key not loaded in ssh-agent (run: ssh-add)"
        echo "  2. SSH key not authorized on server"
        echo "  3. Firewall blocking SSH port"
        echo "  4. Server is down"
        echo ""
        log_info "Try manually: ssh ${SERVER_USER}@${SERVER_IP}"
        log_info "Or skip this check with: $0 --skip-checks"
        return 1
    fi
    
    log_success "Connectivity check passed"
    return 0
}

deploy_config() {
    log_info "🚀 Deploying configuration to ${SERVER_NAME}..."
    
    if colmena apply --on "${SERVER_NAME}" -v; then
        log_success "Configuration deployed successfully"
        return 0
    else
        log_error "Deployment failed!"
        return 1
    fi
}

reboot_server() {
    log_info "🔄 Rebooting ${SERVER_NAME} for clean activation..."
    
    # Send reboot command
    # The connection will drop, so we ignore the error
    if ssh "${SERVER_USER}@${SERVER_IP}" 'sudo reboot' &> /dev/null; then
        log_success "Reboot command sent"
    else
        log_warning "Connection closed (expected during reboot)"
    fi
    
    # Wait for server to go down
    log_info "⏳ Waiting for server to shut down..."
    sleep 5
    
    # Wait for server to come back up (max 2 minutes)
    local max_attempts=24
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if ping -c 1 -W 2 "${SERVER_IP}" &> /dev/null; then
            # Try SSH with BatchMode to avoid hanging
            if ssh -o BatchMode=yes -o ConnectTimeout=5 "${SERVER_USER}@${SERVER_IP}" 'exit' 2>/dev/null; then
                echo ""  # New line after dots
                log_success "Server is back online"
                sleep 10  # Give services time to start
                return 0
            fi
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 5
    done
    
    echo ""  # New line after dots
    log_error "Server did not come back online within 2 minutes"
    log_info "Server might still be booting. Check manually:"
    echo "  ssh ${SERVER_USER}@${SERVER_IP}"
    return 1
}

check_services() {
    log_info "🔍 Checking service status..."
    
    local services=(
        "nextcloud-setup.service"
        "nextcloud-update-db.service"
        "mysql.service"
        "redis-nextcloud.service"
        "phpfpm-nextcloud.service"
        "nginx.service"
    )
    
    local failed_services=()
    
    for service in "${services[@]}"; do
        if ssh "${SERVER_USER}@${SERVER_IP}" "sudo systemctl is-active --quiet ${service}" 2>/dev/null; then
            log_success "${service} is active"
        else
            local status=$(ssh "${SERVER_USER}@${SERVER_IP}" "sudo systemctl is-active ${service}" 2>/dev/null || echo "unknown")
            if [ "${status}" == "inactive" ] && [[ "${service}" == "nextcloud-setup.service" || "${service}" == "nextcloud-update-db.service" ]]; then
                log_warning "${service} is ${status} (expected after successful run)"
            else
                log_error "${service} is ${status}"
                failed_services+=("${service}")
            fi
        fi
    done
    
    if [ ${#failed_services[@]} -gt 0 ]; then
        log_error "Some services failed. Check logs with:"
        for service in "${failed_services[@]}"; do
            echo "  ssh ${SERVER_USER}@${SERVER_IP} 'sudo journalctl -u ${service} -n 50'"
        done
        return 1
    fi
    
    log_success "All critical services are running"
    return 0
}

show_summary() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Deployment Summary${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "  Server:     ${SERVER_NAME} (${SERVER_IP})"
    echo -e "  Rebooted:   $([ "${REBOOT}" = true ] && echo 'Yes' || echo 'No')"
    echo -e "  Status:     ${GREEN}Success${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Useful commands:"
    echo "  • Check Nextcloud status:"
    echo "    ssh ${SERVER_USER}@${SERVER_IP} 'sudo -u nextcloud php /run/current-system/sw/bin/nextcloud-occ status'"
    echo ""
    echo "  • View recent logs:"
    echo "    ssh ${SERVER_USER}@${SERVER_IP} 'sudo journalctl -u nextcloud-setup.service -n 50'"
    echo ""
    echo "  • Access Nextcloud:"
    echo "    https://cloud.home.lan or https://stuff.deranged.cc"
    echo ""
}

# Main execution
main() {
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         Cloud-Apps Server Deployment Script              ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Pre-flight checks
    if [ "${SKIP_CHECKS}" = false ]; then
        if ! check_connectivity; then
            log_error "Pre-flight checks failed. Aborting."
            log_info "To skip checks, use: $0 --skip-checks"
            exit 1
        fi
    else
        log_warning "Skipping pre-flight checks (--skip-checks flag used)"
    fi
    
    # Deploy configuration
    if ! deploy_config; then
        log_error "Deployment failed. Aborting."
        exit 1
    fi
    
    # Reboot if requested
    if [ "${REBOOT}" = true ]; then
        if ! reboot_server; then
            log_error "Server reboot failed or timed out"
            log_warning "Check server status manually:"
            echo "  ssh ${SERVER_USER}@${SERVER_IP}"
            exit 1
        fi
    else
        log_warning "Skipping reboot (--no-reboot flag used)"
        log_warning "Manual reboot recommended for major version upgrades:"
        echo "  ssh ${SERVER_USER}@${SERVER_IP} 'sudo reboot'"
    fi
    
    # Verify services
    if ! check_services; then
        log_warning "Some services may need attention"
        exit 1
    fi
    
    # Show summary
    show_summary
    
    log_success "Deployment completed successfully! 🎉"
}

# Run main function
main "$@"
