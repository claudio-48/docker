# Quick Start - Docker su Windows per OpenACS

## Setup Iniziale (Una Tantum)

### 1. Installa WSL2

Apri PowerShell **come Amministratore**:

```powershell
# Installa WSL2 con Ubuntu
wsl --install -d Ubuntu

# Riavvia il computer
# Al riavvio, Ubuntu si aprirà automaticamente
# Crea username e password Linux
```

### 2. Installa Docker Desktop

1. Download: https://www.docker.com/products/docker-desktop/
2. Esegui installer
3. Durante install: assicurati che sia selezionato **"Use WSL 2"**
4. Riavvia se richiesto

### 3. Configura Docker Desktop

Apri Docker Desktop → Settings:

```
General:
  ✓ Use WSL 2 based engine

Resources → WSL Integration:
  ✓ Enable integration with my default WSL distro
  ✓ Ubuntu

Resources → Advanced:
  Memory: 4096 MB (minimo) - 8192 MB (consigliato)
  CPUs: 2 (minimo) - 4 (consigliato)
```

Click "Apply & Restart"

### 4. Verifica Installazione

Apri PowerShell:

```powershell
# Test Docker
docker --version
# Output: Docker version 24.x.x

# Test Docker Compose
docker compose version
# Output: Docker Compose version v2.x.x

# Test WSL2
wsl --list --verbose
# Output: 
#   NAME      STATE           VERSION
# * Ubuntu    Running         2
```

**Se tutto OK, sei pronto!** ✅

---

## Setup Progetto OpenACS

### Opzione A: Progetto in WSL2 (Consigliato) ⭐

```powershell
# 1. Apri WSL2
wsl

# Ora sei in Linux!
# 2. Crea directory progetti
mkdir -p ~/projects
cd ~/projects

# 3. Clone repository
git clone https://github.com/your-org/oacs-docker.git
cd oacs-docker

# 4. Configura Git (se primo uso)
git config --global core.autocrlf input
git config --global core.eol lf

# 5. Setup ambiente
cp .env.example .env
nano .env  # o usa 'code .env' se hai VSCode

# 6. Crea secrets
mkdir -p secrets
echo "your-postgres-password" > secrets/psql_password

# 7. Avvia stack
docker compose up -d

# 8. Verifica
docker compose ps
docker compose logs -f

# Accedi a:
# OpenACS A: http://localhost:8080
# OpenACS B: http://localhost:8081
# Portainer: https://localhost:9443
```

### Opzione B: Progetto su C:\ (Più Facile ma Più Lento)

```powershell
# 1. Clone su Windows
cd C:\Users\TuoNome\Projects
git clone https://github.com/your-org/oacs-docker.git
cd oacs-docker

# 2. Configura Git
git config core.autocrlf input

# 3. Converti line endings
# In Git Bash (o installa dos2unix):
find . -name "*.sh" -exec dos2unix {} \;

# 4. Setup .env
copy .env.example .env
notepad .env

# 5. Secrets
mkdir secrets
echo your-postgres-password > secrets\psql_password

# 6. Avvia
docker compose up -d
```

⚠️ **Attenzione:** Se usi bind mount da C:\, performance I/O saranno ~50% più lente.

---

## Usare VSCode con WSL2

### Setup VSCode Remote-WSL

1. Installa VSCode: https://code.visualstudio.com/
2. Installa extension: "Remote - WSL"
3. Riavvia VSCode

### Aprire Progetto in WSL2

```powershell
# Apri WSL2
wsl

# Naviga al progetto
cd ~/projects/oacs-docker

# Apri VSCode in WSL2
code .

# VSCode si apre con "WSL: Ubuntu" nell'angolo in basso a sinistra
```

**Vantaggi:**
- Editor Windows, file su Linux (performance ottime)
- Terminal integrato usa bash WSL2
- Git integrato funziona perfettamente
- Extensions funzionano in WSL2

---

## Workflow Quotidiano

### Aprire Progetto

```powershell
# Opzione 1: Da PowerShell
wsl -d Ubuntu -e bash -c "cd ~/projects/oacs-docker && code ."

# Opzione 2: WSL Terminal
wsl
cd ~/projects/oacs-docker
code .

# Opzione 3: Da VSCode
# F1 → "WSL: Open Folder in WSL"
# Seleziona: ~/projects/oacs-docker
```

