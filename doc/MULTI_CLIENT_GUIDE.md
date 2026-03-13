# Deploy Multi-Cliente - Guida Completa

## Panoramica

Sistema di deployment centralizzato per gestire deploy su **più server di produzione** (diversi clienti) usando un'unica configurazione.

## Architettura

```
┌─────────────────────────────────────────────────────────────┐
│  SERVER SVILUPPO                                            │
│                                                             │
│  ┌──────────────────────────────────────────────────┐      │
│  │  deployment-clients.conf                         │      │
│  │  • acme    → prod.acme.com                       │      │
│  │  • globex  → prod.globex.com                     │      │
│  │  • techcorp → prod.techcorp.io                   │      │
│  └──────────────────────────────────────────────────┘      │
│                         │                                   │
│  ┌──────────────────────▼──────────────────────────┐       │
│  │  deploy-client.sh                               │       │
│  │  • Carica config cliente                        │       │
│  │  • Esegue deploy remoto                         │       │
│  └─────────────────────────────────────────────────┘       │
│                         │                                   │
└─────────────────────────┼───────────────────────────────────┘
                          │
         ┌────────────────┼────────────────┐
         │                │                │
         ▼                ▼                ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ CLIENTE ACME │  │CLIENTE GLOBEX│  │CLIENTE TECH  │
│ prod.acme.   │  │ 192.168.100. │  │ prod.tech    │
│ com          │  │ 50           │  │ corp.io      │
└──────────────┘  └──────────────┘  └──────────────┘
```

## File del Sistema

### 1. deployment-clients.conf

File di configurazione centrale con tutti i clienti:

```conf
# CLIENT_ID|PROD_SERVER|PROD_USER|COMPOSE_DIR|CVSROOT|INSTANCES

acme|prod.acme.com|deploy|/opt/oacs-production|:pserver:user@cvs.com:/repo|oacs-a,oacs-b
globex|192.168.100.50|root|/root/oacs-production|:ext:user@cvs.globex.com:/repo|oacs-a
techcorp|prod.techcorp.io|oacs|/home/oacs/production||oacs-a,oacs-b,oacs-c
```

### 2. deploy-client.sh

Script principale per deploy singolo cliente:

```bash
./deploy-client.sh <client> <instance> <method>
```

### 3. deploy-batch.sh

Script per deploy su più clienti:

```bash
./deploy-batch.sh all <instance> <method>
```

## Setup Iniziale

### 1. Configurazione Clienti

```bash
# Crea/edita file configurazione
nano deployment-clients.conf

# Aggiungi un nuovo cliente
echo "newclient|prod.newclient.com|deploy|/opt/oacs-production|:pserver:user@cvs.com:/repo|oacs-a" >> deployment-clients.conf
```

**Campi configurazione:**

| Campo | Descrizione | Esempio |
|-------|-------------|---------|
| CLIENT_ID | ID univoco cliente | `acme` |
| PROD_SERVER | Hostname/IP server | `prod.acme.com` |
| PROD_USER | User SSH | `deploy` |
| COMPOSE_DIR | Path docker-compose | `/opt/oacs-production` |
| CVSROOT | Repository CVS | `:pserver:user@cvs.com:/repo` |
| INSTANCES | Istanze (sep. virgola) | `oacs-a,oacs-b` |

### 2. Setup SSH per Ogni Cliente

```bash
# Genera chiave SSH se non esiste
ssh-keygen -t ed25519 -C "deploy-multi-client"

# Copia su ogni server cliente
ssh-copy-id deploy@prod.acme.com
ssh-copy-id root@prod.globex.com
ssh-copy-id oacs@prod.techcorp.io

# Se il server del cliente è ospitato su AWS la sintassi è diversa
ssh-copy-id -i ~/.ssh/id_ed25519.pub \
            -o IdentityFile=/percorso-del-file.pem \
            deploy@prod.acme.com

# Test connessione
ssh deploy@prod.acme.com "echo 'OK'"
```

### 3. Verifica Setup

