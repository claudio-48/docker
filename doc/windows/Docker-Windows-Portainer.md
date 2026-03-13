# Docker su Windows e Portainer - Guida Completa

## Docker su Windows come Ambiente di Sviluppo

### TL;DR - Risposta Rapida

✅ **Sì, Docker su Windows funziona bene per sviluppo**
- Docker Desktop per Windows è maturo e stabile
- Performance accettabili con WSL2
- Alcuni accorgimenti necessari ma gestibili

⚠️ **Attenzioni necessarie**
- Usa WSL2 (non Hyper-V legacy)
- File system: attenzione a performance
- Path Windows vs Linux
- Line endings (CRLF vs LF)

---

## Docker Desktop per Windows

### Requisiti

**Hardware:**
- Windows 10/11 Pro, Enterprise, Education (64-bit)
- CPU con virtualizzazione (Intel VT-x / AMD-V)
- Minimo 4GB RAM (8GB+ consigliato)
- 20GB+ spazio disco

**Software:**
- Windows 10 versione 21H2+ o Windows 11
- WSL2 abilitato
- Kernel WSL aggiornato

### Architetture Disponibili

Docker Desktop per Windows supporta **due backend**:

#### 1. WSL2 Backend (Consigliato) ⭐

**Vantaggi:**
- Performance eccellenti (quasi native)
- File system veloce per volumi Linux
- Integrazione profonda con Linux
- Uso memoria più efficiente
- Supporto systemd

**Come funziona:**
```
Windows Host
  └─ WSL2 (Linux kernel reale)
      └─ Docker Engine (nativo Linux)
          └─ Container Linux
```

**Setup:**
```powershell
# 1. Abilita WSL2
wsl --install

# 2. Imposta WSL2 come default
wsl --set-default-version 2

# 3. Installa Docker Desktop
# Download da docker.com e installa

# 4. Nelle impostazioni Docker Desktop:
# Settings → General → "Use WSL2 based engine" ✓
```

#### 2. Hyper-V Backend (Legacy)

**Quando usarlo:**
- Windows 10 Home (non supporta WSL2 su versioni vecchie)
- Requisiti aziendali specifici

**Svantaggi:**
- Performance inferiori
- Più consumo risorse
- File system più lento

**Non consigliato per nuovo sviluppo.**

---

## Performance su Windows

### Benchmark Tipici (WSL2)

| Operazione | Windows (WSL2) | Linux Nativo | Differenza |
|------------|----------------|--------------|------------|
| Container startup | 2-3s | 1-2s | +50% |
| Build immagine | 30s | 25s | +20% |
| File I/O (volume Linux) | ~95% | 100% | -5% |
| File I/O (bind mount Windows) | ~30-50% | 100% | -50-70% |
| Network | ~98% | 100% | -2% |

### Best Practices Performance

#### ✅ DO: Usa File System Linux (WSL2)

```yaml
# docker-compose.yml

services:
  openacs-a:
    volumes:
      # VELOCE: usa named volume (filesystem Linux)
      - oacs-a_data:/var/www/openacs
      
      # LENTO: bind mount da Windows
      # - C:/Users/marco/oacs-a:/var/www/openacs  ❌
```

**Spiegazione:**
- Named volumes vivono nel filesystem WSL2 (ext4)
- Bind mount da C:\ attraversa boundary Windows/Linux → lento
- Per codice: usa IDE su WSL2 o clona repo in WSL2

#### ✅ DO: Sviluppa Dentro WSL2

```bash
# Apri terminale WSL2
wsl

# Naviga al progetto (filesystem Linux!)
cd ~/projects/oacs-development

# Codice qui è veloce
git clone https://github.com/...
docker compose up
```

**Con VSCode:**
```bash
# Installa estensione "Remote - WSL"
# Poi in VSCode: F1 → "WSL: Open Folder in WSL"
# Il tuo codice è su WSL2 = veloce!
```

#### ❌ DON'T: Bind Mount da C:\

```yaml
# LENTO! ❌
volumes:
  - C:/Users/marco/projects/oacs-a:/var/www/openacs
  
# Ogni accesso file passa per:
# Container → Docker → WSL2 → Windows NTFS → WSL2 → Container
# Latenza: ~10-100x rispetto a filesystem nativo
```

**Eccezioni quando bind mount Windows va bene:**
- File di config piccoli (docker-compose.yml)
- Read-only files
- Poche operazioni I/O

---

## Problematiche Comuni Windows

### 1. Line Endings (CRLF vs LF)

