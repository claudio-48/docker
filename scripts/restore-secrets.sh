#!/bin/bash
# restore-secrets.sh
# Restore secrets from encrypted backup
#
# Usage:
#   ./scripts/restore-secrets.sh <backup-file.tar.gz.gpg>
#
# Example:
#   ./scripts/restore-secrets.sh ~/secrets-backup/oacs-secrets-20250216-143022.tar.gz.gpg

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check arguments
BACKUP_FILE="$1"

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup-file.tar.gz.gpg>"
    echo ""
    echo "Example:"
    echo "  $0 ~/secrets-backup/oacs-secrets-20250216-143022.tar.gz.gpg"
    echo ""
    
    # List available backups
    BACKUP_DIR="${SECRETS_BACKUP_DIR:-$HOME/secrets-backup}"
    if [ -d "$BACKUP_DIR" ]; then
        echo "Available backups:"
        ls -lh "$BACKUP_DIR"/oacs-secrets-*.tar.gz.gpg 2>/dev/null || echo "  (none found)"
        echo ""
    fi
    
    exit 1
fi

# Verify backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    error "Backup file not found: $BACKUP_FILE"
fi

# Configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo ""
echo "════════════════════════════════════════════════════════"
echo "  Restore Secrets from Backup"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Backup file:  $BACKUP_FILE"
echo "Project dir:  $PROJECT_DIR"
echo ""

# Verify GPG is installed
if ! command -v gpg &> /dev/null; then
    error "GPG not found. Please install: brew install gnupg"
fi

# Show backup contents
info "Backup contents:"
gpg --decrypt "$BACKUP_FILE" 2>/dev/null | tar tzf - | head -20
echo ""

# Confirm restore
warn "This will OVERWRITE existing secrets!"
echo ""
read -p "Create backup of current secrets before restore? (recommended) (y/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    info "Backing up current secrets..."
    
    CURRENT_BACKUP_DIR="$PROJECT_DIR/secrets/restore-backups"
    mkdir -p "$CURRENT_BACKUP_DIR"
    
    # Backup current files
    cd "$PROJECT_DIR"
    
    tar czf "$CURRENT_BACKUP_DIR/pre-restore-$TIMESTAMP.tar.gz" \
      secrets/ \
      nginx/ssl/ \
      postfix/sasl_passwd \
      postfix/sender_relay \
      2>/dev/null || warn "Some files missing, continuing..."
    
    info "✓ Current secrets backed up to:"
    echo "    $CURRENT_BACKUP_DIR/pre-restore-$TIMESTAMP.tar.gz"
    echo ""
fi

# Final confirmation
warn "Ready to restore secrets from backup."
read -p "Continue with restore? (yes/no): " -r

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    info "Cancelled. No changes made."
    exit 0
fi

# Change to project directory
cd "$PROJECT_DIR"

# Restore from backup
info "Restoring secrets..."
info "Enter the passphrase you used when creating the backup:"
echo ""

gpg --decrypt "$BACKUP_FILE" 2>/dev/null | tar xzf -

if [ $? -eq 0 ]; then
    info "✓ Secrets restored successfully"
else
    error "Restore failed! Check passphrase and backup file."
fi

# Verify restored files
echo ""
info "Restored files:"

for item in secrets/ nginx/ssl/ postfix/sasl_passwd postfix/sender_relay; do
    if [ -e "$item" ]; then
        echo "  ✓ $item"
    else
        warn "  ✗ $item (not in backup)"
    fi
done

# Fix permissions
info "Setting correct permissions..."

if [ -d "secrets" ]; then
    chmod 700 secrets
    chmod 600 secrets/* 2>/dev/null || true
fi

if [ -d "nginx/ssl" ]; then
    chmod 600 nginx/ssl/*.key 2>/dev/null || true
    chmod 600 nginx/ssl/privkey.pem 2>/dev/null || true
    chmod 644 nginx/ssl/*.crt 2>/dev/null || true
    chmod 644 nginx/ssl/fullchain.pem 2>/dev/null || true
fi

if [ -f "postfix/sasl_passwd" ]; then
    chmod 600 postfix/sasl_passwd
fi

if [ -f "postfix/sender_relay" ]; then
    chmod 600 postfix/sender_relay
fi

info "✓ Permissions updated"

echo ""
echo "════════════════════════════════════════════════════════"
echo "  Restore Complete"
echo "════════════════════════════════════════════════════════"
echo ""
info "✓ Secrets restored from: $BACKUP_FILE"
echo ""
warn "Next steps:"
echo "  1. Verify secrets are correct"
echo "  2. If using git-crypt, files should auto-encrypt on commit"
echo "  3. Restart services to use new secrets:"
echo "     ./compose.sh <env> restart"
echo ""

# Suggest testing
info "Test database connection:"
echo "  docker exec <env>-db-1 psql -U postgres -c '\\l'"
echo ""
info "Test nginx config:"
echo "  docker exec <env>-nginx-1 nginx -t"
echo ""
