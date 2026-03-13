#!/bin/bash
# production-deploy-remote.sh
# Deploy completo da sviluppo a produzione su server remoto
# Supporta CVS, Git e rsync

set -e

# Configurazione
INSTANCE=${1:-}
DEPLOY_METHOD=${2:-cvs}
PROD_SERVER=${3:-prod.example.com}
PROD_USER=${4:-root}

# Path locali (sviluppo)
DEV_PATH="/var/www/${INSTANCE}"

# Path remoti (produzione)
PROD_CONTAINER="prod-${INSTANCE}-1"
PROD_PATH="/var/www/openacs"
PROD_COMPOSE_DIR="/var/www/docker-prod"

# CVS
CVSROOT=${CVSROOT:-}

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step() { echo -e "${BLUE}▶${NC} $1"; }

# Help
show_help() {
    cat << EOF
Production Remote Deployment Script

Deploy da server di sviluppo a server di produzione remoto.

Usage: $0 <instance> <method> [prod_server] [prod_user]

Arguments:
  instance      Nome istanza (oacs-a o oacs-b)
  method        Metodo deploy: cvs, git, o rsync
  prod_server   Server produzione (default: prod.example.com)
  prod_user     User SSH (default: root)

Examples:
  $0 oacs-a cvs prod.server.com root
  $0 oacs-b rsync 192.168.1.100 deploy
  $0 oacs-a git prod.server.com root

Prerequisiti:
  - SSH key-based authentication configurato
  - CVS repository accessibile da entrambi i server (per metodo cvs)
  - Git repository accessibile da produzione (per metodo git)

Environment Variables:
  CVSROOT              CVS repository root
  PROD_COMPOSE_DIR     Directory docker-compose in produzione (default: /root/oacs-production)

EOF
    exit 0
}

# Verifica argomenti
if [ "$1" == "help" ] || [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    show_help
fi

if [ -z "$INSTANCE" ]; then
    error "Specificare l'istanza"
fi

# Pre-flight checks
preflight_checks() {
    step "Pre-flight checks..."
    
    # Test connessione SSH
    info "Test connessione SSH a ${PROD_SERVER}..."
    if ! ssh -o ConnectTimeout=5 ${PROD_USER}@${PROD_SERVER} "echo ok" >/dev/null 2>&1; then
        error "Impossibile connettersi a ${PROD_USER}@${PROD_SERVER}"
    fi
    info "✓ Connessione SSH OK"
    
    # Verifica container remoto
    info "Verifica container remoto..."
    if ! ssh ${PROD_USER}@${PROD_SERVER} "docker ps | grep -q ${PROD_CONTAINER}"; then
        error "Container ${PROD_CONTAINER} non in esecuzione su ${PROD_SERVER}"
    fi
    info "✓ Container produzione attivo"
    
    # Check specifici per metodo
    case $DEPLOY_METHOD in
        cvs)
            # Verifica CVS locale
            if [ ! -d "${DEV_PATH}/CVS" ]; then
                error "Directory ${DEV_PATH} non è sotto CVS"
            fi
            info "✓ Repository CVS trovato localmente"
            
            # Ottieni CVSROOT se non settato
            if [ -z "$CVSROOT" ]; then
                CVSROOT=$(cat ${DEV_PATH}/CVS/Root)
            fi
            info "  CVSROOT: ${CVSROOT}"
            ;;
            
        git)
            # Verifica Git remoto
            GIT_EXISTS=$(ssh ${PROD_USER}@${PROD_SERVER} "
                docker exec ${PROD_CONTAINER} sh -c '[ -d ${PROD_PATH}/.git ] && echo yes || echo no'
            ")
            if [ "$GIT_EXISTS" == "no" ]; then
                error "Git non configurato nel container remoto"
            fi
            info "✓ Repository Git configurato in produzione"
            ;;
            
        rsync)
            # Verifica path sviluppo
            if [ ! -d "${DEV_PATH}" ]; then
                error "Directory sviluppo ${DEV_PATH} non trovata"
            fi
            info "✓ Directory sviluppo trovata"
            ;;
    esac
    
    # Verifica spazio disco remoto
    DISK_USAGE=$(ssh ${PROD_USER}@${PROD_SERVER} "
        df -h /var/lib/docker | tail -1 | awk '{print \$5}' | sed 's/%//'
    ")
    if [ $DISK_USAGE -gt 90 ]; then
        error "Spazio disco critico su ${PROD_SERVER}: ${DISK_USAGE}%"
    elif [ $DISK_USAGE -gt 80 ]; then
        warn "Spazio disco al ${DISK_USAGE}% su ${PROD_SERVER}"
    else
        info "✓ Spazio disco OK su produzione (${DISK_USAGE}% usato)"
    fi
}