**Problema:**
Windows usa CRLF (`\r\n`), Linux usa LF (`\n`)
Script bash con CRLF causano errori:
```
bash: ./script.sh: /bin/bash^M: bad interpreter
```

**Soluzione:**

```bash
# Configura Git globalmente
git config --global core.autocrlf input

# In repository, aggiungi .gitattributes
cat > .gitattributes << EOF
* text=auto
*.sh text eol=lf
*.md text eol=lf
*.yml text eol=lf
*.sql text eol=lf
EOF

# Converti file esistenti
dos2unix script.sh
# o in Git Bash:
sed -i 's/\r$//' script.sh
```

**In VSCode:**
- Bottom right: "CRLF" → click → "LF"
- Settings → Files: EOL → `\n`

### 2. Path Separators

**Problema:**
Windows: `C:\path\to\file`
Linux: `/path/to/file`

**Soluzione in docker-compose.yml:**

```yaml
# ❌ NON PORTABILE
volumes:
  - C:\Users\marco\data:/data

# ✅ PORTABILE (usa forward slash sempre)
volumes:
  - C:/Users/marco/data:/data
  # Docker su Windows converte automaticamente

# ✅ ANCORA MEGLIO (usa variabili)
volumes:
  - ${HOME}/data:/data
  # ${HOME} = C:/Users/marco su Windows
  #         = /home/marco su Linux
```

### 3. Permessi File

**Problema:**
Windows non ha concetto di permessi Unix (chmod)

**Soluzione:**

```yaml
# In docker-compose.yml
services:
  openacs:
    volumes:
      - ./scripts:/scripts
    # Dopo mount, aggiusta permessi:
    command: >
      sh -c "
        chmod +x /scripts/*.sh &&
        ./start.sh
      "
```

**In WSL2:**
```bash
# Configura WSL per preservare permessi
# In /etc/wsl.conf:
[automount]
options = "metadata"

# Restart WSL
wsl --shutdown
wsl
```

### 4. Performance File Watching

**Problema:**
IDE su Windows che monitora file in container → lento

**Soluzione:**
```yaml
# docker-compose.yml
services:
  openacs:
    environment:
      # Usa polling invece di inotify
      CHOKIDAR_USEPOLLING: "true"
      CHOKIDAR_INTERVAL: 1000
```

**Oppure:**
Usa IDE in WSL2 (VSCode Remote-WSL)

---

## Setup Consigliato per Team Misto

### Configurazione Repository Git

**.gitattributes** (obbligatorio):
```
# Line endings
* text=auto
*.sh text eol=lf
*.sql text eol=lf
*.tcl text eol=lf
*.adp text eol=lf

# Binary files
*.png binary
*.jpg binary
*.pdf binary
```

**.gitignore**:
```
# OS specific
.DS_Store
Thumbs.db
desktop.ini

# IDE
.vscode/
.idea/
*.swp

# Docker
.env.local
```

**README.md** - Istruzioni Setup:
```markdown
## Setup Sviluppo

### Windows
1. Installa Docker Desktop con WSL2
2. Clona repo DENTRO WSL2:
   ```bash
   wsl
   cd ~
   git clone https://...
   ```
3. Apri con VSCode Remote-WSL
4. `docker compose up`

### Linux / macOS
1. Installa Docker
2. Clona repo
3. `docker compose up`
```

---

## Docker Compose Multi-Piattaforma

### File docker-compose.yml Portabile

```yaml
version: '3.8'

services:
  openacs-a:
    image: gustafn/openacs:latest
    
    volumes:
      # ✅ Named volumes: funzionano identici ovunque
      - oacs-a_data:/var/www/openacs
      - oacs-a_log:/var/www/openacs/log
      
      # ✅ Path relativi: portabili
      - ./config.tcl:/var/www/openacs/etc/config.tcl:ro
      
      # ✅ Variabili ambiente: adatta automaticamente
      - ${PWD}/secrets:/run/secrets:ro
      
    environment:
      # ✅ Variabili funzionano ovunque
      oacs_db_host: ${DB_HOST:-db}
      
volumes:
  oacs-a_data:
  oacs-a_log:
```

### File .env Multi-Piattaforma

```bash
# .env
# Funziona su Windows, Linux, macOS

# Database
DB_HOST=db
DB_PORT=5432

# Paths (usa forward slash sempre!)
CONFIG_DIR=./config
SECRETS_DIR=./secrets

# Windows-specific (se necessario)
# COMPOSE_CONVERT_WINDOWS_PATHS=1
```

---

## Workflow Sviluppatore Windows

### Opzione A: Tutto in WSL2 (Consigliato) ⭐

