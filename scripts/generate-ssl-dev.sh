#!/bin/bash
# generate-ssl-dev.sh
# Generate self-signed SSL certificates for development environment
#
# Usage:
#   ./scripts/generate-ssl-dev.sh [domain]
#
# Example:
#   ./scripts/generate-ssl-dev.sh alter-dev

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Configuration
DOMAIN=${1:-alter-dev}
SSL_DIR="nginx/ssl"
DAYS_VALID=365

echo ""
echo "════════════════════════════════════════════════════════"
echo "  Generate Self-Signed SSL Certificate"
echo "════════════════════════════════════════════════════════"
echo ""
echo "Domain:      $DOMAIN"
echo "Output dir:  $SSL_DIR"
echo "Valid days:  $DAYS_VALID"
echo ""

# Create directory if not exists
mkdir -p "$SSL_DIR"

# Check if certificates already exist
if [ -f "$SSL_DIR/privkey.pem" ] || [ -f "$SSL_DIR/fullchain.pem" ]; then
    warn "Certificates already exist!"
    read -p "Overwrite existing certificates? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Cancelled. Existing certificates preserved."
        exit 0
    fi
fi

# Generate private key and certificate
info "Generating SSL certificate..."

openssl req -x509 -nodes -days "$DAYS_VALID" -newkey rsa:2048 \
  -keyout "$SSL_DIR/privkey.pem" \
  -out "$SSL_DIR/fullchain.pem" \
  -subj "/C=IT/ST=Lazio/L=Rome/O=Development/CN=$DOMAIN" \
  -addext "subjectAltName=DNS:$DOMAIN,DNS:localhost,IP:127.0.0.1"

# Set correct permissions
chmod 600 "$SSL_DIR/privkey.pem"
chmod 644 "$SSL_DIR/fullchain.pem"

info "✓ SSL certificates generated successfully"
echo ""
echo "Files created:"
echo "  - $SSL_DIR/privkey.pem (private key)"
echo "  - $SSL_DIR/fullchain.pem (certificate)"
echo ""

# Show certificate info
info "Certificate details:"
openssl x509 -in "$SSL_DIR/fullchain.pem" -noout -subject -dates

echo ""
warn "This is a SELF-SIGNED certificate for DEVELOPMENT only!"
warn "Browsers will show security warnings."
warn "For production, use Let's Encrypt or a trusted CA."
echo ""

info "To use with Docker Compose:"
echo "  ./compose.sh dev up -d"
echo "  Access: https://$DOMAIN (accept security warning)"
echo ""
