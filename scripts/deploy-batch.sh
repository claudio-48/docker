#!/bin/bash
# deploy-batch.sh
# Deploy batch su più clienti contemporaneamente o in sequenza

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
error() { echo -e "${RED}[ERROR]${NC} $1"; }
step() { echo -e "${BLUE}▶${NC} $1"; }

# Help
show_help() {
    cat << EOF
Batch Deployment Script

Deploy su più clienti in sequenza o contemporaneamente.

Usage: $0 <command> [options]

Commands:
  all <instance> <method>       Deploy su tutti i clienti
  clients <list> <instance>     Deploy su clienti specifici
  group <group> <instance>      Deploy su gruppo (definito in config)
  
Options:
  --method METHOD    Metodo deploy (cvs, git, rsync) - default: cvs
  --parallel         Esegui deploy in parallelo (default: sequenziale)
  --continue         Continua anche se un deploy fallisce
  --dry-run          Simula senza eseguire

Examples:
  # Deploy oacs-a su tutti i clienti con CVS
  $0 all oacs-a cvs

  # Deploy su clienti specifici
  $0 clients "acme,globex" oacs-a rsync

  # Deploy parallelo
  $0 all oacs-a git --parallel

  # Dry run per vedere cosa succederà
  $0 all oacs-a cvs --dry-run

EOF
    exit 0
}

# Ottieni lista clienti dal config
get_all_clients() {
    if [ ! -f "$CONFIG_FILE" ]; then
        error "File configurazione non trovato: ${CONFIG_FILE}"
    fi
    
    grep -v '^#' "$CONFIG_FILE" | grep -v '^[[:space:]]*$' | cut -d'|' -f1
}

# Deploy su singolo cliente
deploy_single() {
    local client=$1
    local instance=$2
    local method=$3
    local dry_run=$4
    
    local opts=""
    [ -n "$dry_run" ] && opts="--dry-run"
    
    if [ -f "${SCRIPT_DIR}/deploy-client.sh" ]; then
        "${SCRIPT_DIR}/deploy-client.sh" "$client" "$instance" "$method" $opts --force
        return $?
    else
        error "Script deploy-client.sh non trovato"
    fi
}

# Deploy su tutti i clienti
deploy_all() {
    local instance=$1
    local method=$2
    local parallel=$3
    local continue_on_error=$4
    local dry_run=$5
    
    local clients=$(get_all_clients)
    local total=$(echo "$clients" | wc -l)
    local success=0
    local failed=0
    
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  Batch Deploy - Tutti i Clienti"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "Istanza:   ${instance}"
    echo "Metodo:    ${method}"
    echo "Clienti:   ${total}"
    echo "Parallelo: ${parallel:-No}"
    [ -n "$dry_run" ] && echo "Modalità:  DRY RUN"
    echo ""
    
    if [ -z "$dry_run" ]; then
        read -p "Procedere con il batch deploy? (yes/no): " -r
        if [ "$REPLY" != "yes" ]; then
            info "Batch deploy annullato"
            exit 0
        fi
    fi
    
    echo ""
    step "Inizio batch deploy..."
    echo ""
    
    # Array per tracciare PIDs in modalità parallela
    declare -a pids
    
    for client in $clients; do
        client=$(echo "$client" | xargs) # trim
        
        if [ -n "$parallel" ]; then
            # Deploy parallelo
            info "Avvio deploy per ${client} (background)..."
            deploy_single "$client" "$instance" "$method" "$dry_run" &
            pids+=($!)
        else
            # Deploy sequenziale
            step "Deploy su ${client}..."
            
            if deploy_single "$client" "$instance" "$method" "$dry_run"; then
                info "✓ Deploy ${client} completato con successo"
                ((success++))
            else
                warn "✗ Deploy ${client} FALLITO"
                ((failed++))
                
                if [ -z "$continue_on_error" ]; then
                    error "Batch deploy interrotto dopo errore su ${client}"
                fi
            fi
            
            echo ""
        fi
    done
    
    # Se parallelo, attendi completamento
    if [ -n "$parallel" ]; then
        info "Attesa completamento deploy paralleli..."
        
        for pid in "${pids[@]}"; do
            if wait "$pid"; then
                ((success++))
            else
                ((failed++))
            fi
        done
    fi
    
    # Riepilogo
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  Riepilogo Batch Deploy"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "Totale clienti:  ${total}"
    echo "Successi:        ${success}"
    echo "Falliti:         ${failed}"
    echo ""
    
    if [ $failed -gt 0 ]; then
        warn "Alcuni deploy sono falliti. Controlla i log."
        exit 1
    else
        info "Tutti i deploy completati con successo!"
    fi
}

# Deploy su lista clienti
deploy_clients() {
    local client_list=$1
    local instance=$2
    local method=$3
    local parallel=$4
    local continue_on_error=$5
    local dry_run=$6
    
    IFS=',' read -ra CLIENTS <<< "$client_list"
    
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  Batch Deploy - Clienti Selezionati"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "Istanza:   ${instance}"
    echo "Metodo:    ${method}"
    echo "Clienti:   ${client_list}"
    echo ""
    
    for client in "${CLIENTS[@]}"; do
        client=$(echo "$client" | xargs)
        
        step "Deploy su ${client}..."
        
        if deploy_single "$client" "$instance" "$method" "$dry_run"; then
            info "✓ Deploy ${client} completato"
        else
            warn "✗ Deploy ${client} FALLITO"
            
            if [ -z "$continue_on_error" ]; then
                error "Batch deploy interrotto"
            fi
        fi
        
        echo ""
    done
}

# Parse arguments
COMMAND=${1:-help}

case "$COMMAND" in
    help|-h|--help)
        show_help
        ;;
    all)
        INSTANCE=$2
        METHOD=${3:-cvs}
        PARALLEL=""
        CONTINUE=""
        DRY_RUN=""
        
        shift 3 2>/dev/null || true
        
        while [ $# -gt 0 ]; do
            case "$1" in
                --parallel) PARALLEL="yes" ;;
                --continue) CONTINUE="yes" ;;
                --dry-run) DRY_RUN="yes" ;;
                --method) METHOD=$2; shift ;;
            esac
            shift
        done
        
        if [ -z "$INSTANCE" ]; then
            error "Specificare istanza"
        fi
        
        deploy_all "$INSTANCE" "$METHOD" "$PARALLEL" "$CONTINUE" "$DRY_RUN"
        ;;
    clients)
        CLIENT_LIST=$2
        INSTANCE=$3
        METHOD=${4:-cvs}
        PARALLEL=""
        CONTINUE=""
        DRY_RUN=""
        
        shift 4 2>/dev/null || true
        
        while [ $# -gt 0 ]; do
            case "$1" in
                --parallel) PARALLEL="yes" ;;
                --continue) CONTINUE="yes" ;;
                --dry-run) DRY_RUN="yes" ;;
                --method) METHOD=$2; shift ;;
            esac
            shift
        done
        
        if [ -z "$CLIENT_LIST" ] || [ -z "$INSTANCE" ]; then
            error "Specificare lista clienti e istanza"
        fi
        
        deploy_clients "$CLIENT_LIST" "$INSTANCE" "$METHOD" "$PARALLEL" "$CONTINUE" "$DRY_RUN"
        ;;
    *)
        error "Comando sconosciuto: $COMMAND. Usa 'help' per aiuto"
        ;;
esac
