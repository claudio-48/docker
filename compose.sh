#!/bin/bash
# compose.sh - Helper script for Docker Compose with environment overrides
#
# Usage:
#   ./compose.sh <env> <command> [options]
#
# Environments:
#   dev      - Development (bind mounts, exposed ports)
#   staging  - Staging (like prod but with testing features)
#   prod     - Production (volumes, no exposed ports)
#
# Examples:
#   ./compose.sh dev up -d
#   ./compose.sh prod restart alter-dev
#   ./compose.sh staging logs -f
#   ./compose.sh dev down
#   ./compose.sh prod ps

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Help
show_help() {
    cat << EOF
Docker Compose Environment Helper

Usage: $0 <environment> <command> [options]

Environments:
  dev       Development environment
            - Bind mounts for live code editing
            - Database port exposed (5432)
            - restart: unless-stopped
            
  staging   Staging environment
            - Named volumes (like prod)
            - Database on localhost only
            - OpenACS port exposed on localhost
            - restart: unless-stopped
            
  prod      Production environment
            - Named volumes
            - No ports exposed (nginx only)
            - restart: always

Commands:
  up        Start services
  down      Stop and remove services
  restart   Restart services
  ps        List services
  logs      View logs
  exec      Execute command in service
  ...       Any docker compose command

Examples:
  $0 dev up -d                    # Start dev environment
  $0 prod restart alter-dev       # Restart production instance
  $0 staging logs -f alter-dev    # Follow staging logs
  $0 dev down -v                  # Stop dev and remove volumes
  $0 prod ps                      # List production services
  $0 dev exec alter-dev /bin/sh   # Shell into dev container

Environment Files:
  - docker-compose.yml           (base - common config)
  - docker-compose.dev.yml       (development overrides)
  - docker-compose.staging.yml   (staging overrides)
  - docker-compose.prod.yml      (production overrides)

EOF
    exit 0
}

# Validate
[ $# -lt 2 ] && show_help

ENV=$1
shift

# Validate environment
case "${ENV}" in
    dev|development)
        ENV="dev"
        COMPOSE_FILES="-f docker-compose.yml -f docker-compose.dev.yml"
        ;;
    staging|stage)
        ENV="staging"
        COMPOSE_FILES="-f docker-compose.yml -f docker-compose.staging.yml"
        ;;
    prod|production)
        ENV="prod"
        COMPOSE_FILES="-f docker-compose.yml -f docker-compose.prod.yml"
        ;;
    --help|-h|help)
        show_help
        ;;
    *)
        error "Unknown environment: ${ENV}. Use: dev, staging, prod"
        ;;
esac

# Set project name based on environment (just dev/prod/staging for compatibility)
export COMPOSE_PROJECT_NAME="${ENV}"

# Info
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Docker Compose - ${ENV^^} Environment"
echo "═══════════════════════════════════════════════════════════"
echo ""
info "Project: ${COMPOSE_PROJECT_NAME}"
info "Files:   ${COMPOSE_FILES}"
info "Command: docker compose ${COMPOSE_FILES} $@"
echo ""

# Execute
docker compose ${COMPOSE_FILES} "$@"

if [ "$1" == "down" ]; then
    info "Fixing file permissions..."
    echo "Dopo il down dei container occorre ripristinare la ownership"
    echo "che postfix e nginx hanno impostato a root:root"
    
    sudo chown -R $USER:$USER nginx/ssl/ postfix/ secrets/
    chmod 600 nginx/ssl/privkey.pem postfix/* secrets/*
    chmod 644 nginx/ssl/fullchain.pem
fi
