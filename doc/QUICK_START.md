# Quick Start - OpenACS Production

## File Forniti

1. **docker-compose.prod.yml** - Configurazione Docker Compose per produzione
2. **.env.prod.template** - Template file environment (da copiare come .env)
3. **oacs-prod.sh** - Script di gestione (eseguibile)
4. **.gitignore** - File da ignorare in Git
5. **PRODUCTION_GUIDE.md** - Guida completa al deployment
6. **DEV_VS_PROD.md** - Confronto dettagliato dev/prod

## Setup Rapido (5 minuti)

```bash
# 1. Crea directory produzione
mkdir oacs-production && cd oacs-production

# 2. Copia i file forniti
cp /path/to/docker-compose.prod.yml ./docker-compose.yml
cp /path/to/oacs-prod.sh ./manage.sh
cp /path/to/.env.prod.template ./.env

# 3. Copia configurazioni esistenti
cp -r /path/to/nginx ./
cp -r /path/to/secrets ./
cp /path/to/config.tcl ./
cp /path/to/init-user-db.sh ./

# 4. Rendi eseguibile lo script
chmod +x manage.sh

# 5. Configura .env
nano .env
# IMPORTANTE: Cambia almeno questi valori:
#   - oacs_a_hostname
#   - oacs_b_hostname
#   - clusterSecret (usa: openssl rand -base64 32)
#   - parameterSecret (usa: openssl rand -base64 32)
#   - SMTP_* (credenziali email)

# 6. Verifica secrets
cat secrets/psql_password  # Deve contenere la password PostgreSQL

# 7. Deploy!
./manage.sh deploy

# 8. Verifica
./manage.sh status
./manage.sh logs
```

## Differenze Chiave vs Sviluppo

| Cosa | Sviluppo | Produzione |
|------|----------|------------|
| **Codice** | `/var/www/oacs-*` (host) | Docker volume |
| **Log** | `/var/www/oacs-*/log` (host) | Docker volume |
| **Restart** | `unless-stopped` | `always` |
| **Resources** | Unlimited | CPU/RAM limits |
| **DB Port** | `:5432` | `127.0.0.1:5432` |
| **Backup** | Manuale | Automatico (cron) |

## Comandi Essenziali

```bash
./manage.sh status          # Stato servizi
./manage.sh logs            # Logs real-time
./manage.sh restart         # Riavvia tutto
./manage.sh backup-db       # Backup database
./manage.sh shell openacs-a # Accedi al container
./manage.sh help           # Lista comandi
```

## Backup Automatico (Setup Cron)

```bash
# Edita crontab
crontab -e

# Aggiungi (backup giornaliero ore 2:00)
0 2 * * * cd /path/to/oacs-production && ./manage.sh backup-db >> /var/log/oacs-backup.log 2>&1
```

## Troubleshooting Rapido

**Container non parte?**
```bash
./manage.sh logs <service-name>
docker compose config  # Verifica YAML
```

**Database non raggiungibile?**
```bash
docker compose exec db pg_isready -U postgres
```

**OpenACS non risponde?**
```bash
docker compose exec openacs-a curl http://localhost:8080/SYSTEM/success.tcl
```

## Sicurezza - Checklist

- [ ] Password PostgreSQL forte
- [ ] Secrets univoci (clusterSecret, parameterSecret)
- [ ] .env NON committato in Git
- [ ] Porte DB solo su localhost
- [ ] SSL configurato per Nginx
- [ ] Firewall attivo (solo 80, 443)

## Prossimi Passi

1. ✅ Setup base (hai appena fatto)
2. ⏳ Test applicazione
3. ⏳ Configura domini DNS
4. ⏳ Setup certificati SSL
5. ⏳ Configura backup automatici
6. ⏳ Setup monitoring (opzionale)

## Link Utili

- Guida completa: `PRODUCTION_GUIDE.md`
- Confronto dev/prod: `DEV_VS_PROD.md`
- Help comandi: `./manage.sh help`

---

**Supporto:** Se hai problemi, controlla sempre prima i logs con `./manage.sh logs`
