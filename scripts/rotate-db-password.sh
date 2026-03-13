#!/bin/bash
# rotate-db-password.sh
# Rotate PostgreSQL password for security compliance
#
# Usage:
#   ./scripts/rotate-db-password.sh [environment]
#
# Example:
#   ./scripts/rotate-db-password.sh prod
#   ./scripts/rotate-db-password.sh dev

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

# Configuration
ENV=${1:-prod}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SECRET_FILE="$PROJECT_DIR/secrets/psql_password"
BACKUP_DIR="$PROJECT_DIR/secrets/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Container names based on environment
DB_CONTAINER="${ENV}-db-1"
APP_CONTAINER="${ENV}-alter-dev-1"

echo ""
echo "════════════════════════════════════════════════════════"
echo "  PostgreSQL Password Rotation"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Environment:     $ENV"
echo "DB Container:    $DB_CONTAINER"
echo "App Container:   $APP_CONTAINER"
echo "Secret file:     $SECRET_FILE"
echo ""

# Verify containers are running
info "Checking containers..."

if ! docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
    error "Database container $DB_CONTAINER is not running!"
fi

if ! docker ps --format '{{.Names}}' | grep -q "^${APP_CONTAINER}$"; then
    warn "Application container $APP_CONTAINER is not running (will need manual restart)"
fi

# Confirmation
warn "This will change the PostgreSQL password and restart services."
read -p "Continue? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    info "Cancelled."
    exit 0
fi

# Backup old password
info "Backing up current password..."
mkdir -p "$BACKUP_DIR"

if [ -f "$SECRET_FILE" ]; then
    cp "$SECRET_FILE" "$BACKUP_DIR/psql_password.${TIMESTAMP}.backup"
    info "✓ Backup saved to: $BACKUP_DIR/psql_password.${TIMESTAMP}.backup"
else
    warn "No existing password file found"
fi

# Generate new strong password
info "Generating new password..."
NEW_PASSWORD=$(openssl rand -base64 32)

# Update password file
echo "$NEW_PASSWORD" > "$SECRET_FILE"
chmod 600 "$SECRET_FILE"
info "✓ New password written to $SECRET_FILE"

# Update password in PostgreSQL
info "Updating PostgreSQL password..."

docker exec "$DB_CONTAINER" psql -U postgres -c \
  "ALTER USER postgres WITH PASSWORD '$NEW_PASSWORD';" \
  || error "Failed to update password in PostgreSQL"

info "✓ PostgreSQL password updated"

# Restart application container to reload secret
info "Restarting application container..."

docker restart "$APP_CONTAINER" || warn "Failed to restart $APP_CONTAINER"

# Wait for container to be healthy
info "Waiting for application to be ready..."
sleep 5

MAX_ATTEMPTS=12
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$APP_CONTAINER" 2>/dev/null || echo "unknown")
    
    if [ "$HEALTH" == "healthy" ]; then
        info "✓ Application container is healthy"
        break
    fi
    
    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        warn "Application did not become healthy after ${MAX_ATTEMPTS} attempts"
        warn "Check logs: docker logs $APP_CONTAINER"
        break
    fi
    
    echo -n "."
    sleep 5
    ((ATTEMPT++))
done

echo ""
echo "════════════════════════════════════════════════════════"
echo "  Password Rotation Complete"
echo "════════════════════════════════════════════════════════"
echo ""
info "✓ PostgreSQL password rotated successfully"
info "✓ New password saved in: $SECRET_FILE"
info "✓ Old password backed up to: $BACKUP_DIR/"
echo ""
warn "IMPORTANT: If using git-crypt, commit the new password:"
echo "  git add $SECRET_FILE"
echo "  git commit -m 'Rotate PostgreSQL password'"
echo "  git push"
echo ""

# Test connection
info "Testing database connection..."

if docker exec "$APP_CONTAINER" psql -h db -U postgres -c '\l' >/dev/null 2>&1; then
    info "✓ Database connection successful"
else
    error "Database connection failed! Check configuration."
fi

echo ""
info "Password rotation completed successfully! 🔐"
echo ""