```bash
# Rendi eseguibili gli script
chmod +x deploy-client.sh deploy-batch.sh

# Lista clienti configurati
./deploy-client.sh list

# Test connessione cliente specifico
./deploy-client.sh test acme

# Mostra dettagli cliente
./deploy-client.sh show acme
```

## Uso Quotidiano

### Deploy Singolo Cliente

```bash
# Deploy su cliente ACME, istanza oacs-a, metodo CVS
./deploy-client.sh acme oacs-a cvs

# Deploy su cliente Globex, istanza oacs-a, metodo rsync
./deploy-client.sh globex oacs-a rsync

# Deploy con dry-run (simula senza eseguire)
./deploy-client.sh techcorp oacs-b git --dry-run

# Deploy forzato (senza conferme)
./deploy-client.sh acme oacs-a cvs --force
```

### Deploy Multi-Cliente

```bash
# Deploy su TUTTI i clienti
./deploy-batch.sh all oacs-a cvs

# Deploy su clienti specifici
./deploy-batch.sh clients "acme,globex" oacs-a cvs

# Deploy parallelo (più veloce)
./deploy-batch.sh all oacs-a git --parallel

# Deploy con continue-on-error
./deploy-batch.sh all oacs-a cvs --continue

# Dry run batch
./deploy-batch.sh all oacs-a cvs --dry-run
```

### Comandi Utility

```bash
# Lista tutti i clienti
./deploy-client.sh list

# Mostra config cliente
./deploy-client.sh show acme

# Test connessione
./deploy-client.sh test acme

# Lista istanze disponibili
./deploy-client.sh instances acme
```

## Workflow Tipico

### Scenario 1: Deploy Feature su Tutti i Clienti

```bash
# 1. Sviluppa in locale
cd /var/www/oacs-a
# ... modifiche codice ...

# 2. Commit in CVS
cvs commit -m "New feature: xyz"

# 3. Deploy su staging (se hai ambiente staging)
./deploy-client.sh acme-staging oacs-a cvs

# 4. Test in staging
curl https://staging.acme.com/test

# 5. Deploy su tutti i clienti produzione
./deploy-batch.sh all oacs-a cvs

# 6. Monitor
watch "./deploy-client.sh test acme && ./deploy-client.sh test globex"
```

### Scenario 2: Deploy Urgente su Cliente Specifico

```bash
# 1. Hotfix in sviluppo
cd /var/www/oacs-a
# ... fix bug critico ...
cvs commit -m "HOTFIX: critical bug"

# 2. Deploy immediato su cliente con problema
./deploy-client.sh acme oacs-a cvs --force

# 3. Verifica
ssh deploy@prod.acme.com "cd /opt/oacs-production && docker compose logs -f oacs-a"

# 4. Se OK, deploy sugli altri clienti
./deploy-batch.sh clients "globex,techcorp" oacs-a cvs
```

### Scenario 3: Migrazione Graduale CVS → Git

```bash
# Cliente già migrato a Git
./deploy-client.sh techcorp oacs-a git

# Clienti ancora su CVS
./deploy-client.sh acme oacs-a cvs
./deploy-client.sh globex oacs-a cvs

# Quando tutti migrati, cambia default
# Modifica deployment-clients.conf per rimuovere CVSROOT
```

## Gestione Clienti

### Aggiungere Nuovo Cliente

```bash
# 1. Setup server cliente (una tantum)
ssh newuser@new-server.com "mkdir -p /opt/oacs-production"

# 2. Copia files produzione
scp -r docker-compose.yml manage.sh .env nginx/ newuser@new-server.com:/opt/oacs-production/

# 3. Deploy iniziale
ssh newuser@new-server.com "cd /opt/oacs-production && ./manage.sh deploy"

# 4. Aggiungi a configurazione
echo "newclient|new-server.com|newuser|/opt/oacs-production|:pserver:user@cvs.com:/repo|oacs-a" >> deployment-clients.conf

# 5. Setup SSH
ssh-copy-id newuser@new-server.com

# 6. Test
./deploy-client.sh test newclient

# 7. Primo deploy
./deploy-client.sh newclient oacs-a cvs
```