```bash
# 1. Apri WSL2
wsl

# 2. Naviga a progetto (in filesystem WSL!)
cd ~/projects/oacs-dev

# 3. Sviluppo normale
code .  # VSCode con Remote-WSL
git pull
docker compose up -d
docker compose logs -f

# Performance: ~95% di Linux nativo
```

**Vantaggi:**
- Performance eccellenti
- Nessun problema line endings
- Workflow identico a Linux
- Tools Linux disponibili

**Svantaggi:**
- File non visibili facilmente in Windows Explorer
- Curva apprendimento WSL

### Opzione B: Codice su Windows, Docker in WSL2

```yaml
# docker-compose.yml
services:
  openacs:
    volumes:
      # Codice su Windows (per IDE Windows)
      - /mnt/c/Users/marco/projects/oacs-a:/var/www/openacs
      # ⚠️ LENTO per molti file piccoli
      # OK per sviluppo sporadico
```

**Vantaggi:**
- File visibili in Windows Explorer
- IDE Windows nativi (Visual Studio, etc.)

**Svantaggi:**
- Performance I/O ridotte (~30-50%)
- Problemi line endings possibili
- Watch file lento

### Opzione C: Hybrid (Compromesso)

```yaml
services:
  openacs:
    volumes:
      # Codice in named volume (veloce)
      - oacs_code:/var/www/openacs
      
      # Solo config su Windows (pochi file, OK)
      - ./config:/config:ro
      
    # Script di sync codice da Windows
    # (rsync, watchman, etc.)
```

---

## Checklist Setup Team Windows

### Per Amministratori

- [ ] **Standardizza su WSL2**
  - Crea guida interna setup WSL2
  - Template .gitattributes nel repository
  - Script di verifica ambiente

- [ ] **Docker Desktop Settings**
  ```
  Settings → General:
    ✓ Use WSL2 based engine
    ✓ Send usage statistics: OFF (privacy)
  
  Settings → Resources → WSL Integration:
    ✓ Enable integration with my default WSL distro
    ✓ Ubuntu (se installato)
  
  Settings → Resources:
    Memory: 4-8 GB
    CPUs: 2-4 cores
  ```

- [ ] **Documentazione**
  - README con setup Windows
  - Troubleshooting comune
  - FAQ line endings, paths

### Per Sviluppatori Windows

- [ ] **Installa WSL2**
  ```powershell
  wsl --install -d Ubuntu
  wsl --set-default-version 2
  ```

- [ ] **Installa Docker Desktop**
  - Download da docker.com
  - Durante install: "Use WSL2"
  - Verifica: `docker --version`

- [ ] **Setup Git**
  ```bash
  git config --global core.autocrlf input
  git config --global core.eol lf
  ```

- [ ] **Installa VSCode Remote-WSL**
  - Extension: "Remote - WSL"
  - F1 → "WSL: Open Folder in WSL"

- [ ] **Clone Repo in WSL2**
  ```bash
  wsl
  cd ~
  mkdir projects
  cd projects
  git clone https://...
  ```

- [ ] **Test Docker**
  ```bash
  docker compose up
  # Se funziona = setup corretto!
  ```

---

## Portainer - Management Interface

### Cos'è Portainer

Portainer è una **web UI per gestire Docker** visualmente.

**Caratteristiche:**
- Dashboard container, immagini, volumi, network
- Start/stop/restart container con click
- Visualizza logs in real-time
- Gestione stack Docker Compose
- Monitoring risorse
- Console web nei container
- Multi-host support

### Quando è Utile

✅ **Ottimo per:**
- **Sviluppatori junior**: non devono memorizzare comandi Docker
- **Management/non-tecnici**: visualizzare stato sistema
- **Troubleshooting visuale**: vedere logs, risorse, network
- **Demo/presentazioni**: mostrare Docker visivamente
- **Onboarding**: nuovi sviluppatori imparano Docker più facilmente
- **Team misti**: Windows users che preferiscono GUI

⚠️ **Meno utile per:**
- Esperti Docker: CLI è più veloce
- Automazione: scripting meglio con CLI
- CI/CD: pipeline automatiche non usano UI

### Installazione Portainer

#### Per Sviluppo (Single Node)

```bash
# Crea volume per dati Portainer
docker volume create portainer_data

# Avvia Portainer
docker run -d \
  -p 9000:9000 \
  -p 9443:9443 \
  --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

# Accedi a: https://localhost:9443
# Primo accesso: crea admin user
```

#### Con Docker Compose

```yaml
# docker-compose.portainer.yml
version: '3.8'

services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: always
    
    ports:
      - "9000:9000"
      - "9443:9443"
    
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    
    networks:
      - portainer-network

networks:
  portainer-network:
    driver: bridge

volumes:
  portainer_data:
```

