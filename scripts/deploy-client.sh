#!/bin/bash
# deploy-client.sh
# Deploy multi-cliente con configurazione centralizzata

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/deployment-clients.conf"

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step() { echo -e "${BLUE}▶${NC} $1"; }
client_info() { echo -e "${CYAN}[CLIENT]${NC} $1"; }

# Help
show_help() {
    cat << EOF
Multi-Client Deployment Script

Deploy su server di produzione di diversi clienti usando configurazione centralizzata.

Usage: $0 <client> <instance> <method> [options]

Arguments:
  client      ID cliente (da deployment-clients.conf)
  instance    Istanza da deployare (oacs-a, oacs-b, etc.)
  method      Metodo deploy: cvs, git, o rsync

Options:
  --dry-run   Mostra cosa verrebbe fatto senza eseguire
  --force     Salta conferme interattive

Commands:
  list                Lista tutti i clienti configurati
  show <client>       Mostra configurazione cliente
  test <client>       Test connessione cliente
  instances <client>  Lista istanze disponibili per cliente

Examples:
  $0 list
  $0 show acme
  $0 test acme
  $0 acme oacs-a cvs
  $0 globex oacs-a rsync --dry-run
  $0 techcorp oacs-b git --force

Configuration File: ${CONFIG_FILE}

EOF
    exit 0
}

# Carica configurazione cliente
load_client_config() {
    local client_id=$1
    
    if [ ! -f "$CONFIG_FILE" ]; then
        error "File configurazione non trovato: ${CONFIG_FILE}"
    fi
    
    # Cerca cliente nel file config
    local config_line=$(grep "^${client_id}|" "$CONFIG_FILE" | head -1)
    
    if [ -z "$config_line" ]; then
        error "Cliente '${client_id}' non trovato in ${CONFIG_FILE}"
    fi
    
    # Parse configurazione
    IFS='|' read -r CLIENT_ID PROD_SERVER PROD_USER COMPOSE_DIR CVSROOT INSTANCES <<< "$config_line"
    
    # Export variabili
    export CLIENT_ID
    export PROD_SERVER
    export PROD_USER
    export COMPOSE_DIR
    export CVSROOT
    export INSTANCES
    
    client_info "Cliente: ${CLIENT_ID}"
    client_info "Server: ${PROD_SERVER}"
    client_info "User: ${PROD_USER}"
    client_info "Path: ${COMPOSE_DIR}"
    [ -n "$CVSROOT" ] && client_info "CVS: ${CVSROOT}" || client_info "CVS: Non configurato"
}

