# FAQ - Docker per OpenACS

## Domande Frequenti Tecniche

---

## Generale

### Q: Docker è gratuito?
**A:** Sì, Docker Engine (la parte che usiamo) è completamente open source e gratuito. Docker Desktop ha limitazioni per aziende grandi, ma noi usiamo Docker Engine su Linux che è sempre gratuito.

### Q: È stabile? È pronto per produzione?
**A:** Assolutamente sì. Docker è in produzione dal 2013. È usato da:
- Netflix (streaming)
- Spotify (music)
- PayPal (pagamenti)
- eBay (e-commerce)
- Il 75% delle aziende Fortune 100

### Q: Che risorse server servono?
**A:** Docker usa MENO risorse delle VM. Server attuali vanno benissimo. In generale:
- CPU: nessun overhead significativo
- RAM: ~100MB per container (vs GB per VM)
- Disco: MB per immagini (vs GB per VM)

---

## Sviluppo

### Q: Devo imparare un nuovo linguaggio di programmazione?
**A:** No. Scrivi codice OpenACS/Tcl esattamente come prima. Docker è solo il "contenitore", il codice è lo stesso.

### Q: Posso usare il mio IDE preferito?
**A:** Sì. Il codice è accessibile normalmente. VSCode, Emacs, vim - tutto funziona come prima.

### Q: E il debugging?
**A:** Identico. Puoi:
- Attach al processo nel container
- Usare log files come sempre
- Eseguire shell interattiva nel container
- Usare remote debugging

### Q: Quanto tempo per imparare?
**A:** Per uso base: 1-2 giorni
- Comandi essenziali: 10 (`docker ps`, `docker logs`, etc.)
- Docker Compose: 2 ore
- Per essere produttivi: 1 settimana di pratica

### Q: CVS funziona ancora?
**A:** Sì. Docker non cambia il version control. Puoi continuare con CVS e migrare a Git quando vuoi.

---

## Deploy

### Q: Quanto tempo per un deploy?
**A:** 
- Setup iniziale: ~5 minuti (prima volta)
- Deploy successivi: 30-60 secondi
- Rollback: 10-20 secondi

### Q: E se qualcosa va storto durante un deploy?
**A:** Backup automatico prima di ogni deploy. Rollback con un comando. Nessun rischio.

### Q: Posso fare deploy senza downtime?
**A:** Sì, con Blue/Green deployment:
1. Avvia nuovo container con nuova versione
2. Testa che funzioni
3. Switcha traffico al nuovo
4. Spegni il vecchio
Zero downtime.

### Q: Come gestisco i log?
**A:** Tre opzioni:
1. Docker logs (`docker logs container-name`)
2. Volumi persistenti (i log sono in `/var/log` nei volumi)
3. Log aggregation (Loki, ELK, etc.) - opzionale

### Q: E i backup?
**A:** 
- Automatici: script fa backup prima di ogni deploy
- Scheduled: cron job per backup notturni
- On-demand: comando manuale quando vuoi
Include: database + codice + configurazioni

---

## Database

### Q: PostgreSQL in container è sicuro?
**A:** Sì, equivalente a installazione tradizionale:
- Stessi controlli di accesso
- Stesso encryption
- Stessi backup
- Performance identiche

### Q: Posso accedere al database dall'esterno?
**A:** Sì, ma configurabile:
- Produzione: solo localhost (più sicuro)
- Sviluppo: esposto su 5432 se serve
- SSH tunneling sempre possibile

### Q: E se perdo i dati?
**A:** I dati sono in volumi persistenti Docker. Anche se elimini il container, i dati rimangono. Inoltre:
- Backup automatici giornalieri
- Backup pre-deploy
- Snapshot volumi possibili

### Q: Posso fare restore da backup tradizionale?
**A:** Sì. PostgreSQL dump standard funziona identicamente.

---

## Networking

### Q: Come comunicano i container tra loro?
**A:** Docker crea network interno. I container si vedono per nome:
- `openacs-a` può collegarsi a `db` usando nome host
- Network isolato: sicuro
- Port mapping per accesso esterno

### Q: HTTPS/SSL funziona?
**A:** Sì. Nginx gestisce SSL:
- Certificati Let's Encrypt supportati
- Terminazione SSL su Nginx
- Backend HTTP (più semplice)

### Q: E il firewall?
**A:** Docker gestisce iptables automaticamente. Tu devi solo:
- Aprire 80, 443 per web
- Tutto il resto è interno e sicuro

