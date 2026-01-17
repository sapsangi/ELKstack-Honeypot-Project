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

1. **Create project directory structure:**
   ```bash
   mkdir -p ~/honeypot-project
   cd ~/honeypot-project
   
   # Create subdirectories
   mkdir -p elk/logstash/config
   mkdir -p elk/logstash/pipeline
   mkdir -p elk/kibana/config
   mkdir -p opencti
   ```

2. **Copy the configuration files** (provided separately) to their respective locations:
   ```
   ~/honeypot-project/
   ├── elk/
   │   ├── docker-compose-elk.yml
   │   ├── logstash/
   │   │   ├── config/
   │   │   │   └── logstash.yml
   │   │   └── pipeline/
   │   │       └── cowrie.conf
   │   └── kibana/
   │       └── config/
   │           └── kibana.yml
   └── opencti/
       └── docker-compose-opencti.yml
   ```

---

## Configuration & Security

### **CRITICAL: Change Default Passwords**

Before starting the services, you MUST change all default passwords in the docker-compose files:

#### ELK Stack (`docker-compose-elk.yml`):
- `ELASTIC_PASSWORD`: Change `changeme123` to a strong password
- **Important**: If your password contains a `$` character, you must escape it as `$$` (e.g. `my$password` becomes `my$$password`).
- Update this password in ALL services (elasticsearch, logstash, kibana) UNLESS configured to use tokens.

### Kibana Service Token (Required)
Newer versions of Elasticsearch require a **service account token** for Kibana instead of a username/password.
1. Start Elasticsearch only: `docker compose -f docker-compose-elk.yml up -d elasticsearch`
2. Generate the token:
   ```bash
   sudo docker compose -f docker-compose-elk.yml exec elasticsearch bin/elasticsearch-service-tokens create elastic/kibana kibana-token
   ```
3. Update `docker-compose-elk.yml`:
   - Remove `ELASTICSEARCH_USERNAME` and `ELASTICSEARCH_PASSWORD` from the `kibana` service.
   - Add `ELASTICSEARCH_SERVICEACCOUNTTOKEN=<your_token>` to the environment variables.

#### OpenCTI (`docker-compose-opencti.yml`):
- `MINIO_ROOT_PASSWORD`: Change `changeme123`
- `RABBITMQ_DEFAULT_PASS`: Change `changeme123`
- `APP__ADMIN__PASSWORD`: Change `changeme123`
- `APP__ADMIN__TOKEN`: Generate a new UUID (use `uuidgen` command)
- `OPENCTI_TOKEN`: Use the same token as APP__ADMIN__TOKEN
- `CONNECTOR_ID`: Generate unique IDs for each connector

#### (.env) Environment Variables
The `setup.sh` script automatically generates a `.env` file containing:
- `OPENCTI_TOKEN`
- `CONNECTOR_ID`

These are used by `docker-compose-opencti.yml`. You do not need to manually edit these unless you want to rotate tokens.

### System Configuration

1. **Increase virtual memory for Elasticsearch:**
   ```bash
   sudo sysctl -w vm.max_map_count=262144
   
   # Make it permanent
   echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
   ```

2. **Increase file descriptor limits:**
   ```bash
   echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
   echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf
   ```

---

## Deployment Instructions

### Step 1: Deploy ELK Stack

1. **Start Elasticsearch (if not already running):**
   ```bash
   docker compose -f docker-compose-elk.yml up -d elasticsearch
   ```
   *Wait for it to become healthy.*

