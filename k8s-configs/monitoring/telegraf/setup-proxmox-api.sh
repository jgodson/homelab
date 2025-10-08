#!/bin/bash

# Proxmox API User and Token Setup Script for Telegraf Monitoring
# Run this script on your Proxmox server as root

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TELEGRAF_USER="influx"
TELEGRAF_REALM="pve"
TOKEN_NAME="monitoring"
ROLE="PVEAuditor"
PATH_ACL="/"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Proxmox API Setup for Telegraf Monitoring${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root${NC}"
   echo "Please run: sudo $0"
   exit 1
fi

# Check if this is a Proxmox server
if ! command -v pveum &> /dev/null; then
    echo -e "${RED}Error: pveum command not found. This script must be run on a Proxmox VE server.${NC}"
    exit 1
fi

echo -e "${YELLOW}This script will:${NC}"
echo "1. Create a user '${TELEGRAF_USER}@${TELEGRAF_REALM}' for Telegraf monitoring"
echo "2. Assign the '${ROLE}' role to the user on '${PATH_ACL}'"
echo "3. Create an API token '${TOKEN_NAME}' for the user"
echo "4. Set appropriate permissions for the token"
echo

read -p "Do you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Operation cancelled.${NC}"
    exit 0
fi
echo

# Function to check if user exists
user_exists() {
    pveum user list | grep -q "^${TELEGRAF_USER}@${TELEGRAF_REALM}"
}

# Function to check if token exists
token_exists() {
    pveum user token list "${TELEGRAF_USER}@${TELEGRAF_REALM}" 2>/dev/null | grep -q "^${TOKEN_NAME}"
}

# Create user if it doesn't exist
echo -e "${BLUE}Step 1: Creating Influx user...${NC}"
if user_exists; then
    echo -e "${YELLOW}User ${TELEGRAF_USER}@${TELEGRAF_REALM} already exists. Skipping user creation.${NC}"
else
    echo "Creating user ${TELEGRAF_USER}@${TELEGRAF_REALM}..."
    pveum user add "${TELEGRAF_USER}@${TELEGRAF_REALM}" --comment "Influx monitoring user for VM metrics collection"
    echo -e "${GREEN}✓ User created successfully${NC}"
fi

# Assign role to user
echo -e "${BLUE}Step 2: Assigning ${ROLE} role to user...${NC}"
echo "Setting ACL for user ${TELEGRAF_USER}@${TELEGRAF_REALM} on path ${PATH_ACL}..."
pveum acl modify "${PATH_ACL}" -role "${ROLE}" -user "${TELEGRAF_USER}@${TELEGRAF_REALM}"
echo -e "${GREEN}✓ Role assigned successfully${NC}"

# Create API token
echo -e "${BLUE}Step 3: Creating API token...${NC}"
if token_exists; then
    echo -e "${YELLOW}Token ${TOKEN_NAME} already exists for user ${TELEGRAF_USER}@${TELEGRAF_REALM}.${NC}"
    echo -e "${YELLOW}If you need a new token, please delete the existing one first:${NC}"
    echo "  pveum user token remove ${TELEGRAF_USER}@${TELEGRAF_REALM} ${TOKEN_NAME}"
    echo
    echo -e "${BLUE}Existing token information:${NC}"
    pveum user token list "${TELEGRAF_USER}@${TELEGRAF_REALM}"
else
    echo "Creating API token ${TOKEN_NAME} for user ${TELEGRAF_USER}@${TELEGRAF_REALM}..."
    echo -e "${YELLOW}Important: Save the token value shown below - it cannot be retrieved later!${NC}"
    echo
    
    # Create token with privilege separation
    TOKEN_OUTPUT=$(pveum user token add "${TELEGRAF_USER}@${TELEGRAF_REALM}" "${TOKEN_NAME}" -privsep 1 --comment "Influx monitoring token for VM metrics collection")
    
    echo -e "${GREEN}✓ Token created successfully${NC}"
    echo
    echo -e "${BLUE}Token Details:${NC}"
    echo "$TOKEN_OUTPUT"
fi

# Assign role to token
echo -e "${BLUE}Step 4: Assigning ${ROLE} role to token...${NC}"
echo "Setting ACL for token ${TELEGRAF_USER}@${TELEGRAF_REALM}!${TOKEN_NAME} on path ${PATH_ACL}..."
pveum acl modify "${PATH_ACL}" -role "${ROLE}" -token "${TELEGRAF_USER}@${TELEGRAF_REALM}!${TOKEN_NAME}"
echo -e "${GREEN}✓ Token role assigned successfully${NC}"

echo
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo

echo -e "${BLUE}Configuration Summary:${NC}"
echo "User: ${TELEGRAF_USER}@${TELEGRAF_REALM}"
echo "Token: ${TOKEN_NAME}"
echo "Role: ${ROLE}"
echo "Path: ${PATH_ACL}"
echo "Privilege Separation: Enabled"
echo

echo -e "${BLUE}Verification Commands:${NC}"
echo "List user: pveum user list | grep ${TELEGRAF_USER}"
echo "List tokens: pveum user token list ${TELEGRAF_USER}@${TELEGRAF_REALM}"
echo "List ACLs: pveum acl list | grep ${TELEGRAF_USER}"
echo

echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Copy the API token value from above"
echo "2. Update your .env file with the token in this format:"
echo "   PROXMOX_API_TOKEN=${TELEGRAF_USER}@${TELEGRAF_REALM}!${TOKEN_NAME}=<token_value>"
echo "3. Test the API connection:"
echo "   curl -k -H \"Authorization: PVEAPIToken=${TELEGRAF_USER}@${TELEGRAF_REALM}!${TOKEN_NAME}=<token_value>\" \\"
echo "     \"https://$(hostname -I | awk '{print $1}'):8006/api2/json/nodes\""
echo

echo -e "${GREEN}Setup complete! You can now configure Telegraf to monitor your Proxmox VMs.${NC}"