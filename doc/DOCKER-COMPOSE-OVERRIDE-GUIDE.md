# Docker Compose Override - Guida alla Configurazione

## Struttura File

```
.
├── docker-compose.yml           # BASE (configurazione comune)
├── docker-compose.dev.yml       # OVERRIDE sviluppo
├── docker-compose.staging.yml   # OVERRIDE staging
├── docker-compose.prod.yml      # OVERRIDE produzione
└── compose.sh                   # Helper script
```

## Differenze tra Ambienti

### Database (PostgreSQL)

| Aspetto | Dev | Staging | Prod |
|---------|-----|---------|------|
| **restart** | unless-stopped | unless-stopped | always |
| **Porta esposta** | 5432 (0.0.0.0) | 5432 (127.0.0.1) | No |
| **Script import** | No | No | Sì |
| **Scopo porta** | pgAdmin, DBeaver | Test localhost | Solo interno |

### OpenACS (alter-dev)

| Aspetto | Dev | Staging | Prod |
|---------|-----|---------|------|
| **restart** | unless-stopped | unless-stopped | always |
| **Volume codice** | Bind mount `/var/www/alter-dev` | Named volume | Named volume |
| **Porta 8080** | Opzionale (localhost) | 127.0.0.1:8080 | No |
| **hostname** | alter-dev | alter-dev-staging | docker.alter-web.it |
| **oacs_hostname** | alter-dev | staging.alter-web.it | docker.alter-web.it |
| **Content repos** | No bind mounts | Bind mounts | Bind mounts |
| **Editing live** | ✅ Sì | ❌ No | ❌ No |

### Nginx

| Aspetto | Dev | Staging | Prod |
|---------|-----|---------|------|
| **restart** | unless-stopped | unless-stopped | always |
| **Configurazione** | Identica in tutti gli ambienti |

### Mail Relay

| Aspetto | Dev | Staging | Prod |
|---------|-----|---------|------|
| **restart** | unless-stopped | unless-stopped | always |
| **Configurazione** | Identica in tutti gli ambienti |

## Uso

### Metodo 1: Script Helper (Raccomandato) ⭐

```bash
# Development
./compose.sh dev up -d
./compose.sh dev logs -f alter-dev
./compose.sh dev restart alter-dev
./compose.sh dev down

# Staging
./compose.sh staging up -d
./compose.sh staging ps
./compose.sh staging logs -f

# Production
./compose.sh prod up -d
./compose.sh prod restart alter-dev
./compose.sh prod exec alter-dev /bin/sh
```

### Metodo 2: Docker Compose Diretto

```bash
# Development
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d
docker compose -f docker-compose.yml -f docker-compose.dev.yml logs -f

# Staging
docker compose -f docker-compose.yml -f docker-compose.staging.yml up -d

# Production
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### Metodo 3: Variabile Ambiente (Opzionale)

```bash
# In .bashrc o .zshrc
export COMPOSE_FILE=docker-compose.yml:docker-compose.dev.yml

# Poi semplicemente:
docker compose up -d
docker compose logs -f
```

## Vantaggi Override

### ✅ Vantaggi

1. **DRY (Don't Repeat Yourself)**
   - Configurazione comune in un solo file
   - Override solo ciò che è diverso

2. **Manutenibilità**
   - Modifica comune = un solo file da aggiornare
   - Chiaro cosa è diverso tra ambienti

3. **Git-Friendly**
   - Un solo repository per tutti gli ambienti
   - Facile vedere differenze (git diff)

4. **Scalabilità**
   - Facile aggiungere nuovi ambienti (staging, qa, demo)
   - Facile aggiungere varianti (prod-eu, prod-us)

5. **Sicurezza**
   - Secrets/credenziali in file separati (.gitignore)
   - Configurazione ambiente-specifica chiara

### ⚠️ Attenzioni

1. **Merge dei volumi**
   ```yaml
   # Base
   volumes:
     - ./secrets:/run/secrets:ro
     - /var/run/docker.sock:/var/run/docker.sock
   
   # Override sovrascrive TUTTA la lista, non fa merge!
   # Quindi ripeti volumi comuni negli override
   ```

2. **Environment variables**
   ```yaml
   # Override fa MERGE delle env vars
   # Non serve ripetere tutte, solo quelle diverse
   ```

3. **Ordine file importante**
   ```bash
   # ✅ Corretto
   -f docker-compose.yml -f docker-compose.prod.yml
   
   # ❌ Sbagliato (override non applicato)
   -f docker-compose.prod.yml -f docker-compose.yml
   ```

## Esempio: Passaggio Dev → Prod

### Sviluppo (Dev)

```bash
# Lavori con bind mount per editing live
./compose.sh dev up -d

# Modifichi codice in /var/www/alter-dev
vim /var/www/alter-dev/packages/...

# Riavvii per vedere modifiche
./compose.sh dev restart alter-dev
```

### Test (Staging)

```bash
# Deploy su staging per test
./compose.sh staging up -d