2. **Configure Kibana Token:**
   (See "Kibana Service Token" section above if you haven't done this yet).

3. **Start Full ELK Stack:**
   ```bash
   docker compose -f docker-compose-elk.yml up -d
   ```

3. **Monitor startup logs:**
   ```bash
   docker compose -f docker-compose-elk.yml logs -f
   ```
   
   Wait until you see messages indicating services are ready (usually 2-3 minutes).

4. **Verify services are running:**
   ```bash
   docker compose -f docker-compose-elk.yml ps
   ```

5. **Access Kibana:**
   - Open browser: http://localhost:5601
   - Username: `elastic`
   - Password: (the one you set in ELASTIC_PASSWORD)

6. **Create index pattern in Kibana:**
   - Navigate to: Management → Stack Management → Kibana → Data Views
   - Click "Create data view"
   - Name: `honeypot-logs`
   - Index pattern: `honeypot-logs-*`
   - Timestamp field: `@timestamp`
   - Click "Save data view"

### Step 2: Deploy OpenCTI

1. **Start OpenCTI stack:**
   ```bash
   docker compose -f docker-compose-opencti.yml up -d
   ```

3. **Monitor startup logs:**
   ```bash
   docker compose -f docker-compose-opencti.yml logs -f opencti
   ```
   
   **Note:** OpenCTI takes 5-10 minutes to fully initialize. Wait for message: "API ready on port 8080"

4. **Verify all services are running:**
   ```bash
   docker compose -f docker-compose-opencti.yml ps
   ```

5. **Access OpenCTI:**
   - Open browser: http://localhost:8080
   - Username: `admin@opencti.io`
   - Password: (the one you set in APP__ADMIN__PASSWORD)

6. **Verify MITRE connector:**
   - Navigate to: Data → Connectors
   - Look for "MITRE ATT&CK" connector (should show as active)
   - It will automatically import MITRE ATT&CK framework (takes ~10 minutes)

---

## Testing the Setup

### Test Elasticsearch
```bash
curl -u elastic:YOUR_PASSWORD http://localhost:9200/_cluster/health?pretty
```

Expected response shows cluster status as "yellow" or "green".

### Test Logstash
```bash
# Send a test event
echo '{"message":"test","timestamp":"2025-01-08T12:00:00Z"}' | \
  nc localhost 5000
```

### Check logs in Kibana
1. Open Kibana: http://localhost:5601
2. Navigate to: Analytics → Discover
3. Select the `honeypot-logs` data view
4. You should see incoming logs (once honeypot is connected)

### Test OpenCTI API
```bash
curl -H "Authorization: Bearer YOUR_OPENCTI_TOKEN" \
  http://localhost:8080/graphql \
  -d '{"query": "{me {name}}"}'
```

---

## Managing the Services

### View all running containers:
```bash
docker ps
```

### Stop services:
```bash
# Stop ELK
cd ~/honeypot-project/elk
docker compose -f docker-compose-elk.yml down

# Stop OpenCTI
cd ~/honeypot-project/opencti
docker compose -f docker-compose-opencti.yml down
```

### Start services:
```bash
# Start ELK
cd ~/honeypot-project/elk
docker compose -f docker-compose-elk.yml up -d

# Start OpenCTI
cd ~/honeypot-project/opencti
docker compose -f docker-compose-opencti.yml up -d
```

### View logs:
```bash
# ELK logs
docker compose -f docker-compose-elk.yml logs -f [service_name]

# OpenCTI logs
docker compose -f docker-compose-opencti.yml logs -f [service_name]
```

### Restart a specific service:
```bash
docker compose restart [service_name]
```

### Remove all data and reset (CAUTION):
```bash
# Stop services first
docker compose down

# Remove volumes (this deletes all data!)
docker compose down -v
```

---

## Connecting Your AWS Honeypot

Once your local stack is running, you'll configure your AWS EC2 honeypot to send logs:

### On AWS EC2 Instance:

1. **Install Filebeat:**
   ```bash
   curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.11.3-amd64.deb
   sudo dpkg -i filebeat-8.11.3-amd64.deb
   ```

2. **Configure Filebeat** (`/etc/filebeat/filebeat.yml`):
   ```yaml
   filebeat.inputs:
   - type: log
     enabled: true
     paths:
       - /home/cowrie/cowrie/var/log/cowrie/cowrie.json*
     json.keys_under_root: true
     json.add_error_key: true
   
   output.logstash:
     hosts: ["YOUR_WIREGUARD_IP:5044"]
   ```

3. **Start Filebeat:**
   ```bash
   sudo systemctl enable filebeat
   sudo systemctl start filebeat
   ```

---

## Troubleshooting

### Elasticsearch won't start:
```bash
# Check vm.max_map_count
sysctl vm.max_map_count

# Should be at least 262144
sudo sysctl -w vm.max_map_count=262144
```

### Services crash due to memory:
```bash
# Check available memory
free -h

# Reduce Java heap sizes in docker-compose files if needed
ES_JAVA_OPTS=-Xms1g -Xmx1g  # Instead of 2g
```

### Port conflicts:
```bash
# Check what's using a port
sudo lsof -i :9200

# Kill the process or change the port in docker-compose
```

### OpenCTI not loading:
```bash
# Check all dependencies are healthy
docker compose -f docker-compose-opencti.yml ps

# Check opencti logs
docker compose -f docker-compose-opencti.yml logs opencti

# Common issue: waiting for dependencies to be ready
# Solution: Wait 10-15 minutes for full initialization
```

### Reset Elasticsearch password:
```bash
docker exec -it elasticsearch /usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic
```

---

## Resource Monitoring

### Check resource usage:
```bash
docker stats
```

### Optimize for lower resource usage:
1. Reduce Elasticsearch heap size
2. Reduce number of OpenCTI workers (change replicas: 3 to replicas: 1)
3. Disable monitoring in Kibana
4. Use lighter alternative to OpenCTI Elasticsearch (PostgreSQL)

---

## Next Steps

After successful deployment:

1. ✅ Set up WireGuard VPN tunnel between AWS and local server
2. ✅ Deploy Cowrie honeypot on AWS EC2
3. ✅ Configure Filebeat to forward logs through tunnel
4. ✅ Create Kibana dashboards for visualization
5. ✅ Set up OpenCTI threat intelligence feeds
6. ✅ Begin Phase 3: AI agent development

---

## Useful URLs

- **Kibana**: http://localhost:5601
- **Elasticsearch**: http://localhost:9200
- **OpenCTI**: http://localhost:8080
- **MinIO Console**: http://localhost:9001
- **RabbitMQ Management**: http://localhost:15672

---

## Support & Documentation

- ELK Stack: https://www.elastic.co/guide/index.html
- OpenCTI: https://docs.opencti.io/
- Cowrie: https://cowrie.readthedocs.io/
- Docker Compose: https://docs.docker.com/compose/

---

## Security Reminders

⚠️ **CRITICAL SECURITY NOTES:**

1. **Never expose Elasticsearch, Kibana, or OpenCTI directly to the internet**
2. **Change ALL default passwords before deployment**
3. **Use WireGuard VPN for all AWS → Local communication**
4. **Regularly update Docker images for security patches**
5. **Implement firewall rules (UFW) to restrict access**
6. **Enable SSL/TLS for production deployments**
7. **Regularly backup OpenCTI and Elasticsearch data**
8. **Review AWS Security Groups - only expose honeypot ports**

---

Good luck with your project! 🔒🐝