### Rimuovere Cliente (Deprecato)

```bash
# 1. Backup configurazione
cp deployment-clients.conf deployment-clients.conf.bak

# 2. Rimuovi da config (commenta o elimina riga)
sed -i '/^oldclient|/d' deployment-clients.conf
# oppure
nano deployment-clients.conf  # e commenta con #

# 3. Archivia backup del cliente
ssh user@old-server.com "cd /opt/oacs-production && ./manage.sh backup-db && ./manage.sh backup-volumes"
```

### Aggiornare Configurazione Cliente

```bash
# Cambio user o path
nano deployment-clients.conf

# Prima:
acme|prod.acme.com|root|/root/oacs-production|...|oacs-a

# Dopo:
acme|prod.acme.com|deploy|/opt/oacs-production|...|oacs-a

# Test nuova config
./deploy-client.sh test acme
```

## Script Avanzati

### Deploy con Log Centralizzato

```bash
#!/bin/bash
# deploy-with-log.sh

LOG_DIR="/var/log/deployments"
mkdir -p ${LOG_DIR}

CLIENT=$1
INSTANCE=$2
METHOD=$3
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="${LOG_DIR}/${CLIENT}-${INSTANCE}-${TIMESTAMP}.log"

echo "Deploy started at $(date)" | tee ${LOG_FILE}

./deploy-client.sh ${CLIENT} ${INSTANCE} ${METHOD} 2>&1 | tee -a ${LOG_FILE}

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "✓ Deploy SUCCESS" | tee -a ${LOG_FILE}
else
    echo "✗ Deploy FAILED" | tee -a ${LOG_FILE}
    exit 1
fi
```

### Deploy con Notifiche Slack

```bash
#!/bin/bash
# deploy-with-slack.sh

SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

CLIENT=$1
INSTANCE=$2
METHOD=$3

# Notifica inizio
curl -X POST ${SLACK_WEBHOOK} \
    -H 'Content-Type: application/json' \
    -d "{\"text\":\"🚀 Deploy started: ${CLIENT} - ${INSTANCE} (${METHOD})\"}"

# Deploy
if ./deploy-client.sh ${CLIENT} ${INSTANCE} ${METHOD}; then
    # Successo
    curl -X POST ${SLACK_WEBHOOK} \
        -H 'Content-Type: application/json' \
        -d "{\"text\":\"✅ Deploy SUCCESS: ${CLIENT} - ${INSTANCE}\"}"
else
    # Fallimento
    curl -X POST ${SLACK_WEBHOOK} \
        -H 'Content-Type: application/json' \
        -d "{\"text\":\"❌ Deploy FAILED: ${CLIENT} - ${INSTANCE}\"}"
    exit 1
fi
```

### Health Check Multi-Cliente

```bash
#!/bin/bash
# check-all-clients.sh

source deployment-clients.conf

echo "Health Check Multi-Cliente"
echo "=========================="
echo ""

./deploy-client.sh list | tail -n +4 | while read client server user instances; do
    [ -z "$client" ] && continue
    
    echo "Checking ${client}..."
    ./deploy-client.sh test ${client} 2>&1 | grep -E "✓|✗"
    echo ""
done
```

## Monitoring e Report

### Dashboard Stato Clienti

```bash
#!/bin/bash
# client-dashboard.sh

watch -n 30 '
echo "════════════════════════════════════════"
echo "  Client Production Dashboard"
echo "  $(date)"
echo "════════════════════════════════════════"
echo ""

./deploy-client.sh list | tail -n +4 | while read client server user instances; do
    [ -z "$client" ] && continue
    
    printf "%-15s " "$client"
    
    # Test connessione
    if timeout 3 ./deploy-client.sh test $client >/dev/null 2>&1; then
        echo "✓ ONLINE"
    else
        echo "✗ OFFLINE"
    fi
done
'
```

### Report Deploy