```bash
docker compose -f docker-compose.portainer.yml up -d
```

#### Per Produzione Multi-Server

```yaml
# Portainer Server (host centrale)
services:
  portainer:
    image: portainer/portainer-ce:latest
    ports:
      - "9443:9443"
      - "8000:8000"  # Edge agent communication
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    
# Su altri server: Portainer Agent
services:
  agent:
    image: portainer/agent:latest
    ports:
      - "9001:9001"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /var/lib/docker/volumes:/var/lib/docker/volumes
```

### Funzionalità Principali

#### 1. Dashboard Container

- Lista tutti i container (running, stopped)
- Status, uptime, risorse usate
- Quick actions: start, stop, restart, kill, remove
- Logs real-time
- Stats (CPU, RAM, Network, I/O)

#### 2. Gestione Stack

```
Stacks → Add Stack
  Nome: oacs-production
  Build method: 
    - Web editor (incolla docker-compose.yml)
    - Git repository (auto-deploy da repo)
    - Upload file
  
→ Deploy
```

**Vantaggi:**
- Gestione stack visuale
- Update stack con click
- Rollback versioni precedenti
- Environment variables via UI

#### 3. Console Web

Click su container → Console → `/bin/bash`
- Shell interattiva in browser
- Non serve SSH
- Utile per troubleshooting rapido

#### 4. Registry Management

- Connetti Docker Hub, GitLab, registry privato
- Pull immagini con UI
- Scan vulnerabilità (con Portainer Business)

#### 5. Multi-Host Management

Con Portainer Business o Agent:
- Gestisci più server Docker da una UI
- Switch tra ambienti (dev, staging, prod)
- Deploy stesso stack su N server

### Portainer per il Nostro Caso OpenACS

#### Setup Consigliato

```yaml
# docker-compose.yml (ambiente sviluppo + Portainer)
version: '3.8'

services:
  # ... (openacs-a, openacs-b, db, nginx)
  
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    
    ports:
      - "127.0.0.1:9443:9443"  # Solo localhost in dev
    
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    
    networks:
      - oacs-network
    
    labels:
      - "description=Portainer - Docker Management UI"

volumes:
  portainer_data:
```

#### Casi d'Uso Team

**Sviluppatore Windows:**
```
Portainer: https://localhost:9443
  → Stacks → oacs-dev → Start
  → Container openacs-a → Logs (in browser, no CLI)
  → Volumes → Inspect oacs-a_data
```

**Demo a Management:**
```
Portainer → Dashboard
  "Ecco lo stack: 5 container running"
  → openacs-a → Stats → "Usa 200MB RAM, 5% CPU"
  → Logs → "Vedi richieste in real-time"
```

**Troubleshooting:**
```
Portainer → Containers → openacs-a
  → Inspect → vedi tutte le configurazioni
  → Stats → grafici risorse
  → Console → bash nel container
  → Logs → cerca errori
```

**Onboarding nuovo sviluppatore:**
```
"Apri Portainer → Stacks → oacs-dev → Deploy"
Tutto parte, nessun comando da memorizzare.
```

### Portainer: Pro e Contro

#### ✅ Vantaggi

1. **Facilità d'uso**
   - UI intuitiva
   - Nessun comando da memorizzare
   - Curva apprendimento bassissima

2. **Visualizzazione**
   - Dashboard stato sistema
   - Grafici risorse
   - Network topology
   - Volume inspector

3. **Produttività**
   - Operazioni comuni con click
   - Templates riusabili
   - Logs aggregati

4. **Team non-tecnico**
   - Management può vedere stato
   - Support può fare troubleshooting base
   - Demo efficaci

5. **Multi-ambiente**
   - Gestisci dev, staging, prod da una UI
   - Switch veloce tra ambienti

#### ❌ Svantaggi

1. **Performance**
   - UI carica più lenta di CLI
   - Refresh automatico consuma risorse

2. **Automazione limitata**
   - Non sostituisce script
   - CI/CD meglio con CLI

3. **Overhead**
   - Container extra (Portainer stesso)
   - ~100MB RAM per Portainer

4. **Security surface**
   - Un'altra interfaccia da proteggere
   - Accesso a Docker socket = root access

5. **Dipendenza**
   - Se Portainer giù, devi usare CLI
   - Lock-in parziale (abituarsi a UI)

### Raccomandazioni Portainer

#### Per Sviluppo: ✅ Sì