---

## Migrazione

### Q: Devo migrare tutto subito?
**A:** No. Approccio graduale:
1. Pilot su 1-2 clienti
2. Staging completo
3. Produzione cliente per cliente
4. Sempre possibile rollback

### Q: Quanto downtime serve?
**A:** Dipende dall'approccio:
- Conservativo: 30 minuti di maintenance window
- Blue/Green: zero downtime
- Ibrido: 5-10 minuti

### Q: E se vogliamo tornare indietro?
**A:** Sempre possibile. Abbiamo:
- Backup pre-migrazione
- Documentazione setup tradizionale
- Server può eseguire sia Docker che setup tradizionale

---

## Performance

### Q: Docker rallenta l'applicazione?
**A:** Overhead minimo (<5%):
- CPU: quasi nativo
- Network: impatto trascurabile
- I/O: dipende da storage driver, ma ottimizzabile
- RAM: più efficiente delle VM

### Q: E il database?
**A:** PostgreSQL in container ha performance identiche a bare metal per la maggior parte dei workload. Per carichi estremi, tuning possibile.

### Q: Posso scalare?
**A:** Sì, facilmente:
- Verticale: più CPU/RAM al container
- Orizzontale: più container (load balancing)
- Docker Swarm o Kubernetes per auto-scaling

---

## Sicurezza

### Q: I container sono sicuri?
**A:** Sì, con best practices:
- Isolamento a livello kernel
- User namespace (processi non-root)
- Rete isolata
- Secrets management integrato
- Scan vulnerabilità immagini

### Q: E se qualcuno compromette un container?
**A:** Impatto limitato:
- Container isolato dagli altri
- Filesystem read-only possibile
- Network policies per limitare comunicazione
- Restart automatico in caso di crash

### Q: Come gestiamo i secrets (password, etc)?
**A:** Docker Secrets o variabili ambiente:
- File `.env` per configurazione
- Secrets management di Docker
- Volume read-only per secrets
- Mai hardcoded nel codice

---

## Monitoring

### Q: Come monitoro i container?
**A:** Strumenti disponibili:
- `docker stats` - uso risorse real-time
- `docker ps` - stato container
- `docker logs` - log applicazione
- Health checks integrati
- Prometheus + Grafana (opzionale)

### Q: Come so se un container è crashato?
**A:** 
- Health check automatico
- Restart automatico se crash
- Alert configurabili
- Log centralizzati

### Q: E le metriche?
**A:** Docker espone metriche:
- CPU, RAM, Network, Disk per container
- Esportabili a Prometheus
- Dashboard Grafana disponibili

---

## Troubleshooting

### Q: Container non parte, cosa faccio?
**A:** 
```bash
# 1. Controlla logs
docker logs container-name

# 2. Controlla stato
docker ps -a

# 3. Ispeziona configurazione
docker inspect container-name

# 4. Verifica network
docker network ls
```

### Q: Come entro in un container?
**A:** 
```bash
# Shell interattiva
docker exec -it container-name /bin/sh

# Comando singolo
docker exec container-name comando
```

### Q: Container usa troppa memoria?
**A:** 
```bash
# Verifica uso
docker stats

# Limita memoria
docker run -m 512m image-name

# In compose:
resources:
  limits:
    memory: 512M
```

---

## Costi

### Q: Quanto costa implementare Docker?
**A:** Principalmente tempo:
- Software: €0 (open source)
- Hardware: €0 (server esistente va bene)
- Tempo setup: ~2-3 settimane team
- Training: ~1 settimana per sviluppatore
- ROI: positivo dopo 2-3 mesi

### Q: Serve personale specializzato?
**A:** No. Team attuale può gestirlo:
- Skill base: 1-2 settimane training
- Skill avanzato: 1-2 mesi esperienza
- Community enorme per supporto
- Documentazione ottima

### Q: Costi operativi aumentano?
**A:** No, si riducono:
- Meno tempo deploy (da ore a minuti)
- Meno problemi produzione
- Onboarding più rapido
- Meno risorse server

---

## Compliance e Normative

### Q: Docker è conforme GDPR?
**A:** Docker è uno strumento, compliance dipende da come lo usi:
- Encryption: configurabile
- Backup: automatizzabili
- Audit log: disponibili
- Data isolation: migliorata
Rispetto a setup tradizionale: nessun peggioramento, spesso miglioramento.

