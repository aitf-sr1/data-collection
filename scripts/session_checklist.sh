#!/usr/bin/env bash
# session_checklist.sh - Pre-session verification checklist
# Run this before each data collection session

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Check required environment variables
: "${VPS_HOST:?VPS_HOST environment variable is required}"

echo ""
echo "========================================"
echo "  FER Data Collection Session Checklist"
echo "========================================"
echo ""
echo "Press Enter after completing each item."
echo ""

checklist_item() {
    local num="$1"
    local desc="$2"
    
    printf "${YELLOW}[%2d]${NC} %s\n" "$num" "$desc"
    read -r -p "     Press Enter when done... "
    printf "\r     ${GREEN}✓${NC} Done\n\n"
}

# 1. VPS service running
checklist_item 1 "VPS service running?"
echo "     Check: ssh ${VPS_HOST} 'sudo systemctl status fer-collect'"
echo ""

# 2. HTTPS working
checklist_item 2 "HTTPS working? (curl health endpoint)"
echo "     Check: curl -k https://${VPS_HOST}/health"
echo ""

# 3. Admin page loads
checklist_item 3 "Admin page loads and token works?"
echo "     Open: https://${VPS_HOST}/admin"
echo "     Enter token and verify status loads"
echo ""

# 4. Recorder page
checklist_item 4 "Recorder page (Screen 1) appears?"
echo "     Open: https://${VPS_HOST}/"
echo "     Should see welcome screen with name input"
echo ""

# 5. Test subject
checklist_item 5 "Test ID works and appears in /status?"
echo "     Enter name 'Test User' on recorder page"
echo "     Proceed through camera permission"
echo "     Check admin page shows new connection"
echo ""

# 6. Start signal
checklist_item 6 "Start signal works?"
echo "     Click 'Start Session' on admin page"
echo "     Test browser should advance to task screen"
echo ""

# 7. Recording and upload
checklist_item 7 "Recording and upload works?"
echo "     Let test browser complete one scenario"
echo "     Check admin page shows bytes received"
echo "     Check data directory has .webm file"
echo ""

# 8. Clean test data
checklist_item 8 "Delete test data before real session?"
echo "     Remove test subject directory from VPS"
echo "     Reset session if needed (restart fer-collect service)"
echo ""

# 9. Storage space
checklist_item 9 "VPS has sufficient storage?"
echo "     Check: ssh ${VPS_HOST} 'df -h /var/lib/fer-collect'"
echo "     Need ~3GB free for 30 students"
echo ""

# 10. Students ready
checklist_item 10 "Students briefed and ready?"
echo "     - URL shared (or ready to share)"
echo "     - Browser requirement explained (Chrome/Edge)"
echo "     - Lighting and camera position checked"
echo "     - Students know to wait for start signal"
echo ""

echo "========================================"
echo -e "${GREEN}Checklist complete!${NC}"
echo "========================================"
echo ""
echo "Ready to begin session:"
echo "  1. Share URL with students: https://${VPS_HOST}/"
echo "  2. Wait for all students to connect (check admin page)"
echo "  3. Click 'Start Session' when ready"
echo "  4. Wait ~15 minutes for all tasks to complete"
echo "  5. Run pull_data.sh when admin shows all complete"
echo ""
