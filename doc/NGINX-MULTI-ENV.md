# Nginx Multi-Environment Configuration

## Problema

Nginx config con `server_name` diverso per ambiente:
- Dev: `alter-dev`, `localhost`
- Staging: `staging.alter-web.it`
- Prod: `docker.alter-web.it`

## Soluzione: Template con Variabili d'Ambiente ⭐

### Come Funziona

L'immagine `nginx:alpine` ufficiale supporta **template substitution**:

1. File `.template` in `/etc/nginx/templates/`
2. Nginx sostituisce `${VAR}` con environment variables
3. Output generato in `/etc/nginx/conf.d/`

### Setup

#### Struttura Directory

```
nginx/
├── nginx.conf                          # Principale (comune)
├── conf.d/
│   └── alter-dev.conf.template         # Template con ${VAR}
├── ssl/
│   ├── fullchain.pem
│   └── privkey.pem
└── mime.types
```

#### Template: alter-dev.conf.template

```nginx
server {
    listen 80;
    server_name ${SERVER_NAME};
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${SERVER_NAME};

    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    
    location / {
        proxy_pass http://${BACKEND_HOST}:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

**Variabili usate:**
- `${SERVER_NAME}` - hostname (alter-dev, docker.alter-web.it, etc.)
- `${BACKEND_HOST}` - container backend (alter-dev)

#### docker-compose.yml Modificato

```yaml
services:
  nginx:
    volumes:
      # Templates directory (non conf.d!)
      - ./nginx/conf.d:/etc/nginx/templates:ro
    
    environment:
      SERVER_NAME: localhost
      BACKEND_HOST: alter-dev
```

#### Override per Ambiente

**docker-compose.dev.yml:**
```yaml
services:
  nginx:
    environment:
      SERVER_NAME: alter-dev localhost
```

**docker-compose.staging.yml:**
```yaml
services:
  nginx:
    environment:
      SERVER_NAME: staging.alter-web.it localhost
```

**docker-compose.prod.yml:**
```yaml
services:
  nginx:
    environment:
      SERVER_NAME: docker.alter-web.it www.docker.alter-web.it
```

### Processo

```
Container avvio
    ↓