```yaml
# docker-compose.dev.yml
services:
  portainer:
    image: portainer/portainer-ce:latest
    ports:
      - "127.0.0.1:9443:9443"  # Solo localhost
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
```

**Benefici:**
- Sviluppatori Windows: UI più familiare
- Onboarding: learning curve ridotta
- Troubleshooting: visuale più chiaro

#### Per Produzione: ⚠️ Con Cautela

**Se sì:**
```yaml
# docker-compose.prod.yml
services:
  portainer:
    image: portainer/portainer-ce:latest
    restart: always
    
    ports:
      # NON esporre pubblicamente!
      - "127.0.0.1:9443:9443"
    
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro  # Read-only!
      - portainer_data:/data
    
    # Auth obbligatorio
    environment:
      PORTAINER_ADMIN_PASSWORD_FILE: /run/secrets/portainer_password
    
    secrets:
      - portainer_password

secrets:
  portainer_password:
    file: ./secrets/portainer_password
```

**Security checklist:**
- [ ] Mai esporre porta 9443 su 0.0.0.0
- [ ] Usa HTTPS (certificato valido)
- [ ] Password forte admin
- [ ] Docker socket read-only se possibile
- [ ] RBAC (Portainer Business) per team
- [ ] Audit log abilitato
- [ ] Backup configurazione Portainer

**Se no (produzione critica):**
- Usa solo CLI per produzione
- Portainer solo su staging/dev
- Script automatizzati per deploy
- Monitoring con Prometheus/Grafana

### Alternative a Portainer

| Tool | Pro | Contro | Caso d'uso |
|------|-----|--------|------------|
| **Portainer** | Facile, completo, UI bella | Overhead, security | Dev, staging, demo |
| **Lazydocker** | TUI leggero, zero overhead | Solo locale, no multi-host | Dev personale |
| **Docker Desktop** | Integrato, semplice | Solo locale, basic | Dev Windows/Mac |
| **Rancher** | Enterprise, Kubernetes | Complesso, overkill | Large scale |
| **Yacht** | Leggero, semplice | Meno feature | Homelab |
| **Dockge** | Stack-focused, semplice | Giovane, meno maturo | Stack management |

### Portainer: Decisione Finale

**Consiglio per il vostro caso:**

✅ **Sì, usa Portainer per:**
- Ambiente di sviluppo (tutti i developer)
- Server staging
- Demo e presentazioni
- Onboarding nuovi sviluppatori

❌ **No, non usare per:**
- Deploy produzione critica (usa script)
- CI/CD pipeline (usa docker CLI)
- Server produzione esposti (security risk)

**Setup ibrido ideale:**
```
Sviluppo:
  ✓ Portainer (facile)
  ✓ Script deploy (per imparare)

Staging:
  ✓ Portainer (debugging visuale)
  ✓ Script deploy (test automazione)

Produzione:
  ✗ Portainer (usa solo se security OK)
  ✓ Script deploy (affidabile, auditabile)
  ✓ CLI per troubleshooting
```

---

## Conclusioni

### Docker su Windows

**Verdetto: ✅ Funziona bene con WSL2**

**Setup consigliato:**
1. Docker Desktop + WSL2
2. Codice in filesystem WSL2
3. VSCode Remote-WSL
4. Named volumes per dati

**Performance:** 90-95% di Linux nativo se fatto bene.

**Problemi gestibili:**
- Line endings: .gitattributes
- Path: sempre forward slash
- Performance: usa filesystem WSL2

### Portainer

**Verdetto: ✅ Utile, specialmente per team misti**

**Usa quando:**
- Hai developer Windows (preferiscono GUI)
- Team con skill Docker variabili
- Serve dimostrare visualmente
- Onboarding frequente

**Non usare quando:**
- Produzione critica (security)
- CI/CD (automazione)
- Team CLI-only (overhead inutile)

**Best practice:**
- Dev/staging: sì
- Produzione: valuta security
- Mai esporre pubblicamente
- Combina con CLI (non sostituire)

---

## Risorse

### Docker su Windows
- [Docker Desktop Docs](https://docs.docker.com/desktop/windows/)
- [WSL2 Best Practices](https://docs.docker.com/desktop/wsl/)
- [Performance Tips](https://docs.docker.com/desktop/wsl/best-practices/)

### Portainer
- [Portainer Docs](https://docs.portainer.io/)
- [Installation Guide](https://docs.portainer.io/start/install)
- [Best Practices](https://docs.portainer.io/admin/best-practices)

### Community
- Docker Forum: [forums.docker.com](https://forums.docker.com)
- Portainer Community: [portainer.io/community](https://www.portainer.io/community)
