he# Migrazione da CVS a Git - Guida Completa

## Panoramica

Questa guida ti aiuta nella transizione graduale da CVS a Git, mantenendo entrambi i sistemi funzionanti durante il periodo di migrazione.

## Fase 1: Ambiente Ibrido CVS + Git (Transizione)

Durante questa fase, continui a usare CVS ma inizi a preparare Git.

### Setup Ambiente di Sviluppo

```bash
# 1. Verifica stato CVS attuale
cd /var/www/oacs-a
cvs status | head -20

# 2. Committa tutte le modifiche pendenti
cvs commit -m "Pre-Git migration commit"

# 3. Inizializza Git (senza rimuovere CVS)
git init
git add .
git commit -m "Initial commit - migrated from CVS"

# 4. Crea .gitignore per ignorare metadata CVS
cat > .gitignore << 'EOF'
# CVS directories (temporaneo durante migrazione)
CVS/
.#*

# Log files
log/
*.log

# Temporary files
tmp/
*.swp
*.swo
*~

# OS files
.DS_Store
Thumbs.db
EOF

git add .gitignore
git commit -m "Add .gitignore"

# 5. Push su repository remoto
git remote add origin git@github.com:tuoaccount/oacs-a.git
git push -u origin main
```

### Workflow Durante la Transizione

Durante il periodo di transizione, puoi scegliere quale sistema usare per ogni deploy:

```bash
# Opzione A: Deploy con CVS (metodo corrente)
./sync-cvs-to-prod.sh oacs-a

# Opzione B: Deploy con Git (nuovo metodo)
./deploy-from-git.sh oacs-a

# Opzione C: Deploy senza versioning (emergenza)
./sync-to-prod-simple.sh oacs-a
```

## Fase 2: Migrazione Completa del Repository CVS

### Opzione 1: Migrazione Semplice (Snapshot)

La più semplice - prendi lo stato attuale e parti da lì:

```bash
# Già fatto nella Fase 1
cd /var/www/oacs-a
git init
git add .
git commit -m "Initial commit from CVS"
```

**Vantaggi:**
- Veloce e semplice
- Nessuna complessità

**Svantaggi:**
- Perdi la storia CVS
- Non puoi vedere commit precedenti

### Opzione 2: Migrazione con Storia (cvs2git)

Mantiene tutta la storia dei commit CVS:

```bash
# 1. Installa cvs2git
sudo apt-get install cvs2git  # Debian/Ubuntu
# oppure
brew install cvs2git  # macOS

# 2. Crea file di configurazione
cat > cvs2git-options.py << 'EOF'
import os
from cvs2svn_lib.common import CVSTextDecoder
from cvs2svn_lib.log import logger
from cvs2svn_lib.project import Project
from cvs2svn_lib.git_output_option import GitRevisionCollector
from cvs2svn_lib.git_output_option import GitOutputOption
from cvs2svn_lib.dvcs_common import KeywordHandlingPropertySetter
from cvs2svn_lib.revision_manager import NullRevisionCollector

# Percorso al tuo repository CVS
cvs_repo_main_dir = '/path/to/cvs/repository'
cvs_module = 'openacs'  # Il tuo modulo CVS

# Output directory
git_blob_filename = 'cvs2git-tmp/git-blob.dat'
git_dump_filename = 'cvs2git-tmp/git-dump.dat'

# Configurazione encoding (adatta se necessario)
ctx.encoding = 'utf-8'

# Project
ctx.project = Project(
    cvs_repo_main_dir,
    name='OpenACS',
)

# Mantieni keyword CVS
ctx.property_setters.append(KeywordHandlingPropertySetter('off'))

# Output Git
ctx.output_option = GitOutputOption(
    git_blob_filename,
    git_dump_filename,
    GitRevisionCollector(),
)
EOF

# 3. Esegui conversione
cvs2git --options=cvs2git-options.py

# 4. Crea repository Git
mkdir oacs-a-git
cd oacs-a-git
git init
cat ../cvs2git-tmp/git-blob.dat ../cvs2git-tmp/git-dump.dat | git fast-import

# 5. Verifica
git log --oneline | head -20
git branch -a
```

