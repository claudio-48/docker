# OpenACS Production Environment - Guida al Deployment

## Panoramica

Questo ambiente di produzione include:
- **3 istanze OpenACS** (oacs-a, oacs-b e alter-dev) con codice e log in Docker volumes
- **PostgreSQL 17.2** con database separati per ogni istanza
- **Nginx** come reverse proxy
- **Postfix** come mail relay
- Script di gestione automatizzato

## Differenze rispetto all'ambiente di sviluppo

| Aspetto | Sviluppo | Produzione |
|---------|----------|------------|
| Codice OpenACS | Bind mount da host (`/var/www/oacs-*`) | Named volume Docker |
| Log | Bind mount da host | Named volume Docker |
| Restart policy | `unless-stopped` | `always` |
| Healthcheck | Interval 10s | Interval 30-60s |
| Resource limits | Nessuno | CPU/Memory limits |
| Port exposure | Possibile su host | Solo localhost o network interno |
| Container names | `oacs-a`, `oacs-b`, `alter-dev` | `oacs-a`, `alter-dev` |

## Prerequisiti

1. **Docker e Docker Compose** installati
2. **Certificati SSL** (se usi HTTPS con Nginx)
3. **Credenziali SMTP** per il mail relay
4. **Backup** dell'ambiente di sviluppo (opzionale)

## Installazione

### 1. Preparazione file di configurazione

```bash
# Crea directory di progetto
git clone https://github.com/claudio-48/docker-prod.git
cd docker-prod

```

### 2. Configurazione secrets

```bash
# Crea directory secrets se non esiste
mkdir -p secrets

# Genera password PostgreSQL (esempio)
openssl rand -base64 32 > secrets/psql_password

# Verifica permessi
chmod 600 secrets/psql_password
```

### 3. Configurazione .env

Modifica il file `.env` con i tuoi valori:

### 4. Deploy iniziale

Il codice delle istanze, a differenza dell'ambiente di sviluppo, sarà mantenuto all'interno
dei container e a questo scopo occorre che il codice sia inizialmente disponibile nella
cartella /var/www da dove sarò copiato automaticamente una tantum nella cartella
/var/www/openacs del container alter-dev.

Occorre inoltre predisporre i dump dei database nella cartella db-dumps, in caso contrario
i database verranno creati vuoti. 

```bash
# Verifica configurazione
./manage.sh help

# Deploy
./manage.sh deploy
```

Il processo:
1. Verifica prerequisiti
2. Crea database PostgreSQL
3. Inizializza database per oacs-a, oacs-b e alter-dev
4. Avvia istanze OpenACS
5. Avvia Nginx e mail relay

### 5. Verifica

```bash
# Controlla stato
./manage.sh status

# Verifica logs
./manage.sh logs

# Logs specifici
./manage.sh logs alter-dev
./manage.sh logs db
```
## Gestione Quotidiana

### Comandi principali

```bash
# Start/Stop
./manage.sh start
./manage.sh stop
./manage.sh restart

# Status
./manage.sh status

# Logs in tempo reale
./manage.sh logs
./manage.sh logs alter-dev  # logs specifici

# Shell access
./manage.sh shell oacs-a
./manage.sh shell db
```

### Backup

```bash
# Backup database (automatico ogni notte via cron)
./manage.sh backup-db

# Backup volumi (codice OpenACS)
./manage.sh backup-volumes
```

**Configurazione backup automatico (cron):**

```bash
# Edita crontab
crontab -e

# Aggiungi (backup giornaliero alle 2:00 AM)
0 2 * * * cd /path/to/docker-prod && ./manage.sh backup-db >> /var/log/oacs-backup.log 2>&1

# Backup settimanale volumi (domenica alle 3:00 AM)
0 3 * * 0 cd /path/to/docker-prod && ./manage.sh backup-volumes >> /var/log/oacs-backup.log 2>&1
```

### Update

```bash
# Aggiorna immagini Docker
./manage.sh update

# Questo farà:
# 1. Pull delle nuove immagini
# 2. Chiederà conferma per restart
# 3. Riavvierà con le nuove versioni
```

## Monitoring

### Health checks

I container hanno health checks integrati:

```bash
# Verifica health
docker inspect --format='{{.State.Health.Status}}' oacs-a
docker inspect --format='{{.State.Health.Status}}' alter-dev
docker inspect --format='{{.State.Health.Status}}' db
```

### Logs

```bash
# Logs in tempo reale
./manage.sh logs

# Logs specifici ultimi 100 righe
docker compose -p prod logs --tail=100 openacs-a

# Logs da file (dentro i volumi)
docker compose -p prod exec alter-dev tail -f /var/www/openacs/log/error.log
```

## Troubleshooting

### Container non si avvia

```bash
# Verifica logs
./manage.sh logs <service-name>

# Verifica configurazione
docker compose -p prod config

# Riavvia singolo servizio
docker compose -p prod restart <service-name>
```

### Database non risponde

```bash
# Verifica connessione
docker compose -p prod exec db pg_isready -U postgres

# Accedi a psql
docker compose -p prod exec db psql -U postgres

# Check database
\l
\c oacs-a
\dt
```

### OpenACS non raggiungibile

```bash
# Verifica che il container sia healthy
docker ps

# Test diretto (bypassa Nginx)
docker compose -p prod exec alter-dev curl http://localhost:8080/SYSTEM/success.tcl

# Verifica Nginx
docker compose -p prod exec nginx nginx -t
```

### Problemi mail relay

```bash
# Verifica logs Postfix
./manage.sh logs mailrelay

# Test invio
docker compose -p prod exec mailrelay postfix status

# Verifica coda
docker compose -p prod exec mailrelay mailq
```

## Sicurezza

### Checklist sicurezza produzione

- [ ] Password PostgreSQL forte (32+ caratteri)
- [ ] clusterSecret e parameterSecret univoci e forti
- [ ] File secrets con permessi 600
- [ ] .env NON committato in Git (aggiungi a .gitignore)
- [ ] Porte database esposte solo su localhost
- [ ] Certificati SSL configurati per Nginx
- [ ] Docker socket accessibile solo se strettamente necessario
- [ ] Firewall configurato (solo 80, 443 dall'esterno)
- [ ] Backup automatici configurati
- [ ] Monitoring e alerting attivi

### Rotazione secrets

```bash
# 1. Genera nuovo secret
NEW_SECRET=$(openssl rand -base64 32)

# 2. Aggiorna .env
nano .env

# 3. Ricrea container (mantiene volumi)
docker compose -p prod up -d --force-recreate
```

## Manutenzione

### Pulizia

```bash
# Rimuovi risorse inutilizzate
./manage.sh cleanup

# Pulizia manuale più aggressiva
docker system prune -a --volumes
# ATTENZIONE: questo rimuove TUTTI i volumi non usati!
```

### Spazio disco

```bash
# Verifica spazio volumi
docker system df -v

# Dimensione singolo volume
docker volume inspect alter-dev_data | grep Mountpoint
du -sh /var/lib/docker/volumes/alter-dev_data/_data
```

## Scaling

Per aggiungere ulteriori istanze OpenACS:

1. Crea sezione `viae-dev` in docker-compose.yml
2. Rendi disponibile il codice in /var/www e il database in db-dumps
3. Aggiungi configurazione Nginx per routing
4. Deploy: `docker compose up -d viae-dev`

## Rollback

In caso di problemi dopo un update:

```bash
# 1. Stop nuova versione
./manage.sh stop

# 2. Restore backup database
./manage.sh restore-db ./backups/db_backup_YYYYMMDD_HHMMSS.sql.gz

# 3. Restore volumi (se necessario)
# [Procedura manuale di restore da backup tar.gz]

# 4. Riavvia
./manage.sh start
```

## Supporto

Per problemi o domande:
- Logs: `./manage.sh logs`
- Status: `./manage.sh status`
- Documentazione OpenACS: https://openacs.org/
- Docker Compose: https://docs.docker.com/compose/

---

**Nota finale:** Testa sempre i cambiamenti in un ambiente di staging prima di applicarli in produzione!
