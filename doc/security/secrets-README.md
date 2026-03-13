# Secrets Setup Guide

This directory contains sensitive credentials and must be configured before deploying.

## 🔐 Security Notice

**NEVER commit actual secrets to Git!**

All files except `*.example` are in `.gitignore`.

If using `git-crypt`, secrets are encrypted automatically.

---

## Quick Setup

### 1. Copy Example Files

```bash
cd secrets/
cp psql_password.example psql_password
```

### 2. Edit with Real Values

```bash
# Generate strong password
openssl rand -base64 32

# Edit file
nano psql_password
# Paste the generated password
```

### 3. Set Correct Permissions

```bash
chmod 600 psql_password
```

### 4. Verify

```bash
# Should show only you can read/write
ls -la psql_password
# Output: -rw------- 1 user group ... psql_password
```

---

## Files

| File | Description | Required |
|------|-------------|----------|
| `psql_password` | PostgreSQL admin password | ✅ Yes |
| `psql_password.example` | Template (safe to commit) | ℹ️ Template |
| `README.md` | This file | ℹ️ Docs |

---

## Password Requirements

### PostgreSQL Password

- **Minimum:** 32 characters
- **Recommended:** 64 characters
- **Format:** Random alphanumeric + special chars
- **Generate:** `openssl rand -base64 48`

**Example generation:**
```bash
openssl rand -base64 48 > psql_password
chmod 600 psql_password
```

---

## Security Best Practices

### ✅ DO

- Use password managers (1Password, Bitwarden)
- Generate random passwords
- Rotate passwords every 3-6 months
- Keep backups encrypted
- Use different passwords per environment

### ❌ DON'T

- Reuse passwords
- Use dictionary words
- Share passwords via email/Slack
- Commit secrets to Git (unless using git-crypt)
- Use short passwords (<32 chars)

---

## git-crypt Setup (Recommended)

If your repository uses `git-crypt`, secrets are encrypted automatically:

```bash
# Check if git-crypt is active
git-crypt status

# Secrets shown as encrypted:
# encrypted: secrets/psql_password
```

**Setup for new team member:**

```bash
# Receive git-crypt-key.bin from team lead
git-crypt unlock /path/to/git-crypt-key.bin

# Secrets automatically decrypted!
cat secrets/psql_password  # Shows actual password
```

---

## Backup & Restore

### Create Backup

```bash
# From project root
./scripts/backup-secrets.sh

# Creates encrypted backup:
# ~/secrets-backup/oacs-secrets-YYYYMMDD-HHMMSS.tar.gz.gpg
```

### Restore Backup

```bash
./scripts/restore-secrets.sh ~/secrets-backup/oacs-secrets-*.tar.gz.gpg
```

---

## Troubleshooting

### Permission Denied

```bash
# Fix permissions
chmod 600 secrets/psql_password
```

### File Not Found in Container

```bash
# Verify mount
docker compose config | grep secrets

# Should show:
#   - ./secrets:/run/secrets:ro
```

### Password Not Working

```bash
# Test PostgreSQL connection
docker exec prod-db-1 psql -U postgres -c '\l'

# If fails, verify password matches:
cat secrets/psql_password
```

### Forgot to Copy Example

```bash
# Recreate from template
cp psql_password.example psql_password
# Then edit with real password
```

---

## Environment-Specific Secrets

For multiple environments, use separate secret files:

```
secrets/
├── psql_password.dev
├── psql_password.staging
├── psql_password.prod
└── README.md
```

Update `docker-compose.<env>.yml`:

```yaml
services:
  db:
    volumes:
      - ./secrets/psql_password.${ENV}:/run/secrets/psql_password:ro
```

---

## Need Help?

- Password generation: `openssl rand -base64 32`
- Permissions check: `ls -la secrets/`
- Backup secrets: `./scripts/backup-secrets.sh`
- Rotate password: `./scripts/rotate-db-password.sh`

For team access to git-crypt key, contact: **admin@example.com**