# Backup remoto
create_backup() {
    step "Creazione backup remoto..."
    
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    BACKUP_DIR="backups"
    BACKUP_FILE="pre-deploy-${INSTANCE}-${TIMESTAMP}.tar.gz"
    
    # Crea directory backup remota
    ssh ${PROD_USER}@${PROD_SERVER} "mkdir -p ${PROD_COMPOSE_DIR}/${BACKUP_DIR}"
    
    # Backup database remoto
    info "Backup database..."
    ssh ${PROD_USER}@${PROD_SERVER} "
        cd ${PROD_COMPOSE_DIR} && \
        docker exec prod-db-1 pg_dump -U postgres -b -Fc -f /backup/${INSTANCE}_$(date \
+%Y%m%d_%H%M%S).dmp ${INSTANCE}
    " || warn "Backup DB non riuscito"
    
    # Backup volume codice remoto
    info "Backup volume codice..."
    ssh ${PROD_USER}@${PROD_SERVER} "
        docker run --rm \
            -v prod_${INSTANCE}_data:/data \
            -v ${PROD_COMPOSE_DIR}/${BACKUP_DIR}:/backup \
            alpine tar czf /backup/${BACKUP_FILE} -C /data . 2>/dev/null
    " || warn "Backup volume non riuscito"
    
    # Salva info backup
    ssh ${PROD_USER}@${PROD_SERVER} "
        echo '${BACKUP_DIR}/${BACKUP_FILE}' > ${PROD_COMPOSE_DIR}/.last-backup
    "
    
    info "✓ Backup salvato: ${PROD_SERVER}:${PROD_COMPOSE_DIR}/${BACKUP_DIR}/${BACKUP_FILE}"
}

# Deploy CVS
deploy_cvs() {
    step "Deploy tramite CVS..."
    
    info "Setup chiavi SSH per CVS..."

    # Copia files
    ssh ${PROD_USER}@${PROD_SERVER} \
        "docker cp ~/.ssh/id_ed25519 ${PROD_CONTAINER}:/tmp/cvs_key && \
         docker cp ~/.ssh/known_hosts ${PROD_CONTAINER}:/tmp/known_hosts"
    
    # Setup nel container
    ssh ${PROD_USER}@${PROD_SERVER} \
        "docker exec ${PROD_CONTAINER} /bin/sh -c 'mkdir -p /home/nsadmin/.ssh && \
         mv /tmp/cvs_key /home/nsadmin/.ssh/id_ed25519 && \
         mv /tmp/known_hosts /home/nsadmin/.ssh/known_hosts && \
         chmod 600 /home/nsadmin/.ssh/id_ed25519 && \
         chmod 644 /home/nsadmin/.ssh/known_hosts && \
         chown -R nsadmin:nsadmin /home/nsadmin/.ssh && \
         chmod 700 /home/nsadmin/.ssh'"
    
    # CVS update
    info "Esecuzione CVS update..."

    ssh ${PROD_USER}@${PROD_SERVER} \
        "docker exec ${PROD_CONTAINER} su nsadmin -c \"cd ${PROD_PATH} && cvs -d ${CVSROOT} -q update -d -P\"" \
        || error "CVS update fallito"    
    
    info "✓ Codice aggiornato da CVS"
}

# Deploy Git
deploy_git() {
    step "Deploy tramite Git..."
       
    info "Esecuzione git pull remoto..."

    ssh ${PROD_USER}@${PROD_SERVER} "
        docker exec -u nsadmin -w ${PROD_PATH} ${PROD_CONTAINER} sh -c '
            git stash && \
            git pull origin main
        '
    " || error "Git pull fallito"
    
    info "✓ Codice aggiornato da Git"
}