```bash
#!/bin/bash
# deployment-report.sh

LOG_DIR="/var/log/deployments"
PERIOD=${1:-7}  # giorni

echo "Deployment Report - Last ${PERIOD} days"
echo "========================================"
echo ""

find ${LOG_DIR} -name "*.log" -mtime -${PERIOD} | while read log; do
    CLIENT=$(basename ${log} | cut -d'-' -f1)
    INSTANCE=$(basename ${log} | cut -d'-' -f2)
    
    if grep -q "Deploy SUCCESS" ${log}; then
        STATUS="✓ SUCCESS"
    else
        STATUS="✗ FAILED"
    fi
    
    TIMESTAMP=$(stat -f %Sm ${log})
    
    printf "%-15s %-10s %-10s %s\n" "$CLIENT" "$INSTANCE" "$STATUS" "$TIMESTAMP"
done | sort
```

## Best Practices

### 1. Naming Convention Clienti

```bash
# Produzione
acme
globex
techcorp

# Staging
acme-staging
globex-staging

# Development (se su server separato)
acme-dev
```

### 2. Organizzazione Configurazione

```bash
# File separati per ambiente
deployment-clients-prod.conf
deployment-clients-staging.conf

# Usa variabile per switchare
export CLIENT_CONFIG="deployment-clients-prod.conf"
```

### 3. Backup Prima di Deploy Batch

```bash
# Backup automatico prima di batch deploy
./deploy-batch.sh all oacs-a cvs 2>&1 | tee /var/log/batch-deploy-$(date +%Y%m%d-%H%M%S).log
```

### 4. Deploy Windows

```bash
# Definisci finestre di deploy per cliente
# In deployment-clients.conf aggiungi campo DEPLOY_WINDOW

# Poi nello script verifica orario
CURRENT_HOUR=$(date +%H)
if [ $CURRENT_HOUR -ge 2 ] && [ $CURRENT_HOUR -le 4 ]; then
    # OK per deploy
else
    echo "Fuori finestra deploy (02:00-04:00)"
    exit 1
fi
```

## Troubleshooting

### Problema: Cliente non risponde

```bash
# 1. Verifica SSH
ssh -v deploy@prod.acme.com

# 2. Verifica Docker remoto
ssh deploy@prod.acme.com "docker ps"

# 3. Controlla firewall
ssh deploy@prod.acme.com "sudo iptables -L"
```

### Problema: Deploy fallisce per timeout

```bash
# Aumenta timeout SSH
# In ~/.ssh/config

Host prod.acme.com
    ServerAliveInterval 60
    ServerAliveCountMax 10
    ConnectTimeout 30
```

### Problema: Configurazione cliente corrotta

```bash
# Valida configurazione
./deploy-client.sh show acme

# Se errore, ripristina da backup
cp deployment-clients.conf.bak deployment-clients.conf
```

## Sicurezza

### 1. User Dedicato per Deploy

```bash
# Su ogni server cliente
sudo useradd -m -s /bin/bash deploy
sudo usermod -aG docker deploy

# Limita permessi
sudo visudo
# Aggiungi: deploy ALL=(ALL) NOPASSWD: /usr/bin/docker
```

### 2. SSH Key Separate per Cliente

```bash
# Genera key per ogni cliente
ssh-keygen -t ed25519 -f ~/.ssh/deploy_acme
ssh-keygen -t ed25519 -f ~/.ssh/deploy_globex

# Config SSH
cat >> ~/.ssh/config << EOF
Host prod.acme.com
    IdentityFile ~/.ssh/deploy_acme

Host prod.globex.com
    IdentityFile ~/.ssh/deploy_globex
EOF
```

### 3. Audit Log

```bash
# Log tutti i deploy
echo "$(date) - User: $(whoami) - Client: $CLIENT - Instance: $INSTANCE" >> /var/log/deploy-audit.log
```

## Conclusione

Con questo sistema puoi:
- ✅ Gestire deploy su **decine di clienti** da un'unica postazione
- ✅ Deploy **batch** su tutti i clienti con un comando
- ✅ Configurazione **centralizzata** facile da mantenere
- ✅ **Tracciabilità** completa di tutti i deploy
- ✅ **Rollback** veloce in caso di problemi
- ✅ **Monitoring** dello stato di tutti i clienti
