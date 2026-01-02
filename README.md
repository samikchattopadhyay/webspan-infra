# WebSpan Infrastructure Services

This repository contains Docker Compose configuration for infrastructure services (MySQL, Redis, MinIO) used by the WebSpan application.

## Services

- **MySQL 8.0** - Database server
- **Redis 7** - Cache and session store
- **MinIO** - S3-compatible object storage

## Prerequisites

- Docker and Docker Compose installed
- External network `webspan-net` created
- External HDD mounted at `/mnt/external-hdd/webspan-infra/` (or update volume paths in `docker-compose.yml`)

## Setup

1. Copy `.env.example` to `.env` and configure:
```bash
cp .env.example .env
nano .env
```

2. Create external network (if not exists):
```bash
docker network create webspan-net
```

3. Create volume directories on external HDD:
```bash
sudo mkdir -p /mnt/external-hdd/webspan-infra/{mysql,redis,minio}
sudo chown -R 999:999 /mnt/external-hdd/webspan-infra/mysql
sudo chown -R 999:999 /mnt/external-hdd/webspan-infra/redis
sudo chown -R 1000:1000 /mnt/external-hdd/webspan-infra/minio
```

4. Start services:
```bash
docker compose up -d
```

5. Verify services are running:
```bash
docker compose ps
docker compose logs
```

## Volume Configuration

Volumes are configured to use bind mounts pointing to external HDD:
- MySQL: `/mnt/external-hdd/webspan-infra/mysql`
- Redis: `/mnt/external-hdd/webspan-infra/redis`
- MinIO: `/mnt/external-hdd/webspan-infra/minio`

To change the mount point, update the `device` path in `docker-compose.yml` volumes section.

## Network

All services connect to the external `webspan-net` network, allowing communication with the application containers.

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

