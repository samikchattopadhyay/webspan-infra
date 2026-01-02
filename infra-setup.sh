#!/bin/bash

# Infrastructure Setup Script (Script 2)
# This script sets up infrastructure services (MySQL, Redis, MinIO)
# Run this script ONCE after VPS initial setup
# Run as user 'samik' after SSH'ing into the server

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
APP_DIR="/var/www/html"
DATA_REPO="https://github.com/samikchattopadhyay/webspan-infra.git"
CREDS_REPO="https://github.com/samikchattopadhyay/webspan-creds.git"
TENANT_REPO="https://github.com/samikchattopadhyay/webspan-tenant.git"

print_header() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  Infrastructure Setup${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

print_step() {
    echo -e "${BLUE}[Step]${NC} $1..."
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if running as non-root user
if [ "$EUID" -eq 0 ]; then 
    print_error "Please run as user 'samik' (not root)"
    exit 1
fi

print_header

# Step 1: Create application directory
print_step "Creating application directory: $APP_DIR"
sudo mkdir -p $APP_DIR
sudo chown $USER:$USER $APP_DIR
print_success "Application directory created"

# Step 2: Clone webspan-infra repository
print_step "Cloning webspan-infra repository"
cd $APP_DIR
if [ -d "webspan-infra" ]; then
    print_success "webspan-infra repository already exists"
    cd webspan-infra
    git pull origin main || true
else
    git clone $DATA_REPO webspan-infra
    cd webspan-infra
fi
print_success "webspan-infra repository cloned"

# Step 3: Clone credentials repository
print_step "Cloning credentials repository"
cd $APP_DIR
if [ -d "webspan-creds" ]; then
    print_success "webspan-creds repository already exists"
    cd webspan-creds
    git pull origin main || true
else
    git clone $CREDS_REPO webspan-creds
    cd webspan-creds
fi
print_success "Credentials repository cloned"

# Step 4: Setup .env file for infrastructure
print_step "Setting up .env file for infrastructure services"
cd $APP_DIR/webspan-infra
if [ ! -f ".env" ]; then
    if [ -f "$APP_DIR/webspan-creds/.env" ]; then
        # Copy .env from credentials repository
        cp "$APP_DIR/webspan-creds/.env" .env
        print_success ".env file copied from credentials repository"
    else
        print_error ".env file not found in credentials repository"
        echo "Please ensure .env file exists in webspan-creds repository"
        exit 1
    fi
else
    print_success ".env file already exists"
fi

# Step 5: Create Docker network
print_step "Creating Docker network: webspan-net"
if docker network inspect webspan-net >/dev/null 2>&1; then
    print_success "Network webspan-net already exists"
else
    docker network create webspan-net
    print_success "Network webspan-net created"
fi

# Step 6: Create external HDD mount directories
print_step "Creating external HDD mount directories"
sudo mkdir -p /mnt/external-hdd/webspan-infra/{mysql,redis,minio}
sudo chown -R 999:999 /mnt/external-hdd/webspan-infra/mysql
sudo chown -R 999:999 /mnt/external-hdd/webspan-infra/redis
sudo chown -R 1000:1000 /mnt/external-hdd/webspan-infra/minio
print_success "External HDD directories created"

# Step 7: Start infrastructure containers
print_step "Starting infrastructure containers"
cd $APP_DIR/webspan-infra
docker compose up -d
print_success "Infrastructure containers started"

# Step 8: Wait for services to be ready
print_step "Waiting for services to be ready"
sleep 10

# Step 9: Test services
print_step "Testing services"

# Load .env variables for testing
cd $APP_DIR/webspan-infra
if [ -f ".env" ]; then
    set -a
    source .env
    set +a
fi

# Test MySQL
if docker exec webspan_mysql mysqladmin ping -h localhost -u root -p"${DB_ROOT_PASSWORD}" >/dev/null 2>&1; then
    print_success "MySQL is running"
else
    print_error "MySQL health check failed"
    docker compose logs mysql
fi

# Test Redis
if docker exec webspan_redis redis-cli ping >/dev/null 2>&1; then
    print_success "Redis is running"
else
    print_error "Redis health check failed"
    docker compose logs redis
fi

# Test MinIO
if curl -f http://localhost:9000/minio/health/live >/dev/null 2>&1; then
    print_success "MinIO is running"
else
    print_error "MinIO health check failed"
    docker compose logs minio
fi

# Step 10: Clone webspan-tenant repository
print_step "Cloning webspan-tenant repository"
cd $APP_DIR
if [ -d "webspan-tenant" ]; then
    print_success "webspan-tenant repository already exists"
    cd webspan-tenant
    git pull origin main || true
else
    git clone $TENANT_REPO webspan-tenant
    cd webspan-tenant
fi
print_success "webspan-tenant repository cloned"

# Final Summary
echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Infrastructure Setup Complete!${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "${GREEN}✓${NC} webspan-infra repository cloned to $APP_DIR/webspan-infra"
echo -e "${GREEN}✓${NC} webspan-creds repository cloned to $APP_DIR/webspan-creds"
echo -e "${GREEN}✓${NC} webspan-tenant repository cloned to $APP_DIR/webspan-tenant"
echo -e "${GREEN}✓${NC} Docker network webspan-net created"
echo -e "${GREEN}✓${NC} Infrastructure containers started and tested"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo -e "  1. Verify services: ${CYAN}cd $APP_DIR/webspan-infra && docker compose ps${NC}"
echo -e "  2. View logs: ${CYAN}cd $APP_DIR/webspan-infra && docker compose logs${NC}"
echo -e "  3. Run application deployment script: ${CYAN}cd $APP_DIR/webspan-tenant && ./docker/deploy-prod.sh${NC}"
echo ""

exit 0

