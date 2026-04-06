#!/usr/bin/env bash
# pull_data.sh - Pull FER session data from VPS
# Requires: VPS_HOST, VPS_USER, LOCAL_DATA_DIR environment variables

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Check required environment variables
: "${VPS_HOST:?VPS_HOST environment variable is required}"
: "${VPS_USER:?VPS_USER environment variable is required}"
: "${LOCAL_DATA_DIR:?LOCAL_DATA_DIR environment variable is required}"

# Optional: remote data directory (default: /var/lib/fer-collect/data)
REMOTE_DATA_DIR="${REMOTE_DATA_DIR:-/var/lib/fer-collect/data}"

echo "Pulling data from VPS..."
echo "  Source: ${VPS_USER}@${VPS_HOST}:${REMOTE_DATA_DIR}/"
echo "  Destination: ${LOCAL_DATA_DIR}/"
echo ""

# Create local directory if it doesn't exist
mkdir -p "$LOCAL_DATA_DIR"

# Pull data with rsync
rsync -avz --progress \
    "${VPS_USER}@${VPS_HOST}:${REMOTE_DATA_DIR}/" \
    "${LOCAL_DATA_DIR}/"

echo ""
echo -e "${GREEN}Transfer complete.${NC}"
echo ""

# Run verification
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -x "${SCRIPT_DIR}/verify_session.sh" ]]; then
    echo "Running verification..."
    echo ""
    "${SCRIPT_DIR}/verify_session.sh" "$LOCAL_DATA_DIR"
else
    echo -e "${RED}Warning: verify_session.sh not found or not executable${NC}"
fi