Legge /etc/nginx/templates/*.template
    ↓
Sostituisce ${SERVER_NAME} → "docker.alter-web.it"
             ${BACKEND_HOST} → "alter-dev"
    ↓
Scrive /etc/nginx/conf.d/alter-dev.conf
    ↓
Avvia nginx
```

### Test

```bash
# Development
./compose.sh dev up -d
docker exec dev-nginx-1 cat /etc/nginx/conf.d/alter-dev.conf
# server_name alter-dev localhost;

# Production
./compose.sh prod up -d
docker exec prod-nginx-1 cat /etc/nginx/conf.d/alter-dev.conf
# server_name docker.alter-web.it www.docker.alter-web.it;
```

## Migrazione Step-by-Step

### 1. Backup Config Attuale

```bash
cp nginx/conf.d/alter-dev.conf nginx/conf.d/alter-dev.conf.backup
```

### 2. Rinomina in Template

```bash
mv nginx/conf.d/alter-dev.conf nginx/conf.d/alter-dev.conf.template
```

### 3. Sostituisci Valori con Variabili

```bash
# In alter-dev.conf.template

# Prima:
server_name docker.alter-web.it;
proxy_pass http://alter-dev:8080;

# Dopo:
server_name ${SERVER_NAME};
proxy_pass http://${BACKEND_HOST}:8080;
```

### 4. Aggiorna docker-compose.yml

Volume mount cambia:

```yaml
# Prima:
- ./nginx/conf.d:/etc/nginx/conf.d:ro

# Dopo:
- ./nginx/conf.d:/etc/nginx/templates:ro
```

Aggiungi environment:

```yaml
environment:
  SERVER_NAME: localhost
  BACKEND_HOST: alter-dev
```

### 5. Test Ogni Ambiente

```bash
# Dev
./compose.sh dev up -d
curl -v http://localhost
docker logs dev-nginx-1

# Staging
./compose.sh staging down
./compose.sh staging up -d
curl -v http://localhost:8082

# Prod
./compose.sh prod down
./compose.sh prod up -d
curl -v https://docker.alter-web.it
```

## Variabili per Ambiente

| Variabile | Dev | Staging | Prod |
|-----------|-----|---------|------|
| `SERVER_NAME` | `alter-dev localhost` | `staging.alter-web.it localhost` | `docker.alter-web.it www.docker.alter-web.it` |
| `BACKEND_HOST` | `alter-dev` | `alter-dev` | `alter-dev` |

## Esempio Template Completo

```nginx
# /nginx/conf.d/alter-dev.conf.template

# HTTP → HTTPS redirect
server {
    listen 80;
    server_name ${SERVER_NAME};
    
    # Health check endpoint (no redirect)
    location /health {
        access_log off;
        return 200 "OK\n";
    }
    
    # Everything else → HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS
server {
    listen 443 ssl http2;
    server_name ${SERVER_NAME};

    # SSL
    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=31536000" always;

    # Logging
    access_log /var/log/nginx/alter-dev-access.log;
    error_log /var/log/nginx/alter-dev-error.log warn;

    # Client settings
    client_max_body_size 100M;
    client_body_timeout 300s;

    # Proxy to OpenACS
    location / {
        proxy_pass http://${BACKEND_HOST}:8080;
        
        # Headers
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $server_name;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffering
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
    }

    # Static files caching
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2|ttf|svg)$ {
        proxy_pass http://${BACKEND_HOST}:8080;
        proxy_cache_valid 200 1d;
        proxy_cache_bypass $http_pragma $http_authorization;
        add_header Cache-Control "public, immutable";
        expires 7d;
    }

    # Health check
    location /nginx-health {
        access_log off;
        return 200 "nginx OK\n";
        add_header Content-Type text/plain;
    }
}
```

## Vantaggi

✅ **Un solo template** - nessuna duplicazione
✅ **DRY** - modifiche comuni in un posto
✅ **Nativo nginx** - supporto ufficiale
✅ **Chiaro** - variabili esplicite e documentate
✅ **Testabile** - vedi output processato
✅ **Versionabile** - template in Git

## Troubleshooting

### Template non sostituito

```bash
# Verifica mount
docker inspect dev-nginx-1 | grep -A 5 Mounts

# Deve essere:
# /etc/nginx/templates (non /etc/nginx/conf.d)
```

### Variabile non definita

```bash
# Verifica environment
docker exec dev-nginx-1 env | grep SERVER_NAME

# Se manca, aggiungi in docker-compose override
```

### Config syntax error

```bash
# Test config processata
docker exec dev-nginx-1 nginx -t

# Vedi config generata
docker exec dev-nginx-1 cat /etc/nginx/conf.d/alter-dev.conf
```

### Reload config dopo modifica template

```bash
# Restart nginx service
./compose.sh dev restart nginx

# O reload
docker exec dev-nginx-1 nginx -s reload
```

## Alternative

Se template non funziona, alternativa con file multipli:

```
nginx/conf.d/
├── alter-dev.dev.conf
├── alter-dev.staging.conf
└── alter-dev.prod.conf
```

Override mount per ambiente:

```yaml
# docker-compose.dev.yml
services:
  nginx:
    volumes:
      - ./nginx/conf.d/alter-dev.dev.conf:/etc/nginx/conf.d/alter-dev.conf:ro
```

Ma **sconsigliato** - duplicazione codice!

## Conclusione

Template nginx con variabili d'ambiente è la soluzione **più pulita e manutenibile** per configurazioni multi-ambiente.

Setup finale:

```
nginx/
├── conf.d/
│   └── alter-dev.conf.template  # Un solo file con ${VAR}
├── nginx.conf                    # Comune
└── ssl/                          # Certificati

docker-compose.yml:        SERVER_NAME: localhost
docker-compose.dev.yml:    SERVER_NAME: alter-dev localhost
docker-compose.staging.yml: SERVER_NAME: staging.alter-web.it
docker-compose.prod.yml:   SERVER_NAME: docker.alter-web.it
```

Una cartella, tutti gli ambienti! ✅
