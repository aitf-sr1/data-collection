#!/usr/bin/env bash
# deploy.sh - Deploy FER collection server to VPS
# Requires: VPS_HOST, VPS_USER environment variables

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Check required environment variables
: "${VPS_HOST:?VPS_HOST environment variable is required}"
: "${VPS_USER:?VPS_USER environment variable is required}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BINARY_PATH="${PROJECT_DIR}/bin/fer-server-linux"

# Check binary exists
if [[ ! -f "$BINARY_PATH" ]]; then
    echo -e "${RED}Error: Binary not found at ${BINARY_PATH}${NC}"
    echo "Run 'make build-linux' first."
    exit 1
fi

echo "Deploying FER collection server to ${VPS_HOST}..."
echo ""

# 1. Upload binary
echo -e "${YELLOW}[1/5]${NC} Uploading binary..."
rsync -avz --progress "$BINARY_PATH" "${VPS_USER}@${VPS_HOST}:/tmp/fer-server"
ssh "${VPS_USER}@${VPS_HOST}" "sudo mv /tmp/fer-server /usr/local/bin/fer-server && sudo chmod +x /usr/local/bin/fer-server"

# 2. Upload systemd service
echo -e "${YELLOW}[2/5]${NC} Uploading systemd service..."
if [[ -f "${PROJECT_DIR}/configs/fer-collect.service" ]]; then
    rsync -avz "${PROJECT_DIR}/configs/fer-collect.service" "${VPS_USER}@${VPS_HOST}:/tmp/"
    ssh "${VPS_USER}@${VPS_HOST}" "sudo mv /tmp/fer-collect.service /etc/systemd/system/"
fi

# 3. Upload nginx config
echo -e "${YELLOW}[3/5]${NC} Uploading nginx config..."
if [[ -f "${PROJECT_DIR}/configs/nginx.conf" ]]; then
    rsync -avz "${PROJECT_DIR}/configs/nginx.conf" "${VPS_USER}@${VPS_HOST}:/tmp/fer-collect.nginx"
    ssh "${VPS_USER}@${VPS_HOST}" "sudo mv /tmp/fer-collect.nginx /etc/nginx/sites-available/fer-collect"
    ssh "${VPS_USER}@${VPS_HOST}" "sudo ln -sf /etc/nginx/sites-available/fer-collect /etc/nginx/sites-enabled/"
fi

# 4. Create data directory and user
echo -e "${YELLOW}[4/5]${NC} Setting up directories and permissions..."
ssh "${VPS_USER}@${VPS_HOST}" << 'REMOTE_SCRIPT'
    # Create fer user if not exists
    if ! id -u fer &>/dev/null; then
        sudo useradd --system --no-create-home --shell /usr/sbin/nologin fer
    fi
    
    # Create directories
    sudo mkdir -p /var/lib/fer-collect/data
    sudo mkdir -p /etc/fer-collect
    
    # Set ownership
    sudo chown -R fer:fer /var/lib/fer-collect
    
    # Create default .env if not exists
    if [[ ! -f /etc/fer-collect/.env ]]; then
        echo "PORT=8080" | sudo tee /etc/fer-collect/.env > /dev/null
        echo "DATA_DIR=/var/lib/fer-collect/data" | sudo tee -a /etc/fer-collect/.env > /dev/null
        echo "ADMIN_TOKEN=CHANGE_ME_IN_PRODUCTION" | sudo tee -a /etc/fer-collect/.env > /dev/null
        sudo chmod 600 /etc/fer-collect/.env
        sudo chown fer:fer /etc/fer-collect/.env
        echo "Created /etc/fer-collect/.env - remember to set ADMIN_TOKEN!"
    fi
REMOTE_SCRIPT

# 5. Restart services
echo -e "${YELLOW}[5/5]${NC} Restarting services..."
ssh "${VPS_USER}@${VPS_HOST}" << 'REMOTE_SCRIPT'
    sudo systemctl daemon-reload
    sudo systemctl enable fer-collect
    sudo systemctl restart fer-collect
    
    # Test and reload nginx
    if sudo nginx -t; then
        sudo systemctl reload nginx
    else
        echo "Nginx config test failed!"
        exit 1
    fi
REMOTE_SCRIPT

echo ""
echo -e "${GREEN}Deployment complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. SSH to VPS and edit /etc/fer-collect/.env to set ADMIN_TOKEN"
echo "  2. Run: sudo systemctl restart fer-collect"
echo "  3. Test: curl -k https://${VPS_HOST}/health"
echo ""
