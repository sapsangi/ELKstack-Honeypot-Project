#!/bin/bash

# deploy_remote.sh
# Automates the setup and deployment of ELK/OpenCTI to a remote NAS via Docker Contexts

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BASE_DIR="$(pwd)"
ENV_FILE="$BASE_DIR/.env"
REMOTE_CONTEXT="nas-compute"
REMOTE_CONFIG_DIR="~/honeypot_configs"

# Load existing environment variables
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi

print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# 1. Configure NAS Connection Details
print_step "Checking NAS configuration..."

if [ -z "$NAS_USER" ] || [ -z "$NAS_HOST" ]; then
    echo "NAS connection details not found in .env"
    
    read -p "Enter NAS Username (e.g., sapsangi): " INPUT_USER
    read -p "Enter NAS IPv4 Address (e.g., 192.168.1.100): " INPUT_HOST
    
    if [ -z "$INPUT_USER" ] || [ -z "$INPUT_HOST" ]; then
        echo -e "${RED}Error: Username and Host are required.${NC}"
        exit 1
    fi
    
    # Save to .env
    echo "" >> "$ENV_FILE"
    echo "# NAS Configuration" >> "$ENV_FILE"
    echo "NAS_USER=$INPUT_USER" >> "$ENV_FILE"
    echo "NAS_HOST=$INPUT_HOST" >> "$ENV_FILE"
    
    # Reload
    source "$ENV_FILE"
    print_success "Saved NAS configuration to .env"
else
    print_success "Using NAS: $NAS_USER@$NAS_HOST"
fi

NAS_CONNECTION="ssh://$NAS_USER@$NAS_HOST"

# 2. Setup SSH Key Setup
print_step "Verifying SSH connection..."

# Check if we can connect without password
if ssh -o BatchMode=yes -o ConnectTimeout=5 "$NAS_USER@$NAS_HOST" exit &>/dev/null; then
    print_success "SSH connection established (Passwordless)"
else
    print_warning "SSH passwordless login not configured."
    echo "We need to copy your SSH public key to the NAS."
    
    if [ ! -f ~/.ssh/id_rsa.pub ] && [ ! -f ~/.ssh/id_ed25519.pub ]; then
        echo "Generating SSH key..."
        ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
    fi
    
    echo "Copying SSH key to NAS. You will be asked for your NAS password."
    ssh-copy-id "$NAS_USER@$NAS_HOST"
    
    if ssh -o BatchMode=yes -o ConnectTimeout=5 "$NAS_USER@$NAS_HOST" exit &>/dev/null; then
        print_success "SSH connection established"
    else
        echo -e "${RED}Failed to establish SSH connection.${NC}"
        exit 1
    fi
fi

# 3. Create/Update Docker Context
print_step "Configuring Docker Context..."

if docker context inspect "$REMOTE_CONTEXT" &>/dev/null; then
    docker context update "$REMOTE_CONTEXT" --docker "host=$NAS_CONNECTION" &>/dev/null
    print_success "Updated existing context '$REMOTE_CONTEXT'"
else
    docker context create "$REMOTE_CONTEXT" --docker "host=$NAS_CONNECTION" --description "Remote NAS Compute" &>/dev/null
    print_success "Created new context '$REMOTE_CONTEXT'"
fi

# 4. Sync Configuration Files
print_step "Syncing configuration files to NAS..."

# Create remote directory
ssh "$NAS_USER@$NAS_HOST" "mkdir -p $REMOTE_CONFIG_DIR"

# Rsync directories (elk and opencti)
# Excluding data directories to avoid massive transfers
echo "Syncing ./elk..."
rsync -avz --exclude 'elasticsearch-data' --exclude 'logs' ./elk "$NAS_USER@$NAS_HOST:$REMOTE_CONFIG_DIR/"

echo "Syncing ./opencti..."
rsync -avz ./opencti "$NAS_USER@$NAS_HOST:$REMOTE_CONFIG_DIR/"

# Sync .env
echo "Syncing .env..."
scp "$ENV_FILE" "$NAS_USER@$NAS_HOST:$REMOTE_CONFIG_DIR/.env"

# Setup remote .env links
ssh "$NAS_USER@$NAS_HOST" "ln -sf $REMOTE_CONFIG_DIR/.env $REMOTE_CONFIG_DIR/elk/.env && ln -sf $REMOTE_CONFIG_DIR/.env $REMOTE_CONFIG_DIR/opencti/.env"

print_success "Configuration synced to $NAS_HOST:$REMOTE_CONFIG_DIR"

# 5. Deployment Options
echo ""
echo "=============================================="
echo "Deployment Ready"
echo "=============================================="
echo "1) Start ELK Stack on NAS"
echo "2) Start OpenCTI on NAS"
echo "3) Start EVERYTHING on NAS"
echo "4) Stop EVERYTHING on NAS"
echo "5) View Remote Stats"
echo "6) Exit"
echo ""
read -p "Select an option [1-6]: " OPTION

# Helper to run docker compose on remote
run_remote_compose() {
    local service_name="$1" # "elk" or "opencti"
    local action="$2"       # "up -d" or "down"
    local compose_file="docker-compose-${service_name}.yml"
    
    echo "Executing on NAS: $service_name -> $action"
    
    # Try 'docker compose' first, then 'docker-compose'
    ssh "$NAS_USER@$NAS_HOST" "cd $REMOTE_CONFIG_DIR/$service_name && \
    (docker compose -f $compose_file --env-file .env $action || \
     docker-compose -f $compose_file --env-file .env $action)"
}

setup_tunnel() {
    local ports="$1" # e.g. "-L 5601:localhost:5601"
    print_step "Setting up SSH Tunnel ($ports)..."
    # Kill existing tunnels matching this host
    pkill -f "ssh .* $NAS_USER@$NAS_HOST" || true
    # Start new tunnel
    ssh -f -N $ports "$NAS_USER@$NAS_HOST"
    print_success "Tunnel active."
}

case $OPTION in
    1)
        print_step "Starting ELK Stack on NAS..."
        run_remote_compose "elk" "up -d"
        setup_tunnel "-L 5601:localhost:5601"
        print_success "Access Kibana at http://localhost:5601"
        ;;
    2)
        print_step "Starting OpenCTI on NAS..."
        run_remote_compose "opencti" "up -d"
        setup_tunnel "-L 8080:localhost:8080"
        print_success "Access OpenCTI at http://localhost:8080"
        ;;
    3)
        print_step "Starting ELK..."
        run_remote_compose "elk" "up -d"
        print_step "Starting OpenCTI..."
        run_remote_compose "opencti" "up -d"
        setup_tunnel "-L 5601:localhost:5601 -L 8080:localhost:8080"
        print_success "All systems go! Access at localhost:5601 and localhost:8080"
        ;;
    4)
        print_step "Stopping Remote Containers..."
        run_remote_compose "opencti" "down"
        run_remote_compose "elk" "down"
        print_success "Stopped."
        ;;
    5)
        ssh -t "$NAS_USER@$NAS_HOST" "docker stats"
        ;;
    6)
        exit 0
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac
