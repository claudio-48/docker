# Confronto Ambiente Sviluppo vs Produzione

## Riepilogo Modifiche Principali

### 1. Storage del Codice e Log

**SVILUPPO:**
```yaml
volumes:
  - /var/www/oacs-a:/var/www/openacs      # bind mount da host
  - /var/www/oacs-a/log:/var/www/openacs/log
```

**PRODUZIONE:**
```yaml
volumes:
  - oacs-a_data:/var/www/openacs          # named volume
  - oacs-a_log:/var/www/openacs/log       # named volume
```

**Vantaggi produzione:**
- Codice isolato dal filesystem host
- Più sicuro (no accesso diretto al filesystem)
- Facile backup con Docker volume export
- Portabilità tra host diversi

### 2. Restart Policy

**SVILUPPO:**
```yaml
restart: unless-stopped
```

**PRODUZIONE:**
```yaml
restart: always
```

**Motivo:** In produzione vogliamo che i container si riavviino sempre, anche dopo un reboot del server.

### 3. Resource Limits

**SVILUPPO:**
- Nessun limite

**PRODUZIONE:**
```yaml
deploy:
  resources:
    limits:
      cpus: '2.0'
      memory: 2G
    reservations:
      cpus: '0.5'
      memory: 512M
```

**Vantaggi:**
- Previene che un container consumi tutte le risorse
- Migliore stabilità del sistema
- Predictable performance

### 4. Healthcheck Intervals

**SVILUPPO:**
```yaml
healthcheck:
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 60s
```

**PRODUZIONE:**
```yaml
healthcheck:
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 90s
```

**Motivo:** Riduce il carico in produzione, con intervalli più lunghi ma comunque efficaci.

### 5. Port Exposure

**SVILUPPO:**
```yaml
ports:
  - "5432:5432"  # PostgreSQL accessibile da host
```

**PRODUZIONE:**
```yaml
ports:
  - "127.0.0.1:5432:5432"  # Solo localhost
```

**Sicurezza:** Database accessibile solo localmente, non dall'esterno.

### 6. Container Names

**SVILUPPO:**
- `openacs-a`
- `openacs-b`
- `oacs-postgres`

**PRODUZIONE:**
- `openacs-a-prod`
- `openacs-b-prod`
- `oacs-postgres-prod`

**Motivo:** Evita conflitti se esegui dev e prod sullo stesso host (sconsigliato ma possibile).

### 7. Network Names

**SVILUPPO:**
```yaml
networks:
  oacs-network:
    name: oacs-network
```

**PRODUZIONE:**
```yaml
networks:
  oacs-network:
    name: oacs-network-prod
```

### 8. PostgreSQL Configuration

**PRODUZIONE aggiunge:**
```yaml
shm_size: 256mb
environment:
  POSTGRES_INITDB_ARGS: "-E UTF8 --locale=it_IT.UTF-8"
volumes:
  - db_backups:/backups  # Volume dedicato per backup
```

### 9. Service Dependencies

**PRODUZIONE aggiunge:**
```yaml
nginx:
  depends_on:
    openacs-a:
      condition: service_healthy
    openacs-b:
      condition: service_healthy
```

**Motivo:** Nginx parte solo quando OpenACS è pronto.

### 10. Environment Variables

**PRODUZIONE richiede:**
```bash
# .env file con valori specifici
oacs_a_hostname=app1.example.com  # domini reali
oacs_b_hostname=app2.example.com

# Secrets forti (non "CHANGE_ME")
clusterSecret=<random-32-bytes>
parameterSecret=<random-32-bytes>
```

## File Aggiuntivi per Produzione

### Script di Management (`oacs-prod.sh`)
Fornisce comandi semplificati:
- `deploy` - Deploy iniziale
- `start/stop/restart` - Gestione servizi
- `backup-db` - Backup automatico database
- `backup-volumes` - Backup codice OpenACS
- `restore-db` - Restore da backup
- `logs` - Visualizzazione logs
- `shell` - Accesso container
- `update` - Update immagini

### Backup Strategy

**SVILUPPO:**
- Backup manuale quando necessario
- Codice già su host (`/var/www/oacs-*`)

**PRODUZIONE:**
- Backup automatico giornaliero (cron)
- Backup database: `./manage.sh backup-db`
- Backup volumi: `./manage.sh backup-volumes`
- Retention policy: ultimi 7 backup

## Procedura di Migrazione

### Step-by-step

1. **Preparazione**
   ```bash
   # Backup ambiente sviluppo
   cd /path/to/dev
   ./dev-backup.sh
   ```

2. **Setup produzione**
   ```bash
   mkdir oacs-production
   cd oacs-production
   cp docker-compose.prod.yml docker-compose.yml
   cp .env.prod.template .env
   # Configura .env con valori reali
   ```

3. **Deploy iniziale**
   ```bash
   ./manage.sh deploy
   ```

4. **Migrazione dati** (scegli un metodo)

   **Metodo A: Copia volumi**
   ```bash
   # Copia codice da dev a prod
   docker cp /var/www/oacs-a openacs-a-prod:/var/www/openacs
   ```

   **Metodo B: Restore da backup**
   ```bash
   ./manage.sh restore-db /path/to/backup.sql
   ```

5. **Verifica**
   ```bash
   ./manage.sh status
   ./manage.sh logs
   ```

## Checklist Pre-Deploy Produzione

- [ ] File `.env` configurato con valori reali
- [ ] Secrets generati con `openssl rand -base64 32`
- [ ] File `secrets/psql_password` creato
- [ ] Domini DNS configurati per `oacs_a_hostname` e `oacs_b_hostname`
- [ ] Certificati SSL pronti (se HTTPS)
- [ ] Nginx configurato per i domini corretti
- [ ] SMTP credentials verificate
- [ ] Backup ambiente sviluppo completato
- [ ] Firewall configurato (80, 443 aperti)
- [ ] Monitoring setup (opzionale ma consigliato)
- [ ] Cron job per backup configurato
- [ ] Piano di rollback definito

## Testing Post-Deploy

```bash
# 1. Verifica container healthy
docker ps

# 2. Test OpenACS diretto
docker compose exec openacs-a curl http://localhost:8080/SYSTEM/success.tcl

# 3. Test tramite Nginx
curl http://app1.example.com

# 4. Test HTTPS (se configurato)
curl https://app1.example.com

# 5. Test database
docker compose exec db psql -U postgres -c "\l"

# 6. Test mail relay
docker compose exec mailrelay postfix status
```

## Manutenzione Consigliata

| Attività | Frequenza | Comando |
|----------|-----------|---------|
| Backup database | Giornaliero | `./manage.sh backup-db` (cron) |
| Backup volumi | Settimanale | `./manage.sh backup-volumes` (cron) |
| Update immagini | Mensile | `./manage.sh update` |
| Cleanup Docker | Mensile | `./manage.sh cleanup` |
| Verifica logs | Giornaliero | `./manage.sh logs` |
| Verifica spazio disco | Settimanale | `docker system df -v` |
| Test restore | Trimestrale | Test su ambiente staging |

## Monitoraggio Consigliato

### Metriche da monitorare:
- CPU usage containers
- Memory usage containers
- Disk usage volumi
- Database connections
- Response time applicazioni
- HTTP status codes (Nginx)
- Mail queue size

### Tools consigliati:
- **Prometheus + Grafana** per metriche
- **Loki** per aggregazione logs
- **Alertmanager** per alert
- **Uptime Kuma** per availability monitoring

## Domande Frequenti

**Q: Posso eseguire dev e prod sullo stesso host?**
A: Tecnicamente sì (hanno network e nomi diversi), ma è sconsigliato. Usa host separati o almeno VM separate.

**Q: Come accedo ai file dentro i volumi Docker?**
A: Usa `docker volume inspect` per trovare il mountpoint, oppure:
```bash
docker run --rm -v oacs-prod_oacs-a_data:/data alpine ls -la /data
```

**Q: Posso tornare indietro da prod a dev?**
A: Sì, copia i volumi o fai dump del database e restore in dev.

**Q: Come eseguo comandi Tcl/OpenACS?**
A: 
```bash
./manage.sh shell openacs-a
# Poi dentro il container
/usr/local/ns/bin/nsd -t /var/www/openacs/etc/config.tcl
```

**Q: Il backup automatico funziona anche se il server è spento?**
A: No, usa `anacron` invece di `cron` se il server non è sempre acceso.

---

**Prossimi passi:**
1. Review questo documento
2. Testa il deploy in un ambiente di staging
3. Pianifica la migrazione in produzione
4. Configura monitoring e alerting
5. Documenta procedure specifiche del tuo setup
