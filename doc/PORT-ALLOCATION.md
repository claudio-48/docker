# Allocazione Porte per Ambienti Multi-Environment

## Riepilogo Porte

### Development (dev)

| Servizio | Porta Host | Porta Container | Binding | Note |
|----------|------------|-----------------|---------|------|
| PostgreSQL | 5432 | 5432 | 0.0.0.0 | Accesso esterno (pgAdmin, DBeaver) |
| OpenACS | - | 8080 | - | Solo via Nginx (opzionale 127.0.0.1:8080) |
| Nginx HTTP | 80 | 80 | 0.0.0.0 | Pubblico |
| Nginx HTTPS | 443 | 443 | 0.0.0.0 | Pubblico |
| Mailrelay | - | 25 | - | Solo interno |

### Production (prod)

| Servizio | Porta Host | Porta Container | Binding | Note |
|----------|------------|-----------------|---------|------|
| PostgreSQL | - | 5432 | - | Solo interno (no expose) |
| OpenACS | - | 8080 | - | Solo via Nginx |
| Nginx HTTP | 80 | 80 | 0.0.0.0 | Pubblico |
| Nginx HTTPS | 443 | 443 | 0.0.0.0 | Pubblico |
| Mailrelay | - | 25 | - | Solo interno |

### Staging (staging)

| Servizio | Porta Host | Porta Container | Binding | Note |
|----------|------------|-----------------|---------|------|
| PostgreSQL | 5433 | 5432 | 127.0.0.1 | Diversa da dev (5432) |
| OpenACS | 8081 | 8080 | 127.0.0.1 | Diversa da dev, test diretti |
| Nginx HTTP | 8082 | 80 | 0.0.0.0 | Diversa da dev/prod |
| Nginx HTTPS | 8443 | 443 | 0.0.0.0 | Diversa da dev/prod |
| Mailrelay | - | 25 | - | Solo interno |

## Container Names

Con `COMPOSE_PROJECT_NAME`:

```bash
# Development (COMPOSE_PROJECT_NAME=dev)
dev-alter-dev-1
dev-db-1
dev-nginx-1
dev-mailrelay-1

# Production (COMPOSE_PROJECT_NAME=prod)
prod-alter-dev-1
prod-db-1
prod-nginx-1
prod-mailrelay-1

# Staging (COMPOSE_PROJECT_NAME=staging)
staging-alter-dev-1
staging-db-1
staging-nginx-1
staging-mailrelay-1
```

## Scenari di Deployment

### Scenario 1: Dev e Prod su Server Separati (Raccomandato) ⭐

```
Server Dev (10.0.1.10):
  - dev-alter-dev-1
  - dev-db-1:5432
  - dev-nginx-1:80,443

Server Prod (18.102.240.236):
  - prod-alter-dev-1
  - prod-db-1 (interno)
  - prod-nginx-1:80,443
```

**Nessun conflitto di porte!**

### Scenario 2: Dev e Prod sullo Stesso Server

**❌ CONFLITTO** - Entrambi usano porte 80, 443:

```
Server Unico:
  - dev-nginx-1:80,443    ← CONFLITTO
  - prod-nginx-1:80,443   ← CONFLITTO
```

**✅ SOLUZIONE A: Usa staging invece di dev**

```
Server Unico:
  - prod-nginx-1:80,443         (produzione)
  - staging-nginx-1:8082,8443   (test)
  - staging-db-1:5433           (test DB)
```

**✅ SOLUZIONE B: Override manuale per dev**

Crea `docker-compose.dev-same-server.yml`:

```yaml
# Override per dev sullo stesso server di prod
services:
  nginx:
    ports:
      - "8080:80"
      - "8443:443"
  
  db:
    ports:
      - "127.0.0.1:5433:5432"
```

Uso:
```bash
docker compose -f docker-compose.yml \
               -f docker-compose.dev.yml \
               -f docker-compose.dev-same-server.yml up -d
```

### Scenario 3: Dev, Staging, Prod su Stesso Server

**Con porte diverse:**

```
Server Unico:
  Development:
    - dev-nginx-1: porte 80, 443 (produzione principale)
    - dev-db-1: porta 5432
  
  Staging:
    - staging-nginx-1: porte 8082, 8443
    - staging-db-1: porta 5433
    - staging-alter-dev-1: porta 8081
  
  Production:
    ❌ Non possibile - conflitto con dev su 80/443
```

**Raccomandazione: Non fare questo!** Usa server separati per prod.

## Raccomandazioni

### Setup Consigliato

#### Opzione A: Server Separati (Best Practice) ⭐⭐⭐

