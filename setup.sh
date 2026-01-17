#!/bin/bash

# Honeypot Project Quick Setup Script
# This script automates the initial setup process

set -e  # Exit on error

echo "=================================="
echo "Honeypot Project Setup Script"
echo "=================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo -e "${RED}Please do not run as root${NC}"
    exit 1
fi

# Function to print colored messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Check Docker installation
echo "Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi
print_success "Docker is installed"

if ! command -v docker compose &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi
print_success "Docker Compose is installed"

# Check system requirements
echo ""
echo "Checking system requirements..."

# Check RAM
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM" -lt 16 ]; then
    print_warning "Your system has ${TOTAL_RAM}GB RAM. 16GB+ is recommended."
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    print_success "RAM: ${TOTAL_RAM}GB (sufficient)"
fi

# Check disk space
AVAILABLE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$AVAILABLE_SPACE" -lt 50 ]; then
    print_warning "Available disk space: ${AVAILABLE_SPACE}GB. 50GB+ recommended."
else
    print_success "Disk space: ${AVAILABLE_SPACE}GB available"
fi

# Set vm.max_map_count for Elasticsearch
echo ""
echo "Configuring system for Elasticsearch..."
CURRENT_MAP_COUNT=$(sysctl -n vm.max_map_count)
if [ "$CURRENT_MAP_COUNT" -lt 262144 ]; then
    echo "Setting vm.max_map_count=262144..."
    sudo sysctl -w vm.max_map_count=262144
    
    # Make it permanent
    if ! grep -q "vm.max_map_count" /etc/sysctl.conf; then
        echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
    fi
    print_success "vm.max_map_count configured"
else
    print_success "vm.max_map_count already configured"
fi

# Create directory structure
echo ""
echo "Creating project directory structure..."
BASE_DIR="$HOME/honeypot-project"

mkdir -p "$BASE_DIR/elk/logstash/config"
mkdir -p "$BASE_DIR/elk/logstash/pipeline"
mkdir -p "$BASE_DIR/elk/kibana/config"
mkdir -p "$BASE_DIR/opencti"

print_success "Directory structure created at $BASE_DIR"

# Generate secure passwords
echo ""
echo "Generating secure passwords..."
ELASTIC_PASS=$(openssl rand -base64 24)
MINIO_PASS=$(openssl rand -base64 24)
RABBITMQ_PASS=$(openssl rand -base64 24)
OPENCTI_ADMIN_PASS=$(openssl rand -base64 24)
OPENCTI_TOKEN=$(uuidgen)
CONNECTOR_ID=$(uuidgen)

# Save passwords to file
CREDS_FILE="$BASE_DIR/CREDENTIALS.txt"
cat > "$CREDS_FILE" << EOF
===========================================
HONEYPOT PROJECT CREDENTIALS
Generated: $(date)
===========================================

⚠️  KEEP THIS FILE SECURE AND PRIVATE! ⚠️

ELK STACK:
----------
Elasticsearch User: elastic
Elasticsearch Password: $ELASTIC_PASS
Kibana URL: http://localhost:5601

OPENCTI:
--------
OpenCTI URL: http://localhost:8080
OpenCTI Admin Email: admin@opencti.io
OpenCTI Admin Password: $OPENCTI_ADMIN_PASS
OpenCTI API Token: $OPENCTI_TOKEN

MinIO Console: http://localhost:9001
MinIO User: admin
MinIO Password: $MINIO_PASS

RabbitMQ Management: http://localhost:15672
RabbitMQ User: opencti
RabbitMQ Password: $RABBITMQ_PASS

MITRE Connector ID: $CONNECTOR_ID

===========================================
NEXT STEPS:
1. Review and customize docker-compose files if needed
2. Start ELK Stack: cd $BASE_DIR/elk && docker compose -f docker-compose-elk.yml up -d
3. Start OpenCTI: cd $BASE_DIR/opencti && docker compose -f docker-compose-opencti.yml up -d
4. Access Kibana at http://localhost:5601
5. Access OpenCTI at http://localhost:8080
===========================================
EOF

chmod 600 "$CREDS_FILE"
print_success "Credentials saved to $CREDS_FILE"

echo ""
print_warning "IMPORTANT: The configuration files still have default passwords!"
print_warning "You need to manually update the docker-compose files with the generated passwords."
echo ""
echo "Generated credentials have been saved to: $CREDS_FILE"
echo ""
echo -e "${YELLOW}To view your credentials:${NC}"
echo "  cat $CREDS_FILE"
echo ""

# Ask if user wants to copy files
echo "Would you like to copy the provided Docker Compose and config files to the project directory?"
echo "(Make sure you have the files in your current directory)"
read -p "Copy files now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -f "docker-compose-elk.yml" ]; then
        cp docker-compose-elk.yml "$BASE_DIR/elk/"
        print_success "Copied docker-compose-elk.yml"
    else
        print_warning "docker-compose-elk.yml not found in current directory"
    fi
    
    if [ -f "docker-compose-opencti.yml" ]; then
        cp docker-compose-opencti.yml "$BASE_DIR/opencti/"
        print_success "Copied docker-compose-opencti.yml"
    else
        print_warning "docker-compose-opencti.yml not found in current directory"
    fi
    
    # Copy config files if they exist
    [ -f "logstash.yml" ] && cp logstash.yml "$BASE_DIR/elk/logstash/config/" && print_success "Copied logstash.yml"
    [ -f "cowrie.conf" ] && cp cowrie.conf "$BASE_DIR/elk/logstash/pipeline/" && print_success "Copied cowrie.conf"
    [ -f "kibana.yml" ] && cp kibana.yml "$BASE_DIR/elk/kibana/config/" && print_success "Copied kibana.yml"
fi

# Summary
echo ""
echo "=================================="
echo "Setup Complete!"
echo "=================================="
echo ""
echo "Project directory: $BASE_DIR"
echo "Credentials file: $CREDS_FILE"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. Update docker-compose files with generated passwords from CREDENTIALS.txt"
echo "2. Start ELK Stack:"
echo "   cd $BASE_DIR/elk"
echo "   docker compose -f docker-compose-elk.yml up -d"
echo ""
echo "3. Start OpenCTI:"
echo "   cd $BASE_DIR/opencti"
echo "   docker compose -f docker-compose-opencti.yml up -d"
echo ""
echo "4. Monitor startup:"
echo "   docker compose logs -f"
echo ""
echo "For detailed instructions, see SETUP_INSTRUCTIONS.md"
echo ""