### Comandi Docker Comuni

```bash
# In WSL2 terminal o VSCode terminal

# Avvia stack
docker compose up -d

# Stop stack
docker compose down

# Restart singolo container
docker compose restart openacs-a

# Logs
docker compose logs -f
docker compose logs -f openacs-a

# Status
docker compose ps

# Shell in container
docker compose exec openacs-a /bin/sh

# Rebuild dopo modifiche
docker compose up -d --build
```

### Modificare Codice

```bash
# Il codice è in:
~/projects/oacs-docker/

# Con VSCode Remote-WSL:
# - Modifica file normalmente
# - Salva con Ctrl+S
# - Container vede modifiche immediatamente (se bind mount)

# Con bind mount:
# volumes:
#   - ./code:/var/www/openacs
# 
# Modifiche sono real-time!
```

### Accedere a Database

```bash
# Opzione 1: Da terminale
docker compose exec db psql -U postgres -d oacs-a

# Opzione 2: Tool grafico (pgAdmin, DBeaver)
# Host: localhost
# Port: 5432
# User: postgres
# Password: (quella in secrets/psql_password)
# Database: oacs-a
```

---

## Usare Portainer

### Primo Accesso

1. Apri browser: https://localhost:9443
2. Primo accesso: crea admin user
   - Username: admin
   - Password: (minimo 12 caratteri)
3. Seleziona "Get Started" → Local

### Dashboard

```
Home → Local → Containers
  - Vedi tutti i container
  - Click per dettagli, logs, stats
  - Quick actions: start, stop, restart

Home → Local → Stacks
  - Gestisci stack Docker Compose
  - Update, redeploy, remove

Home → Local → Volumes
  - Vedi volumi
  - Ispeziona contenuto
  - Backup/restore
```

### Operazioni Comuni in Portainer

**Riavviare container:**
```
Containers → openacs-a → ⟳ Restart
```

**Vedere logs:**
```
Containers → openacs-a → 📝 Logs
  - Real-time
  - Filtra per timestamp
  - Download logs
```

**Shell in container:**
```
Containers → openacs-a → >_ Console
  - Seleziona: /bin/sh
  - Click "Connect"
  - Hai shell interattiva in browser!
```

**Monitorare risorse:**
```
Containers → openacs-a → 📊 Stats
  - Grafici CPU, RAM, Network
  - Real-time
```

**Deploy stack:**
```
Stacks → + Add stack
  Nome: oacs-production
  Build method: Web editor
  Incolla docker-compose.yml
  → Deploy stack
```

---

## Troubleshooting Windows

### Problema: "WSL 2 installation is incomplete"

**Soluzione:**
```powershell
# Aggiorna kernel WSL2
wsl --update

# Riavvia WSL
wsl --shutdown
wsl
```

### Problema: "docker: command not found" in WSL

**Soluzione:**
```bash
# Verifica integrazione in Docker Desktop
# Settings → Resources → WSL Integration
# Assicurati che Ubuntu sia abilitato

# Riavvia Docker Desktop
# Riavvia WSL:
exit  # esci da WSL
wsl --shutdown
wsl
```

### Problema: Container molto lenti

**Diagnosi:**
```bash
# Dove sono i tuoi file?
pwd
# Se output: /mnt/c/Users/... → PROBLEMA!
# File su Windows filesystem = lento

# Soluzione: sposta in WSL2
cd ~
mkdir projects
# Sposta progetto qui
```

**Test performance:**
```bash
# Test write speed
dd if=/dev/zero of=test.bin bs=1M count=100
# In WSL2 home: ~500-1000 MB/s
# In /mnt/c: ~50-200 MB/s

# Cleanup
rm test.bin
```

### Problema: "Bad interpreter: ^M"

**Causa:** Line endings Windows (CRLF) invece di Linux (LF)

**Soluzione:**
```bash
# Converti singolo file
sed -i 's/\r$//' script.sh

# Converti tutti gli .sh
find . -name "*.sh" -exec sed -i 's/\r$//' {} \;

# Previeni in futuro
git config --global core.autocrlf input
```

### Problema: Portainer non accessibile

