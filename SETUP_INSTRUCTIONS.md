# Autonomous Threat Intel & Adaptive Honeypot System
## Docker Setup Instructions for Ubuntu

This guide will help you set up the ELK Stack and OpenCTI for your honeypot project on Ubuntu using Docker Desktop.

---

## Prerequisites

### System Requirements
- **Ubuntu 22.04 LTS or later**
- **Minimum 16GB RAM** (32GB recommended)
- **50GB+ free disk space**
- **Docker Desktop for Linux** or Docker Engine + Docker Compose

### Remote NAS Requirements (Optional - for Remote Compute)
- **NAS Device** (e.g., Ugreen, Synology)
- **Docker** installed on the NAS
- **SSH Access** enabled on the NAS
- **Local Network Connection** to the NAS

### Install Docker Desktop (if not already installed)

#### Option 1: Docker Desktop GUI Installation
1. Download Docker Desktop for Ubuntu:
   ```bash
   wget https://desktop.docker.com/linux/main/amd64/docker-desktop-4.26.1-amd64.deb
   ```

2. Install Docker Desktop:
   ```bash
   sudo apt-get update
   sudo apt-get install ./docker-desktop-4.26.1-amd64.deb
   ```

3. Start Docker Desktop from Applications menu or:
   ```bash
   systemctl --user start docker-desktop
   ```

#### Option 2: Docker Engine CLI Installation
```bash
# Update package index
sudo apt-get update

# Install dependencies
sudo apt-get install ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up the repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add your user to docker group (to run without sudo)
sudo usermod -aG docker $USER
newgrp docker
```

### Verify Docker Installation
```bash
docker --version
docker compose version
```

---

## Project Directory Setup

1. **Clone/Create project:**
   ```bash
   mkdir -p ~/honeypot-project
   cd ~/honeypot-project
   # (Clone your repo here if applicable)
   ```

2. **Automated Setup:**
   The `setup.sh` script automates creating directories, generating tokens, and setting up configuration files.
   ```bash
   sudo ./setup.sh
   ```
   *Follow the prompts to copy config files and generate the Kibana Service Token.*

---

## Configuration & Security

### **CRITICAL: Change Default Passwords**

1. **Edit ELK Configuration (`elk/docker-compose-elk.yml`):**
   - `ELASTIC_PASSWORD`: Change `changeme123` to a strong password.
   - **Important**: If your password contains a `$` character, escape it as `$$`.
   - Update this password in the `logstash` service environment variables as well.
   - **Kibana Token**: This is now handled automatically by `setup.sh` and stored in `.env` as `KIBANA_SERVICE_TOKEN`.

2. **Edit OpenCTI Configuration (`opencti/docker-compose-opencti.yml`):**
   - Change `MINIO_ROOT_PASSWORD`, `RABBITMQ_DEFAULT_PASS`, `APP__ADMIN__PASSWORD` etc.
   - **Tokens**: `APP__ADMIN__TOKEN`, `OPENCTI_TOKEN`, and `CONNECTOR_ID` are auto-generated in `.env`.

### System Configuration
Ensure your system limits are high enough for Elasticsearch:
```bash
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

---

## Deployment Options

You have two options for deployment:
1. **Local Deployment**: Runs everything on your local machine. (High resource usage)
2. **Remote NAS Deployment**: Offloads compute to your NAS, controls from local. (Recommended for performance)

### Option A: Local Deployment (Standard)

All Docker commands **must** be run with `sudo` unless you have configured rootless Docker.

#### Step 1: Deploy ELK Stack

1. **Start the Stack:**
   ```bash
   cd elk
   sudo docker compose -f docker-compose-elk.yml up -d
   ```

2. **Monitor Startup:**
   ```bash
   sudo docker compose -f docker-compose-elk.yml logs -f
   ```
   Wait for Kibana to show "Kibana is now available".

3. **Verify Services:**
   ```bash
   sudo docker compose -f docker-compose-elk.yml ps
   ```

4. **Access Kibana:**
   - URL: http://localhost:5601
   - Username: `elastic`
   - Password: (the one you set in ELASTIC_PASSWORD)

#### Step 2: Deploy OpenCTI

1. **Start OpenCTI:**
   ```bash
   cd ../opencti
   sudo docker compose -f docker-compose-opencti.yml up -d
   ```

2. **Monitor Startup:**
   ```bash
   sudo docker compose -f docker-compose-opencti.yml logs -f opencti
   ```
   *Note: Initialization can take 5-10 minutes.*

3. **Access OpenCTI:**
   - URL: http://localhost:8080
   - Login with `admin@opencti.io` and your password.

### Option B: Remote NAS Deployment (Offload Compute)

This option uses your NAS (e.g., Ugreen) to run the heavy containers while you access them from your local machine.

1. **Run the Remote Deploy Script:**
   ```bash
   ./deploy_remote.sh
   ```

2. **Configure NAS (First Run):**
   - Enter your **NAS Username** and **IP Address** when prompted.
   - The script will set up SSH keys for passwordless access.

3. **Deploy:**
   - Select **Option 3) Start EVERYTHING on NAS** from the menu.
   - The script will:
     - Sync configurations to the NAS.
     - Start containers on the remote Docker engine.
     - Establish SSH tunnels so you can access services locally.

4. **Access:**
   - **Kibana**: http://localhost:5601
   - **OpenCTI**: http://localhost:8080
   *(Traffic is tunneled securely to your NAS)*

5. **Stop/Manage:**
   - Run `./deploy_remote.sh` again to view stats or stop containers.

---
##Starting and Stopping
To stop the ELK stack and OpenCTI, run:
```bash
sudo docker compose -f elk/docker-compose-elk.yml stop
sudo docker compose -f opencti/docker-compose-opencti.yml stop
```
To start the ELK stack and OpenCTI, run:
```bash
sudo docker compose -f elk/docker-compose-elk.yml start
sudo docker compose -f opencti/docker-compose-opencti.yml start
```
## Troubleshooting

### "Security Exception" or Auth Errors in Kibana
- Issue: Kibana cannot authenticate with Elasticsearch.
- Fix: Ensure `setup.sh` ran successfully and generated a token.
- Fix: Use `setup.sh` to enforce `COMPOSE_PROJECT_NAME=honeypot` in `.env` so volumes map correctly.
- Fix: Check `.env` exists in `elk/.env` (symlinked).

### OpenCTI "Container Name Conflict"
- Issue: "can't set container_name and worker as container name must be unique".
- Fix: Ensure `container_name` is removed from the `worker` service in your docker-compose file to allow scaling.
