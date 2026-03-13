#!/bin/bash
# backup-secrets.sh
# Create encrypted backup of all sensitive files
#
# Usage:
#   ./scripts/backup-secrets.sh
#
# Backups are encrypted with GPG and saved to ~/secrets-backup/
# You'll need the passphrase to restore

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${SECRETS_BACKUP_DIR:-$HOME/secrets-backup}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$BACKUP_DIR/oacs-secrets-$TIMESTAMP.tar.gz.gpg"
KEEP_BACKUPS=${KEEP_BACKUPS:-10}

echo ""
echo "════════════════════════════════════════════════════════"
echo "  Secrets Backup (Encrypted)"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Project:     $PROJECT_DIR"
echo "Backup dir:  $BACKUP_DIR"
echo "Output:      oacs-secrets-$TIMESTAMP.tar.gz.gpg"
echo "Keep last:   $KEEP_BACKUPS backups"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Check if GPG is installed
if ! command -v gpg &> /dev/null; then
    warn "GPG not found. Installing..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install gnupg
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt-get update && sudo apt-get install -y gnupg
    else
        error "Please install GPG manually"
        exit 1
    fi
fi

# List files to backup
info "Files to backup:"
echo "  - secrets/"
echo "  - nginx/ssl/"
echo "  - postfix/sasl_passwd"
echo "  - postfix/sender_relay"
echo ""

# Change to project directory
cd "$PROJECT_DIR"

# Verify directories exist
MISSING=0
for dir in secrets nginx/ssl; do
    if [ ! -d "$dir" ]; then
        warn "Directory not found: $dir"
        MISSING=1
    fi
done

if [ $MISSING -eq 1 ]; then
    warn "Some directories are missing. Continue anyway?"
    read -p "(y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Cancelled."
        exit 0
    fi
fi

# Create encrypted backup
info "Creating encrypted backup..."
info "You will be prompted for a passphrase (remember it!)"
echo ""

tar czf - \
  secrets/ \
  nginx/ssl/ \
  postfix/sasl_passwd \
  postfix/sender_relay \
  2>/dev/null \
| gpg --symmetric --cipher-algo AES256 --output "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    info "✓ Backup created successfully"
else
    error "Backup failed!"
    exit 1
fi

# Show backup info
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo ""
info "Backup details:"
echo "  File:  $BACKUP_FILE"
echo "  Size:  $BACKUP_SIZE"
echo "  Date:  $(date)"
echo ""

# Cleanup old backups
info "Cleaning up old backups (keeping last $KEEP_BACKUPS)..."

BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/oacs-secrets-*.tar.gz.gpg 2>/dev/null | wc -l)

if [ "$BACKUP_COUNT" -gt "$KEEP_BACKUPS" ]; then
    DELETED=$(ls -t "$BACKUP_DIR"/oacs-secrets-*.tar.gz.gpg | tail -n +$((KEEP_BACKUPS + 1)) | wc -l)
    ls -t "$BACKUP_DIR"/oacs-secrets-*.tar.gz.gpg | tail -n +$((KEEP_BACKUPS + 1)) | xargs rm -f
    info "✓ Deleted $DELETED old backup(s)"
else
    info "No old backups to delete"
fi

# List all backups
echo ""
info "Available backups:"
ls -lh "$BACKUP_DIR"/oacs-secrets-*.tar.gz.gpg 2>/dev/null | tail -5 || echo "  (none)"

echo ""
echo "════════════════════════════════════════════════════════"
echo "  Backup Complete"
echo "════════════════════════════════════════════════════════"
echo ""
info "✓ Secrets backed up to: $BACKUP_FILE"
warn "🔐 Encrypted with GPG - you'll need the passphrase to restore"
echo ""
info "To restore:"
echo "  ./scripts/restore-secrets.sh $BACKUP_FILE"
echo ""
info "To verify backup:"
echo "  gpg --decrypt $BACKUP_FILE | tar tzf -"
echo ""

# Suggest adding to crontab
if ! crontab -l 2>/dev/null | grep -q "backup-secrets.sh"; then
    echo ""
    warn "Tip: Add to crontab for automatic daily backups:"
    echo "  # Daily backup at 2 AM"
    echo "  0 2 * * * $SCRIPT_DIR/backup-secrets.sh"
    echo ""
fi