# Lista tutti i clienti
list_clients() {
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  Clienti Configurati"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    
    if [ ! -f "$CONFIG_FILE" ]; then
        error "File configurazione non trovato: ${CONFIG_FILE}"
    fi
    
    printf "%-15s %-30s %-10s %-20s\n" "CLIENT" "SERVER" "USER" "INSTANCES"
    echo "────────────────────────────────────────────────────────────────"
    
    while IFS='|' read -r client_id server user dir cvs instances; do
        # Salta commenti e linee vuote
        [[ "$client_id" =~ ^#.*$ ]] && continue
        [ -z "$client_id" ] && continue
        
        printf "%-15s %-30s %-10s %-20s\n" "$client_id" "$server" "$user" "$instances"
    done < "$CONFIG_FILE"
    
    echo ""
}

# Mostra dettagli cliente
show_client() {
    local client_id=$1
    
    if [ -z "$client_id" ]; then
        error "Specificare ID cliente"
    fi
    
    load_client_config "$client_id"
    
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  Configurazione Cliente: ${CLIENT_ID}"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "Server Produzione:    ${PROD_SERVER}"
    echo "User SSH:             ${PROD_USER}"
    echo "Directory Compose:    ${COMPOSE_DIR}"
    echo "CVS Root:             ${CVSROOT:-Non configurato}"
    echo "Istanze Disponibili:  ${INSTANCES}"
    echo ""
    echo "Comando SSH:"
    echo "  ssh ${PROD_USER}@${PROD_SERVER}"
    echo ""
}

# Test connessione cliente
test_client() {
    local client_id=$1
    
    if [ -z "$client_id" ]; then
        error "Specificare ID cliente"
    fi
    
    load_client_config "$client_id"
    
    echo ""
    step "Test connessione a ${CLIENT_ID}..."
    
    # Test SSH
    if ssh -o ConnectTimeout=5 ${PROD_USER}@${PROD_SERVER} "echo 'SSH OK'" >/dev/null 2>&1; then
        info "✓ SSH connessione OK"
    else
        error "✗ SSH connessione FALLITA"
    fi
    
    # Test Docker
    if ssh ${PROD_USER}@${PROD_SERVER} "docker ps >/dev/null 2>&1" 2>/dev/null; then
        info "✓ Docker accessibile"
    else
        warn "✗ Docker non accessibile (permessi?)"
    fi
    
    # Test directory compose
    if ssh ${PROD_USER}@${PROD_SERVER} "[ -d ${COMPOSE_DIR} ]" 2>/dev/null; then
        info "✓ Directory compose trovata: ${COMPOSE_DIR}"
    else
        warn "✗ Directory compose non trovata: ${COMPOSE_DIR}"
    fi
    
    # Test container per ogni istanza
    IFS=',' read -ra INSTANCE_ARRAY <<< "$INSTANCES"
    for instance in "${INSTANCE_ARRAY[@]}"; do
        instance=$(echo "$instance" | xargs) # trim whitespace
	# ho deciso di eseguire i comandi con il flag -p 'docker compose -p prod' e come
	# conseguenza il nome del container viene prefissato da 'prod' e seguito da un
	# numero univoco sequenziale
        if ssh ${PROD_USER}@${PROD_SERVER} "docker ps | grep -q prod-${instance}-1" 2>/dev/null; then
            info "✓ Container prod-${instance}-1 in esecuzione"
        else
            warn "✗ Container prod-${instance}-1 non trovato"
        fi
    done
    
    echo ""
    info "Test completato per cliente: ${CLIENT_ID}"
    echo ""
}

# Lista istanze cliente
list_instances() {
    local client_id=$1
    
    if [ -z "$client_id" ]; then
        error "Specificare ID cliente"
    fi
    
    load_client_config "$client_id"
    
    echo ""
    echo "Istanze disponibili per ${CLIENT_ID}:"
    echo ""
    
    IFS=',' read -ra INSTANCE_ARRAY <<< "$INSTANCES"
    for instance in "${INSTANCE_ARRAY[@]}"; do
        instance=$(echo "$instance" | xargs)
        echo "  - ${instance}"
    done
    echo ""
}

# Deploy function
deploy() {
    local client_id=$1
    local instance=$2
    local method=$3
    local dry_run=$4
    local force=$5
    
    # Carica config cliente
    load_client_config "$client_id"
    
    # Verifica che istanza sia valida per questo cliente
    if [[ ! ",${INSTANCES}," =~ ",${instance}," ]]; then
        error "Istanza '${instance}' non configurata per cliente '${CLIENT_ID}'. Istanze disponibili: ${INSTANCES}"
    fi
    
    # Verifica CVS se metodo è cvs
    if [ "$method" == "cvs" ] && [ -z "$CVSROOT" ]; then
        error "Metodo CVS richiesto ma CVSROOT non configurato per cliente '${CLIENT_ID}'"
    fi
    
    # Path locali
    DEV_PATH="/var/www/${instance}"
    PROD_CONTAINER="prod-${instance}-1"
    PROD_PATH="/var/www/openacs"
    
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  Deploy Multi-Cliente"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "Cliente:    ${CLIENT_ID}"
    echo "Server:     ${PROD_SERVER}"
    echo "Istanza:    ${instance}"
    echo "Metodo:     ${method}"
    [ -n "$dry_run" ] && echo "Modalità:   DRY RUN (simulazione)"
    echo ""
    
    if [ -z "$force" ] && [ -z "$dry_run" ]; then
        read -p "Procedere con il deploy? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Deploy annullato"
            exit 0
        fi
    fi
    
    if [ -n "$dry_run" ]; then
        info "DRY RUN - Mostrando operazioni senza eseguirle"
        echo ""
        echo "Operazioni che verrebbero eseguite:"
        echo "  1. Test connessione SSH a ${PROD_USER}@${PROD_SERVER}"
        echo "  2. Verifica container ${PROD_CONTAINER}"
        echo "  3. Backup su ${PROD_SERVER}:${COMPOSE_DIR}/backups"
        echo "  4. Deploy con metodo: ${method}"
        echo "  5. Restart container"
        echo "  6. Health check"
        echo ""
        info "Usa senza --dry-run per eseguire realmente"
        exit 0
    fi
    
    # Esegui deploy reale chiamando lo script esistente
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    
    step "Esecuzione deploy..."
    
    # Usa production-deploy-remote.sh se esiste
    if [ -f "${SCRIPT_DIR}/production-deploy-remote.sh" ]; then
        # Imposta variabili d'ambiente per lo script
        export PROD_COMPOSE_DIR="${COMPOSE_DIR}"
        
        "${SCRIPT_DIR}/production-deploy-remote.sh" \
            "${instance}" \
            "${method}" \
            "${PROD_SERVER}" \
            "${PROD_USER}"
    else
        error "Script production-deploy-remote.sh non trovato in ${SCRIPT_DIR}"
    fi
}

# Parse arguments
COMMAND=${1:-help}

case "$COMMAND" in
    list)
        list_clients
        ;;
    show)
        show_client "$2"
        ;;
    test)
        test_client "$2"
        ;;
    instances)
        list_instances "$2"
        ;;
    help|-h|--help)
        show_help
        ;;
    *)
        # Deploy command
        CLIENT_ID=$1
        INSTANCE=$2
        METHOD=${3:-cvs}
        
        # Parse options
        DRY_RUN=""
        FORCE=""
        shift 3 2>/dev/null || true
        
        while [ $# -gt 0 ]; do
            case "$1" in
                --dry-run)
                    DRY_RUN="yes"
                    ;;
                --force)
                    FORCE="yes"
                    ;;
                *)
                    warn "Opzione sconosciuta: $1"
                    ;;
            esac
            shift
        done
        
        if [ -z "$CLIENT_ID" ] || [ -z "$INSTANCE" ]; then
            error "Specificare client e instance. Usa '$0 help' per aiuto"
        fi
        
        deploy "$CLIENT_ID" "$INSTANCE" "$METHOD" "$DRY_RUN" "$FORCE"
        ;;
esac