# Deploy rsync
deploy_rsync() {
    step "Deploy tramite rsync..."
    
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    
    info "Creazione tarball locale..."
    cd ${DEV_PATH}
    tar czf /tmp/${INSTANCE}-deploy-${TIMESTAMP}.tar.gz \
        --exclude='log/*' \
        --exclude='*.log' \
        --exclude='.git' \
        --exclude='CVS' \
        --exclude='tmp/*' \
        --exclude='*.swp' \
        --exclude='.DS_Store' \
        .
    
    info "Trasferimento a server produzione..."
    scp /tmp/${INSTANCE}-deploy-${TIMESTAMP}.tar.gz ${PROD_USER}@${PROD_SERVER}:/tmp/deploy.tar.gz
    
    info "Estrazione nel container remoto..."
    ssh ${PROD_USER}@${PROD_SERVER} "
        docker cp /tmp/deploy.tar.gz ${PROD_CONTAINER}:/tmp/ && \
        docker exec ${PROD_CONTAINER} sh -c '
            cd ${PROD_PATH} && \
            tar xzf /tmp/deploy.tar.gz && \
            rm /tmp/deploy.tar.gz
        ' && \
        rm /tmp/deploy.tar.gz
    "
    
    # Cleanup locale
    rm /tmp/${INSTANCE}-deploy-${TIMESTAMP}.tar.gz
    
    info "✓ Codice sincronizzato"
}

# Post-deploy
post_deploy() {
    step "Operazioni post-deploy..."
    
    info "Restart container remoto..."
    ssh ${PROD_USER}@${PROD_SERVER} "
        cd ${PROD_COMPOSE_DIR} && \
        docker compose restart ${INSTANCE/-prod/}
    " >/dev/null 2>&1
    
    info "Attesa startup (15 secondi)..."
    sleep 15
    
    info "Health check..."
    HEALTH=$(ssh ${PROD_USER}@${PROD_SERVER} "
        docker exec ${PROD_CONTAINER} curl -sf http://localhost:8080/SYSTEM/success.tcl >/dev/null 2>&1 && echo OK || echo FAIL
    ")
    
    if [ "$HEALTH" == "OK" ]; then
        info "✓ Health check OK"
    else
        error "Health check FAILED! Considera rollback"
    fi
}

# Main
main() {
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    
    echo ""
    echo "========================================="
    echo "  🚀 OpenACS Remote Deployment"
    echo "========================================="
    echo "Sviluppo:   $(hostname)"
    echo "Produzione: ${PROD_SERVER}"
    echo "Istanza:    ${INSTANCE}"
    echo "Metodo:     ${DEPLOY_METHOD}"
    echo "Timestamp:  ${TIMESTAMP}"
    if [ "$DEPLOY_METHOD" == "cvs" ]; then
        echo "CVSROOT:    ${CVSROOT}"
    fi
    echo ""
  
    preflight_checks
    echo ""

    read -p "Procedere con il backup? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        create_backup
        echo ""
    else
        info "Backup annullato"
        echo ""	
    fi
       
    case $DEPLOY_METHOD in
        cvs)
            deploy_cvs
            ;;
        git)
            deploy_git
            ;;
        rsync)
            deploy_rsync
            ;;
        *)
            error "Metodo non supportato: ${DEPLOY_METHOD}"
            ;;
    esac
    echo ""
    
    post_deploy
    echo ""
    
    info "========================================="
    info "  ✅ Deploy remoto completato!"
    info "========================================="
    info ""
    info "Server:  ${PROD_SERVER}"
    info "Metodo:  ${DEPLOY_METHOD}"
    info "Backup:  Disponibile su server produzione"
    echo ""
    info "Comandi utili:"
    echo "  Logs:     ssh ${PROD_USER}@${PROD_SERVER} 'cd ${PROD_COMPOSE_DIR} && docker compose logs -f ${INSTANCE/-prod/}'"
    echo "  Status:   ssh ${PROD_USER}@${PROD_SERVER} 'cd ${PROD_COMPOSE_DIR} && ./manage.sh status'"
    echo "  Rollback: ssh ${PROD_USER}@${PROD_SERVER} 'cd ${PROD_COMPOSE_DIR} && ./manage.sh rollback'"
    echo ""
}

# Execute
main