**Vantaggi:**
- Mantieni tutta la storia
- Puoi vedere vecchi commit
- Blame e bisect funzionano

**Svantaggi:**
- Più complesso
- Richiede tempo

### Opzione 3: Migrazione Incrementale (Raccomandato)

Il compromesso migliore - converti ma continua a sincronizzare con CVS:

```bash
#!/bin/bash
# cvs-git-sync.sh - Mantieni sincronizzati CVS e Git durante transizione

CVS_PATH="/var/www/oacs-a"
GIT_PATH="/var/www/oacs-a-git"

# 1. Update da CVS
cd ${CVS_PATH}
cvs update -d -P

# 2. Copia modifiche a Git (escludendo metadata CVS)
rsync -av \
    --exclude='CVS' \
    --exclude='.git' \
    --exclude='log' \
    ${CVS_PATH}/ ${GIT_PATH}/

# 3. Commit in Git
cd ${GIT_PATH}
git add .
git commit -m "Sync from CVS - $(date +%Y-%m-%d)" || true
git push origin main
```

## Fase 3: Switch Completo a Git

Quando sei pronto per abbandonare CVS completamente:

### Checklist Pre-Switch

- [ ] Tutti i developer hanno accesso al repository Git
- [ ] Tutti i developer sanno usare Git base (commit, push, pull)
- [ ] CI/CD aggiornato per usare Git invece di CVS
- [ ] Script di deploy testati con Git
- [ ] Backup completo dell'ultimo stato CVS
- [ ] Documentazione aggiornata

### Procedura di Switch

```bash
# 1. Ultimo sync CVS → Git
cd /var/www/oacs-a
cvs commit -m "Final CVS commit before Git migration"
cvs update

cd /var/www/oacs-a-git  # o il tuo repo Git
# Sync finale
git add .
git commit -m "Final sync from CVS - switching to Git"
git push origin main

# 2. Tag il commit di migrazione
git tag -a cvs-migration -m "Last CVS sync - Git becomes source of truth"
git push origin cvs-migration

# 3. Sostituisci directory CVS con Git
sudo mv /var/www/oacs-a /var/www/oacs-a.cvs.backup
sudo mv /var/www/oacs-a-git /var/www/oacs-a

# 4. Aggiorna produzione
cd /path/to/oacs-production
./deploy-from-git.sh oacs-a

# 5. Test completo
./manage.sh status
./manage.sh logs oacs-a
```

### Post-Migration Cleanup

```bash
# Dopo 1 mese di funzionamento stabile con Git:

# 1. Archivia repository CVS
tar czf /backup/cvs-archive-$(date +%Y%m%d).tar.gz /var/www/oacs-a.cvs.backup

# 2. Rimuovi backup CVS da disco attivo
# (SOLO dopo aver verificato che l'archivio è completo!)
sudo rm -rf /var/www/oacs-a.cvs.backup

# 3. Rimuovi CVS dai container produzione
docker exec openacs-a-prod apk del cvs
```

## Script Utili per la Transizione

### Verifica Divergenze CVS vs Git

```bash
#!/bin/bash
# check-cvs-git-diff.sh
# Verifica se CVS e Git sono allineati

CVS_PATH="/var/www/oacs-a"
GIT_PATH="/var/www/oacs-a-git"

echo "Controllo differenze CVS vs Git..."

# Copia temporanea senza metadata
TMP_CVS=$(mktemp -d)
TMP_GIT=$(mktemp -d)

rsync -av --exclude='CVS' --exclude='.git' --exclude='log' ${CVS_PATH}/ ${TMP_CVS}/
rsync -av --exclude='CVS' --exclude='.git' --exclude='log' ${GIT_PATH}/ ${TMP_GIT}/

# Confronto
diff -rq ${TMP_CVS} ${TMP_GIT} || echo "Differenze trovate!"

# Cleanup
rm -rf ${TMP_CVS} ${TMP_GIT}
```

### Commit Parallelo CVS + Git

