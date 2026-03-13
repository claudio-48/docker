#!/bin/bash
set -e

mkdir -p secrets

# Genera password PostgreSQL
openssl rand -base64 32 > secrets/psql_password
chmod 600 secrets/psql_password

# Chiedi password SMTP
read -sp "Inserisci password SMTP: " SMTP_PASS
echo
echo "$SMTP_PASS" > secrets/smtp_password
chmod 600 secrets/smtp_password

echo "Secrets creati in directory ./secrets/"
