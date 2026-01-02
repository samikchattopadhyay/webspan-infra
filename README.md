# WebSpan Infrastructure Services

This repository contains Docker Compose configuration for infrastructure services (MySQL, Redis, MinIO) used by the WebSpan application.

## Overview

This repository is part of a **three-repository deployment architecture**:

1. **`webspan-infra`** (this repository) - Infrastructure services (MySQL, Redis, MinIO)
2. **`webspan-tenant`** - Application code and Docker configuration
3. **`webspan-creds`** - Production credentials and VPS setup scripts

## Services

- **MySQL 8.0** - Database server
- **Redis 7** - Cache and session store
- **MinIO** - S3-compatible object storage

## Architecture

### Network Configuration

All services connect to an external Docker network `webspan-net`:
- Network must be created before starting services
- Application containers connect to this network to access infrastructure services
- Services are accessible via hostnames: `webspan_mysql`, `webspan_redis`, `webspan_minio`

### Volume Configuration

Volumes are configured to use bind mounts pointing to external HDD (production) or local directories (development):
- MySQL: `/mnt/external-hdd/webspan-infra/mysql` (production) or `./data/mysql` (development)
- Redis: `/mnt/external-hdd/webspan-infra/redis` (production) or `./data/redis` (development)
- MinIO: `/mnt/external-hdd/webspan-infra/minio` (production) or `./data/minio` (development)

## Prerequisites

- Docker and Docker Compose installed
- External network `webspan-net` created (or use `infra-setup.sh` to create it)
- External HDD mounted at `/mnt/external-hdd/webspan-infra/` (production) or local directories (development)

## Quick Setup

### Option 1: Using infra-setup.sh (Recommended)

The `infra-setup.sh` script automates the entire infrastructure setup:

```bash
# Make script executable
chmod +x infra-setup.sh

# Run infrastructure setup
./infra-setup.sh
```