```bash
#!/bin/bash
# dual-commit.sh
# Committa la stessa modifica sia in CVS che in Git

MESSAGE="${1:-Update}"
CVS_PATH="/var/www/oacs-a"
GIT_PATH="/var/www/oacs-a-git"

# CVS commit
cd ${CVS_PATH}
cvs commit -m "${MESSAGE}"

# Sync a Git
rsync -av --exclude='CVS' --exclude='.git' --exclude='log' ${CVS_PATH}/ ${GIT_PATH}/

# Git commit
cd ${GIT_PATH}
git add .
git commit -m "${MESSAGE}" || true
git push origin main

echo "Committed to both CVS and Git: ${MESSAGE}"
```

## Timeline Consigliata

### Settimana 1-2: Preparazione
- [ ] Setup Git in sviluppo (mantenendo CVS)
- [ ] Training team su Git basics
- [ ] Test script di deployment Git
- [ ] Backup completo CVS

### Settimana 3-4: Transizione
- [ ] Usa Git per nuovi sviluppi
- [ ] Sync periodico CVS ↔ Git
- [ ] Deploy misti (a volte CVS, a volte Git)
- [ ] Identifica e risolvi problemi

### Settimana 5: Go-Live Git
- [ ] Ultimo commit CVS
- [ ] Switch completo a Git
- [ ] Deploy solo da Git
- [ ] Monitor intensivo

### Mese 2+: Consolidamento
- [ ] Solo Git in uso
- [ ] CVS in sola lettura (backup)
- [ ] Cleanup e archiviazione CVS

## Troubleshooting Migrazione

### CVS checkout fallisce dopo migrazione

```bash
# Se hai bisogno di tornare a CVS temporaneamente
cd /var/www
mv oacs-a oacs-a.git.backup
cvs checkout -d oacs-a openacs
```

### Merge conflicts durante sync CVS→Git

```bash
cd /var/www/oacs-a-git
git status
# Risolvi manualmente i conflitti
git add .
git commit -m "Resolved CVS sync conflicts"
```

### Team member ancora usa CVS

Continua sync bidirezionale fino a quando tutti sono migrati:

```bash
# Developer A usa CVS
cd /var/www/oacs-a
cvs commit -m "Fix bug"

# Sync to Git (automatico via script)
./cvs-git-sync.sh

# Developer B usa Git
cd /var/www/oacs-a-git
git pull
# ... modifiche ...
git commit -m "New feature"
git push

# Sync to CVS (manuale quando necessario)
rsync -av --exclude='.git' oacs-a-git/ oacs-a/
cd oacs-a
cvs commit -m "Sync from Git: new feature"
```

## Best Practices

1. **Non eliminare CVS troppo presto**
   - Mantieni CVS funzionante per almeno 1 mese dopo lo switch
   - Usalo come backup/fallback

2. **Documenta tutto**
   - Procedure di sync CVS↔Git
   - Cosa fare in caso di problemi
   - Come tornare indietro se necessario

3. **Training graduale**
   - Non forzare switch immediato
   - Permetti periodo di adattamento
   - Supporta chi ha difficoltà

4. **Test intensivo**
   - Deploy da Git in ambiente di test prima
   - Verifica che tutti i tool funzionino
   - Check procedure di rollback

5. **Comunicazione chiara**
   - Annuncia le date di migrazione
   - Spiega perché si fa
   - Fornisci supporto attivo

## Risorse Utili

- **Git Crash Course per CVS users**: https://git-scm.com/course/svn.html
- **cvs2git Documentation**: http://cvs2svn.tigris.org/cvs2git.html
- **Git Cheat Sheet**: https://education.github.com/git-cheat-sheet-education.pdf

---

## Quick Reference: CVS vs Git Commands

| Operazione | CVS | Git |
|------------|-----|-----|
| Clone | `cvs checkout module` | `git clone url` |
| Update | `cvs update` | `git pull` |
| Status | `cvs status` | `git status` |
| Add | `cvs add file` | `git add file` |
| Commit | `cvs commit -m "msg"` | `git commit -m "msg"` + `git push` |
| History | `cvs log file` | `git log file` |
| Diff | `cvs diff file` | `git diff file` |
| Tag | `cvs tag TAG` | `git tag TAG` |
| Branch | `cvs tag -b BRANCH` | `git branch BRANCH` |
| Revert | `cvs update -C file` | `git checkout file` |