### Q: E backup secondo normativa?
**A:** Backup gestibili come sempre:
- Schedule automatico
- Retention configurabile
- Export per archiviazione
- Restore testabile

---

## Ecosistema

### Q: Docker è l'unico tool necessario?
**A:** Docker + Docker Compose bastano per iniziare. Opzionali:
- Kubernetes: se serve orchestrazione avanzata
- Registry privato: se serve repository interno immagini
- Monitoring: Prometheus, Grafana
- CI/CD: Jenkins, GitLab CI

### Q: E se Docker sparisce?
**A:** 
- Open source: codice disponibile sempre
- Standard OCI: immagini compatibili con altri runtime
- Community enorme: non sparirà presto
- Alternative disponibili: Podman, containerd

---

## Confronto Alternative

### Q: Perché Docker e non Kubernetes?
**A:** Kubernetes è orchestrazione di container. È più complesso:
- Docker: setup in 1 giorno
- Kubernetes: setup in 1-2 settimane
- Per 2-10 server: Docker basta
- Per 50+ server: considera Kubernetes

### Q: Perché Docker e non Podman?
**A:** Podman è valido ma:
- Docker: più maturo, più documentazione
- Podman: più recente, meno tooling
- Migrazione Podman→Docker facile se serve
- Per ora, Docker è scelta più sicura

### Q: Perché Docker e non LXC/LXD?
**A:** LXC è più low-level:
- Docker: application containers
- LXC: system containers
- Docker: più facile per app
- LXC: meglio per sostituire VM

---

## Casi d'Uso Reali

### Q: Qualcuno usa Docker con OpenACS?
**A:** Sì:
- OpenACS ha immagini Docker ufficiali
- Community attiva
- Esempi disponibili
- La nostra soluzione è basata su best practices consolidate

### Q: E con PostgreSQL?
**A:** PostgreSQL in Docker è scenario comune:
- Immagine ufficiale PostgreSQL molto usata
- Production-ready
- Performance testate
- Community enorme

---

## Prossimi Passi

### Q: Da dove iniziare?
**A:** 
1. **Setup sviluppo:** 
   - Installa Docker Desktop (Mac/Windows) o Docker Engine (Linux)
   - Clone repository con docker-compose.yml
   - `docker compose up`
   - Hai ambiente funzionante

2. **Impara base:**
   - Tutorial Docker ufficiale (2 ore)
   - Pratica con il nostro stack (1 settimana)
   - Deploy su staging (2 settimane)

3. **Pilot produzione:**
   - Cliente non critico
   - Monitor attento
   - Feedback e iterazioni

### Q: Dove trovo aiuto?
**A:** 
- **Interno:** Team IT (dopo training)
- **Documentazione:** docs.docker.com (ottima)
- **Community:** Stack Overflow, Reddit r/docker
- **Video:** YouTube Docker channel
- **Corsi:** Udemy, Coursera (se serve approfondimento)

### Q: Serve certificazione Docker?
**A:** No, per uso base. Certificazioni disponibili se serve:
- Docker Certified Associate (DCA)
- Utile ma non necessario
- Pratica > certificazione

---

## Risorse Consigliate

### Documentazione
- [Docker Docs](https://docs.docker.com) - Documentazione ufficiale
- [Docker Compose Docs](https://docs.docker.com/compose/) - Compose reference
- [Best Practices](https://docs.docker.com/develop/dev-best-practices/) - Best practices ufficiali

### Tutorial
- [Docker Getting Started](https://docs.docker.com/get-started/) - Tutorial interattivo
- [Play with Docker](https://labs.play-with-docker.com/) - Sandbox online gratuito

### Video
- [Docker YouTube Channel](https://www.youtube.com/user/dockerrun) - Canale ufficiale
- [TechWorld with Nana](https://www.youtube.com/c/TechWorldwithNana) - Tutorial eccellenti

### Community
- [Docker Forums](https://forums.docker.com) - Forum ufficiale
- [Stack Overflow](https://stackoverflow.com/questions/tagged/docker) - Q&A tecnico
- [Reddit r/docker](https://reddit.com/r/docker) - Community attiva

---

## Contatti

Per domande specifiche al nostro progetto:
- **Email:** it-team@company.com
- **Slack:** #docker-migration
- **Wiki:** internal-wiki.company.com/docker

Per domande su questa presentazione:
- Contatta il presentatore
- Repository documentazione: /path/to/repo
