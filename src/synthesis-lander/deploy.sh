#!/bin/bash

# Synthesis Lander Deployment Script
# This script sets up the synthesis-lander service on a Linux system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   exit 1
fi

echo -e "${GREEN}Starting Synthesis Lander deployment...${NC}"

# Variables
SERVICE_NAME="synthesis-lander"
APP_DIR="/opt/synthesis-lander"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Create application directory
echo -e "${YELLOW}Creating application directory...${NC}"
mkdir -p ${APP_DIR}

# Copy application files
echo -e "${YELLOW}Copying application files...${NC}"
cp -r ${CURRENT_DIR}/* ${APP_DIR}/
chown -R www-data:www-data ${APP_DIR}

# Install Node.js if not present
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}Installing Node.js...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt-get install -y nodejs
fi

# Copy service file
echo -e "${YELLOW}Installing systemd service...${NC}"
cp ${APP_DIR}/${SERVICE_NAME}.service ${SERVICE_FILE}

# Reload systemd
systemctl daemon-reload

# Enable and start service
echo -e "${YELLOW}Enabling and starting service...${NC}"
systemctl enable ${SERVICE_NAME}
systemctl start ${SERVICE_NAME}

# Check service status
sleep 2
if systemctl is-active --quiet ${SERVICE_NAME}; then
    echo -e "${GREEN}✓ Synthesis Lander is running!${NC}"
    echo -e "${GREEN}Service status:${NC}"
    systemctl status ${SERVICE_NAME} --no-pager
    echo -e "\n${GREEN}Access the application at: http://$(hostname -I | cut -d' ' -f1)${NC}"
else
    echo -e "${RED}✗ Service failed to start${NC}"
    echo -e "${RED}Check logs with: journalctl -u ${SERVICE_NAME} -f${NC}"
    exit 1
fi

echo -e "\n${GREEN}Deployment complete!${NC}"
echo -e "${YELLOW}Useful commands:${NC}"
echo -e "  View logs:    journalctl -u ${SERVICE_NAME} -f"
echo -e "  Restart:      systemctl restart ${SERVICE_NAME}"
echo -e "  Stop:         systemctl stop ${SERVICE_NAME}"
echo -e "  Status:       systemctl status ${SERVICE_NAME}"