# Codice in named volume (come prod)
# Ma porta esposta per test diretti
curl http://localhost:8080/SYSTEM/success.tcl
```

### Produzione (Prod)

```bash
# Deploy finale
./compose.sh prod up -d

# Solo via Nginx
curl https://docker.alter-web.it
```

## Migrazione da Setup Attuale

### Passo 1: Backup

```bash
# Backup configurazioni attuali
cp /path/to/dev/docker-compose.yml docker-compose-dev-OLD.yml
cp /path/to/prod/docker-compose.yml docker-compose-prod-OLD.yml
```

### Passo 2: Unifica Directory

```bash
# Crea directory unica
mkdir -p /opt/oacs-unified
cd /opt/oacs-unified

# Copia file comuni (secrets, nginx, scripts)
cp -r /path/to/dev/secrets ./
cp -r /path/to/dev/nginx ./
cp -r /path/to/dev/db-scripts ./
cp -r /path/to/dev/postfix ./

# Copia nuovi file compose
# (quelli creati sopra)
```

### Passo 3: Test Dev

```bash
cd /opt/oacs-unified
./compose.sh dev up -d

# Verifica tutto funzioni
docker ps
docker logs oacs-dev-alter-dev-1

# Se OK, continua
# Se problemi, aggiusta override
```

### Passo 4: Deploy Prod

```bash
# Ferma vecchia prod
cd /path/to/old/prod
docker compose down

# Avvia nuova prod
cd /opt/oacs-unified
./compose.sh prod up -d

# Verifica
docker ps
curl https://docker.alter-web.it
```

## Project Names

Lo script `compose.sh` usa nomi progetto identici al flag `-p`:

```bash
# Development
COMPOSE_PROJECT_NAME=dev
# Container: dev-alter-dev-1, dev-db-1, dev-nginx-1, etc.

# Staging
COMPOSE_PROJECT_NAME=staging
# Container: staging-alter-dev-1, staging-db-1, staging-nginx-1, etc.

# Production
COMPOSE_PROJECT_NAME=prod
# Container: prod-alter-dev-1, prod-db-1, prod-nginx-1, etc.
```

**Compatibilità con script esistenti:**
- `manage.sh` che usa `-p prod` → funziona! ✅
- `production-deploy-remote.sh` che cerca `prod-alter-dev-1` → funziona! ✅

## Conflitti di Porte

### ⚠️ Attenzione: Dev e Prod sullo Stesso Server

**Problema:** Entrambi usano porte 80, 443 → **CONFLITTO!**

```bash
# ❌ NON FUNZIONA
./compose.sh dev up -d    # Usa 80, 443
./compose.sh prod up -d   # Usa 80, 443 → ERRORE!
```

### ✅ Soluzioni

**Opzione A: Server Separati (Raccomandato)**

```
Server Dev:     ./compose.sh dev up -d   (80, 443, 5432)
Server Prod:    ./compose.sh prod up -d  (80, 443)
```

**Opzione B: Usa Staging con Porte Diverse**

```
Server Unico:
  ./compose.sh prod up -d     (80, 443)
  ./compose.sh staging up -d  (8082, 8443, 5433, 8081)
```

Staging usa porte diverse:
- Nginx HTTP: 8082 (invece di 80)
- Nginx HTTPS: 8443 (invece di 443)
- PostgreSQL: 5433 (invece di 5432)
- OpenACS: 8081 (invece di 8080)

**Accesso staging:**
```bash
http://localhost:8082
https://localhost:8443
psql -h localhost -p 5433 -U postgres
```

Vedi `PORT-ALLOCATION.md` per dettagli completi.

## File .env

Puoi avere `.env` files separati:

```bash
.env.dev       # Development vars
.env.staging   # Staging vars
.env.prod      # Production vars
```

Poi in `compose.sh`:

```bash
# Aggiungi dopo la scelta dell'environment
if [ -f ".env.${ENV}" ]; then
    export ENV_FILE="--env-file .env.${ENV}"
    info "Using .env.${ENV}"
fi

# Nel comando finale
docker compose ${COMPOSE_FILES} ${ENV_FILE} "$@"
```

## Conclusione

Setup consigliato:

```
/opt/oacs-unified/
├── docker-compose.yml          # Base (comune)
├── docker-compose.dev.yml      # Dev overrides
├── docker-compose.staging.yml  # Staging overrides
├── docker-compose.prod.yml     # Prod overrides
├── compose.sh                  # Helper
├── .env.dev                    # Dev vars
├── .env.staging                # Staging vars
├── .env.prod                   # Prod vars
├── secrets/                    # Credenziali
├── nginx/                      # Config Nginx
├── db-scripts/                 # Script DB
└── postfix/                    # Config mail
```

Comandi:

```bash
./compose.sh dev up -d          # Dev
./compose.sh staging up -d      # Staging  
./compose.sh prod up -d         # Prod
```

Semplice, pulito, manutenibile! ✅
