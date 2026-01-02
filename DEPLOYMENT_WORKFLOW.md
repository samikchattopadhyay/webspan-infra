# WebSpan Deployment Workflow

This document describes the complete three-script deployment workflow for WebSpan application.

## Repository Structure

1. **webspan-tenant** - Application repository (contains Laravel app and `docker/deploy-prod.sh`)
2. **webspan-creds** - Credentials repository (PRIVATE - contains `.env` and `vps-setup/vps-setup.sh`)
3. **webspan-infra** - Infrastructure repository (contains MySQL, Redis, MinIO setup and `infra-setup.sh`)

## Three-Script Deployment Workflow

### Script 1: VPS Initial Setup (`vps-setup.sh`)

**Location**: `webspan-creds/vps-setup/vps-setup.sh`  
**Run as**: root  
**Run**: Once per new VPS server

**What it does:**
- Updates system packages
- Installs Docker, Git, and essential tools
- Creates user `samik` with sudo privileges
- Configures Git credentials
- Hardens SSH security
- Configures firewall (UFW)
- Installs Fail2ban
- Enables automatic security updates

**After completion:**
- SSH into server as user `samik`
- Upload script 2 to `/home/samik`

### Script 2: Infrastructure Setup (`infra-setup.sh`)

**Location**: `webspan-infra/infra-setup.sh`  
**Run as**: user `samik`  
**Run**: Once after VPS setup

**What it does:**
- Clones `webspan-infra` repository to `/var/www/html/webspan-infra`
- Clones `webspan-creds` repository to `/var/www/html/webspan-creds`
- Creates Docker network `webspan-net`
- Creates external HDD mount directories
- Starts infrastructure containers (MySQL, Redis, MinIO)
- Tests that all services are running
- Clones `webspan-tenant` repository to `/var/www/html/webspan-tenant`

**After completion:**
- Infrastructure services are running
- Application repository is ready
- Run script 3 to deploy application

### Script 3: Application Deployment (`deploy-prod.sh`)

**Location**: `webspan-tenant/docker/deploy-prod.sh`  
**Run as**: user `samik`  
**Run**: For each deployment (initial and updates)

**What it does:**
- Checks Docker is running
- Updates application repository (git pull)
- Validates `.env` file (copies from credentials repository)
- Builds production Docker image
- Creates named volumes
- Starts application containers (app, nginx)
- Waits for services
- Prepares public assets
- Runs Laravel optimizations
- Sets file permissions

## Directory Structure on Server

```
/var/www/html/
├── webspan-infra/         # Infrastructure services (MySQL, Redis, MinIO)
│   ├── docker-compose.yml
│   ├── infra-setup.sh
│   └── .env
├── webspan-creds/         # Credentials repository
│   └── .env
└── webspan-tenant/        # Application repository
    ├── docker/
    │   └── deploy-prod.sh
    ├── docker-compose.yml
    └── .env
```

## Network Architecture

All containers connect to the external `webspan-net` network:
- Infrastructure containers: `webspan_mysql`, `webspan_redis`, `webspan_minio`
- Application containers: `laravel_app`, `laravel_nginx`

Application connects to infrastructure using container hostnames:
- `DB_HOST=webspan_mysql`
- `REDIS_HOST=webspan_redis`
- `MINIO_ENDPOINT=webspan_minio:9000`

## Volume Configuration

Infrastructure volumes are mounted to external HDD:
- `/mnt/external-hdd/webspan-infra/mysql`
- `/mnt/external-hdd/webspan-infra/redis`
- `/mnt/external-hdd/webspan-infra/minio`

Application volumes use Docker named volumes (can be moved to external HDD later).