```
Laptop Development:
  ./compose.sh dev up -d
  - Bind mounts per sviluppo
  - Porte 80, 443, 5432

Server Staging (opzionale):
  ./compose.sh staging up -d
  - Named volumes
  - Porte 80, 443 (o 8082, 8443 se condiviso)

Server Production:
  ./compose.sh prod up -d
  - Named volumes
  - Porte 80, 443
```

#### Opzione B: Server Condiviso Dev+Staging

```
Server Unico:
  Development (principale):
    ./compose.sh dev up -d
    - Porte 80, 443, 5432
  
  Staging (test):
    ./compose.sh staging up -d
    - Porte 8082, 8443, 5433, 8081
```

#### Opzione C: Solo Staging+Prod (senza dev locale)

```
Server Dev/Staging:
  ./compose.sh staging up -d
  - Porte 80, 443, 5432

Server Production:
  ./compose.sh prod up -d
  - Porte 80, 443, DB interno
```

## Verifica Porte in Uso

```bash
# Verifica quali porte sono occupate
sudo netstat -tulpn | grep :80
sudo netstat -tulpn | grep :443
sudo netstat -tulpn | grep :5432

# O con ss
ss -tulpn | grep :80

# O con lsof
sudo lsof -i :80
sudo lsof -i :443
```

## Firewall Rules

### Development (laptop/server interno)

```bash
# Firewall aperto per sviluppo locale
# Nessuna regola speciale necessaria
```

### Staging (se su server pubblico)

```bash
# ufw/iptables
sudo ufw allow 8082/tcp comment "Staging HTTP"
sudo ufw allow 8443/tcp comment "Staging HTTPS"

# Accesso DB solo da IP specifici
sudo ufw allow from 10.0.0.0/8 to any port 5433 comment "Staging DB"
```

### Production

```bash
# Solo 80 e 443 pubblici
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# DB non esposto (no regole necessarie)
```

## Accesso ai Servizi

### Development

```bash
# HTTP
http://localhost

# HTTPS
https://localhost

# Database
psql -h localhost -p 5432 -U postgres -d alter-dev

# OpenACS diretto (se esposto)
http://localhost:8080/SYSTEM/success.tcl
```

### Staging (stesso server)

```bash
# HTTP
http://localhost:8082

# HTTPS
https://localhost:8443

# Database
psql -h localhost -p 5433 -U postgres -d alter-dev

# OpenACS diretto
http://localhost:8081/SYSTEM/success.tcl
```

### Production

```bash
# HTTP/HTTPS (solo via Nginx)
https://docker.alter-web.it

# Database (solo da container)
docker exec prod-alter-dev-1 psql -h db -U postgres -d alter-dev

# OpenACS diretto (non esposto)
docker exec prod-alter-dev-1 curl localhost:8080/SYSTEM/success.tcl
```

## Compatibilità Script Esistenti

### manage.sh

Gli script esistenti usano il nome progetto con `-p`:

```bash
# manage.sh attuale (presume prod)
docker compose -p prod up -d
# Crea: prod-alter-dev-1, prod-db-1, etc.

# Con nuovo compose.sh
./compose.sh prod up -d
# COMPOSE_PROJECT_NAME=prod → stesso risultato! ✅
```

**Nessuna modifica necessaria** se già usi `-p dev` e `-p prod`.

### production-deploy-remote.sh

Script cerca container con pattern:

```bash
PROD_CONTAINER="prod-alter-dev-1"  # ← Deve matchare
```

Con `COMPOSE_PROJECT_NAME=prod` → `prod-alter-dev-1` ✅

**Funziona senza modifiche!**

## Migrazione da Setup Attuale

### Se attualmente usi:

```bash
# Server Dev
docker compose -p dev up -d

# Server Prod
docker compose -p prod up -d
```

### Migra a:

```bash
# Server Dev
./compose.sh dev up -d
# COMPOSE_PROJECT_NAME=dev (uguale a -p dev)

# Server Prod
./compose.sh prod up -d
# COMPOSE_PROJECT_NAME=prod (uguale a -p prod)
```

**Container names identici!** Migrazione trasparente. ✅

## Conclusione

**Setup raccomandato per evitare conflitti:**

1. **Dev su laptop/server dedicato**
   - Porte standard: 80, 443, 5432
   - `./compose.sh dev up -d`

2. **Prod su server dedicato AWS**
   - Porte standard: 80, 443
   - DB interno (no porta esposta)
   - `./compose.sh prod up -d`

3. **Staging opzionale**
   - Se su server separato: porte standard
   - Se su server condiviso con dev: porte 8082, 8443, 5433
   - `./compose.sh staging up -d`

**Nomi container compatibili con script esistenti!** ✅