**What the script does:**
1. Clones `webspan-infra` repository to `/var/www/html/webspan-infra`
2. Clones `webspan-creds` repository to `/var/www/html/webspan-creds`
3. Creates Docker network `webspan-net` (if it doesn't exist)
4. Creates external HDD mount directories (optional)
5. Copies `.env` from credentials repository to infrastructure repository
6. Starts infrastructure containers (MySQL, Redis, MinIO)
7. Tests all services are running
8. Clones `webspan-tenant` to `/var/www/html/webspan-tenant` (if not already present)

### Option 2: Manual Setup

1. **Copy `.env.example` to `.env` and configure:**
   ```bash
   cp .env.example .env
   nano .env
   ```

2. **Create external network (if not exists):**
   ```bash
   docker network create --driver bridge --subnet 172.20.0.0/16 --gateway 172.20.0.1 webspan-net
   ```

3. **Create volume directories:**
   
   **For Production (External HDD):**
   ```bash
   sudo mkdir -p /mnt/external-hdd/webspan-infra/{mysql,redis,minio}
   sudo chown -R 999:999 /mnt/external-hdd/webspan-infra/mysql
   sudo chown -R 999:999 /mnt/external-hdd/webspan-infra/redis
   sudo chown -R 1000:1000 /mnt/external-hdd/webspan-infra/minio
   ```
   
   **For Development (Local):**
   ```bash
   mkdir -p ./data/{mysql,redis,minio}
   ```

4. **Start services:**
   ```bash
   docker compose up -d
   ```

5. **Verify services are running:**
   ```bash
   docker compose ps
   docker compose logs
   ```

## Service Configuration

### MySQL

- **Hostname**: `webspan_mysql`
- **Port**: 3306 (internal)
- **Default Database**: Configured via `MYSQL_DATABASE` in `.env`
- **Root User**: `root` (password from `DB_ROOT_PASSWORD` in `.env`)
- **Application User**: Configured via `DB_USERNAME` and `DB_PASSWORD` in `.env`

### Redis

- **Hostname**: `webspan_redis`
- **Port**: 6379 (internal)
- **Password**: Configured via `REDIS_PASSWORD` in `.env` (optional)

### MinIO

- **Hostname**: `webspan_minio`
- **API Port**: 9000 (internal)
- **Console Port**: 9001 (internal, accessible via nginx proxy in application)
- **Root User**: Configured via `MINIO_ROOT_USER` in `.env`
- **Root Password**: Configured via `MINIO_ROOT_PASSWORD` in `.env`

## Network

All services connect to the external `webspan-net` network, allowing communication with the application containers.

**Create network:**
```bash
docker network create --driver bridge --subnet 172.20.0.0/16 --gateway 172.20.0.1 webspan-net
```

**Verify network exists:**
```bash
docker network ls | grep webspan-net
```

## Health Checks

All services include health checks:
- MySQL: `mysqladmin ping`
- Redis: `redis-cli ping`
- MinIO: HTTP health endpoint

## Resource Limits

Services have resource limits configured:
- MySQL: 1 CPU, 1GB RAM
- Redis: 0.5 CPU, 256MB RAM
- MinIO: 1 CPU, 512MB RAM

## Volume Management

### Changing Volume Paths

To change the mount point, update the `device` path in `docker-compose.yml` volumes section:

```yaml
volumes:
  mysql_data:
    driver: local
    driver_opts:
      type: none
      device: /path/to/your/mysql/data
      o: bind
```

### Backup

**MySQL Backup:**
```bash
docker compose exec mysql mysqldump -u root -p --all-databases > backup.sql
```

**Redis Backup:**
```bash
docker compose exec redis redis-cli --rdb /data/dump.rdb
```

**MinIO Backup:**
Use MinIO client (`mc`) to sync buckets to external storage.

## Troubleshooting

### Services Not Starting

```bash
# Check logs
docker compose logs mysql
docker compose logs redis
docker compose logs minio

# Check container status
docker compose ps

# Restart services
docker compose restart
```

### Network Issues

```bash
# Verify network exists
docker network inspect webspan-net

# Recreate network (WARNING: This will disconnect all containers)
docker network rm webspan-net
docker network create --driver bridge --subnet 172.20.0.0/16 --gateway 172.20.0.1 webspan-net
```

### Permission Issues

```bash
# Fix MySQL permissions
sudo chown -R 999:999 /mnt/external-hdd/webspan-infra/mysql

# Fix Redis permissions
sudo chown -R 999:999 /mnt/external-hdd/webspan-infra/redis

# Fix MinIO permissions
sudo chown -R 1000:1000 /mnt/external-hdd/webspan-infra/minio
```

### Connection Testing

```bash
# Test MySQL connection
docker compose exec mysql mysql -u root -p -e "SELECT 1"

# Test Redis connection
docker compose exec redis redis-cli ping

# Test MinIO
docker compose exec minio mc alias list
```

## Integration with Application

The application (`webspan-tenant`) connects to these services via the `webspan-net` network:

**In application `.env`:**
```env
DB_HOST=webspan_mysql
REDIS_HOST=webspan_redis
AWS_ENDPOINT=http://webspan_minio:9000
```

## Production Deployment

For production deployment, infrastructure services are set up as part of the three-script deployment workflow:

1. **VPS Setup** - Run `vps-setup.sh` from `webspan-creds` repository (one-time)
2. **Infrastructure Setup** - Run `infra-setup.sh` from this repository (one-time)
3. **Application Deployment** - Run `docker/deploy-prod.sh` from `webspan-tenant` repository (per deployment)

See the application's [Production Deployment Guide](../webspan-tenant/docs/deployment/PRODUCTION_DEPLOYMENT_GUIDE.md) for complete instructions.

## Maintenance

### Updating Services

```bash
# Pull latest images
docker compose pull

# Recreate containers with new images
docker compose up -d --force-recreate
```

### Viewing Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f mysql
docker compose logs -f redis
docker compose logs -f minio
```

### Stopping Services

```bash
# Stop services (keeps volumes)
docker compose stop

# Stop and remove containers (keeps volumes)
docker compose down

# Stop and remove containers and volumes (WARNING: Deletes all data)
docker compose down -v
```

## Security Considerations

- Change all default passwords in production
- Use strong, randomly generated passwords
- Restrict network access (services only accessible via `webspan-net`)
- Regular security updates for Docker images
- Backup strategy for all volumes
- Monitor service health and logs

## License

This infrastructure configuration is part of the WebSpan project.