**Soluzione:**
```bash
# Verifica container running
docker ps | grep portainer

# Se non running:
docker compose up -d portainer

# Verifica logs
docker compose logs portainer

# Test porta
curl -k https://localhost:9443
# Se risponde: OK

# In browser, accetta certificato self-signed
# Chrome: click "Advanced" → "Proceed to localhost"
```

### Problema: Out of disk space

**Diagnosi:**
```bash
# Spazio usato Docker
docker system df

# Dettagli
docker system df -v
```

**Pulizia:**
```bash
# Rimuovi container stopped
docker container prune

# Rimuovi immagini unused
docker image prune -a

# Rimuovi volumi unused (ATTENZIONE!)
docker volume prune

# Pulizia completa
docker system prune -a --volumes
# ⚠️ Rimuove TUTTO non in uso!
```

### Problema: "Permission denied" accedendo a file

**In WSL2:**
```bash
# Configura metadata permissions
sudo nano /etc/wsl.conf

# Aggiungi:
[automount]
options = "metadata"

# Riavvia WSL
exit
wsl --shutdown
wsl

# Ora chmod funziona
chmod +x script.sh
```

---

## Best Practices Windows + Docker

### ✅ DO

1. **Usa WSL2** (non Hyper-V)
2. **Progetti in ~/projects** (non /mnt/c)
3. **VSCode Remote-WSL** per editing
4. **Git in WSL2** (non Git for Windows)
5. **Named volumes** per dati persistenti
6. **.gitattributes** per line endings
7. **Portainer** per UI (se preferisci)

### ❌ DON'T

1. **Bind mount da C:\** (troppo lento)
2. **Edit file con Notepad** (problemi encoding)
3. **Git for Windows su repo WSL2** (conflitti)
4. **Dimenticare core.autocrlf = input**
5. **Docker su Hyper-V** (legacy)
6. **Esporre Portainer pubblicamente** (security)

---

## Comandi Rapidi

### Setup

```bash
# Clone in WSL2
wsl
cd ~
git clone URL
cd project

# Config Git
git config --global core.autocrlf input
git config --global core.eol lf

# Avvia
docker compose up -d
```

### Sviluppo

```bash
# Apri VSCode
code .

# Logs
docker compose logs -f

# Restart
docker compose restart service-name

# Shell
docker compose exec service-name /bin/sh
```

### Portainer

```
URL: https://localhost:9443
User: admin
Pass: (tua password)

Dashboard → Vedi tutto
Containers → Gestisci
Stacks → Deploy
```

### Pulizia

```bash
# Stop tutto
docker compose down

# Remove volumi (ATTENZIONE!)
docker compose down -v

# Pulizia generale
docker system prune
```

---

## Cheat Sheet Path

### WSL2 → Windows

```bash
# Da WSL2, accedi a file Windows:
cd /mnt/c/Users/TuoNome/Documents

# Apri Explorer Windows da WSL2:
explorer.exe .
```

### Windows → WSL2

```powershell
# Da Windows, accedi a file WSL2:
\\wsl$\Ubuntu\home\username\projects

# In Explorer:
# Indirizzo: \\wsl$\Ubuntu\home\username
```

### VSCode

```bash
# Apri file/folder da WSL2:
code file.txt
code /path/to/folder

# Apri progetto corrente:
code .
```

---

## Risorse

### Documentazione
- [Docker Desktop for Windows](https://docs.docker.com/desktop/windows/)
- [WSL2 Best Practices](https://docs.docker.com/desktop/wsl/)
- [Portainer Docs](https://docs.portainer.io/)

### Video Tutorial
- [Docker on Windows (YouTube)](https://www.youtube.com/results?search_query=docker+windows+wsl2)
- [VSCode Remote WSL](https://code.visualstudio.com/docs/remote/wsl-tutorial)

### Community
- [Docker Forums](https://forums.docker.com)
- [WSL GitHub](https://github.com/microsoft/WSL)
- [Portainer Community](https://www.portainer.io/community)

---

## Help

**Problemi?**
1. Controlla questa guida
2. Docker Desktop → Troubleshoot → Reset to factory defaults
3. Chiedi al team: #docker-help su Slack

**Setup assistito:**
Prenota slot con IT team per setup guidato (30 min)
