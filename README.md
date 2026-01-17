# Autonomous Threat Intel & Adaptive Honeypot System
## Docker Configuration Files

This package contains all the necessary Docker Compose configurations and setup files for deploying the ELK Stack and OpenCTI components of your honeypot project.

## 📦 Package Contents

```
honeypot-docker-configs/
├── docker-compose-elk.yml          # ELK Stack (Elasticsearch, Logstash, Kibana)
├── docker-compose-opencti.yml      # OpenCTI Platform with dependencies
├── logstash-config/
│   └── logstash.yml                # Logstash main configuration
├── logstash-pipeline/
│   └── cowrie.conf                 # Cowrie log parsing pipeline
├── kibana-config/
│   └── kibana.yml                  # Kibana configuration
├── setup.sh                        # Automated setup script
├── SETUP_INSTRUCTIONS.md           # Detailed setup guide
└── README.md                       # This file
```

## 🚀 Quick Start

### Option 1: Automated Setup (Recommended)

1. **Run the setup script:**
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

2. **Update passwords in docker-compose files** with the generated credentials from `~/honeypot-project/CREDENTIALS.txt`

3. **Start the services:**
   ```bash
   # ELK Stack
   cd ~/honeypot-project/elk
   docker compose -f docker-compose-elk.yml up -d
   
   # OpenCTI (wait 2-3 minutes after ELK starts)
   cd ~/honeypot-project/opencti
   docker compose -f docker-compose-opencti.yml up -d
   ```

### Option 2: Manual Setup

1. **Create directory structure:**
   ```bash
   mkdir -p ~/honeypot-project/{elk,opencti}
   cd ~/honeypot-project
   ```

2. **Copy all files to the project directory**

3. **Configure system for Elasticsearch:**
   ```bash
   sudo sysctl -w vm.max_map_count=262144
   echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
   ```

4. **Change all default passwords** in both docker-compose files (search for "changeme123")

5. **Start services** (see commands in Option 1, step 3)

## 📖 Documentation

For comprehensive setup instructions, troubleshooting, and next steps, see **SETUP_INSTRUCTIONS.md**

## 🔧 System Requirements

- Ubuntu 22.04 LTS or later
- Minimum 16GB RAM (32GB recommended)
- 50GB+ free disk space
- Docker Desktop or Docker Engine with Docker Compose

## 🔐 Security Notes

**CRITICAL:** Before deployment:

1. ✅ Change ALL default passwords in docker-compose files
2. ✅ Generate new UUIDs for OpenCTI tokens
3. ✅ Never expose services directly to the internet
4. ✅ Use WireGuard VPN for AWS-to-local communication
5. ✅ Review firewall rules

## 📊 Services & Ports

### ELK Stack
- **Elasticsearch**: http://localhost:9200
- **Kibana**: http://localhost:5601
- **Logstash Beats**: 5044
- **Logstash TCP/UDP**: 5000

### OpenCTI
- **OpenCTI Platform**: http://localhost:8080
- **MinIO Console**: http://localhost:9001
- **RabbitMQ Management**: http://localhost:15672

## 🎯 Project Phases

This configuration supports your project outline:

- ✅ **Phase 1**: Secure Infrastructure Setup
  - ELK Stack for log aggregation and visualization
  - OpenCTI for threat intelligence management
  
- 🔄 **Phase 2**: Monitoring & MITRE ATT&CK Mapping
  - Logstash pipeline configured for Cowrie logs
  - MITRE ATT&CK connector included in OpenCTI
  - GeoIP enrichment enabled
  
- 📋 **Phase 3 & 4**: Ready for AI agent integration
  - Elasticsearch API accessible for agents
  - OpenCTI GraphQL API ready
  - Infrastructure prepared for adaptive honeypot features

## 🐛 Common Issues

### Elasticsearch won't start
```bash
# Check and set vm.max_map_count
sudo sysctl -w vm.max_map_count=262144
```

### Out of memory errors
```bash
# Reduce heap sizes in docker-compose files
# Change from -Xms2g -Xmx2g to -Xms1g -Xmx1g
```

### OpenCTI stuck loading
```bash
# Wait 10-15 minutes for initialization
# Check logs: docker compose logs -f opencti
```

### Port already in use
```bash
# Check what's using the port
sudo lsof -i :9200
# Either kill the process or change port in docker-compose
```

## 📚 Useful Commands

```bash
# View all containers
docker ps

# View logs
docker compose logs -f [service_name]

# Stop services
docker compose down

# Remove all data (CAUTION)
docker compose down -v

# Restart specific service
docker compose restart [service_name]

# Check resource usage
docker stats
```

## 🔗 Next Steps

After successful deployment:

1. Set up WireGuard VPN tunnel
2. Deploy Cowrie honeypot on AWS EC2
3. Configure Filebeat to forward logs
4. Create Kibana dashboards
5. Set up OpenCTI threat feeds
6. Begin AI agent development

## 📞 Resources

- [ELK Stack Documentation](https://www.elastic.co/guide/)
- [OpenCTI Documentation](https://docs.opencti.io/)
- [Cowrie Honeypot](https://cowrie.readthedocs.io/)
- [MITRE ATT&CK Framework](https://attack.mitre.org/)

## ⚖️ License & Ethics

This project is for educational and research purposes. Always:
- Comply with AWS Acceptable Use Policy
- Isolate honeypot infrastructure
- Respect data privacy regulations
- Never launch attacks from compromised systems

---

**Happy Hunting! 🐝🔒**
