#!/bin/bash
# =============================================================================
# OpenACS Production Management Script
# =============================================================================
# Gestisce deployment, backup e operazioni comuni in produzione
# =============================================================================

set -e

COMPOSE_FILE="docker-compose.yml"
PROJECT_NAME="prod"

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Funzioni helper
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verifica prerequisiti
check_prerequisites() {
    info "Verifico prerequisiti..."
    
    if [ ! -f ".env" ]; then
        error "File .env non trovato!"
        exit 1
    fi
    
    if [ ! -f "secrets/psql_password" ]; then
        error "File secrets/psql_password non trovato!"
        exit 1
    fi
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        error "File $COMPOSE_FILE non trovato!"
        exit 1
    fi
    
      info "Prerequisiti OK"
}

# Deploy iniziale
deploy_initial() {
    info "Deploy iniziale ambiente produzione..."
    check_prerequisites
    
    warn "Questo creerà tutti i container e i volumi. Continuare? (y/n)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        info "Deploy annullato"
        exit 0
    fi
    
    info "Creazione network e volumi..."
    docker compose -p "$PROJECT_NAME" up -d db
    
    info "Attendo che il database sia pronto..."
    sleep 20
    
    info "Avvio container oacs-a e alter-dev"
    docker compose -p "$PROJECT_NAME" up -d oacs-a alter-dev
    
    info "Attendo che le istanze OpenACS siano pronte..."
    sleep 90
    
    info "Avvio servizi restanti..."
    docker compose -p "$PROJECT_NAME" up -d
    sleep 30
    
    info "Deploy completato! Verifica lo stato con: $0 status"
}

# Start/Stop/Restart
start_services() {
    info "Avvio servizi..."
    docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" start
}

stop_services() {
    info "Arresto servizi..."
    docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" stop
}

restart_services() {
    info "Restart servizi..."
    docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" restart
}

# Status
show_status() {
    info "Status servizi:"
    docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps
}

# Logs
show_logs() {
    local service=$1
    if [ -z "$service" ]; then
        docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" logs -f --tail=100
    else
        docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" logs -f --tail=100 "$service"
    fi
}

# Backup database
backup_database() {
    local backup_dir="./backups"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${backup_dir}/db_backup_${timestamp}.sql.gz"
    
    info "Creazione backup database..."
    
    mkdir -p "$backup_dir"
    
    # Backup di tutte le istanze
    docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" exec -T db \
        pg_dumpall -U postgres | gzip > "$backup_file"
    
    info "Backup salvato in: $backup_file"
    
    # Mantieni solo gli ultimi 7 backup
    info "Pulizia backup vecchi (mantengo ultimi 7)..."
    ls -t ${backup_dir}/db_backup_*.sql.gz | tail -n +8 | xargs -r rm
}

# Restore database
restore_database() {
    local backup_file=$1
    
    if [ -z "$backup_file" ]; then
        error "Specificare il file di backup: $0 restore-db /path/to/backup.sql.gz"
        exit 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        error "File backup non trovato: $backup_file"
        exit 1
    fi
    
    warn "ATTENZIONE: Questo sovrascriverà il database corrente!"
    warn "Continuare? (yes/no)"
    read -r response
    if [ "$response" != "yes" ]; then
        info "Restore annullato"
        exit 0
    fi
    
    info "Arresto container OpenACS..."
    docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" stop oacs-a oacs-b alter-dev
    
    info "Restore database..."
    gunzip -c "$backup_file" | docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" \
        exec -T db psql -U postgres
    
    info "Riavvio container OpenACS..."
    docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" start oacs-a oacs-b alter-dev
    
    info "Restore completato"
}

# Backup volumi OpenACS
backup_volumes() {
    local backup_dir="./backups/volumes"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    mkdir -p "$backup_dir"
    
    info "Backup volume oacs-a_data..."
    docker run --rm \
        -v ${PROJECT_NAME}_oacs-a_data:/data \
        -v $(pwd)/${backup_dir}:/backup \
        alpine tar czf /backup/oacs-a_data_${timestamp}.tar.gz -C /data .

    info "Backup volume oacs-b_data..."
    docker run --rm \
        -v ${PROJECT_NAME}_oacs-b_data:/data \
        -v $(pwd)/${backup_dir}:/backup \
        alpine tar czf /backup/oacs-b_data_${timestamp}.tar.gz -C /data .
    
    info "Backup volume alter-dev_data..."
    docker run --rm \
        -v ${PROJECT_NAME}_alter-dev_data:/data \
        -v $(pwd)/${backup_dir}:/backup \
        alpine tar czf /backup/alter-dev_data_${timestamp}.tar.gz -C /data .
    
    info "Backup volumi completato in: $backup_dir"
}

# Update
update_services() {
    info "Update immagini Docker..."
    docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" pull
    
    warn "Vuoi riavviare i servizi con le nuove immagini? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        info "Riavvio con nuove immagini..."
        docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d
    fi
}

# Cleanup
cleanup() {
    info "Pulizia risorse inutilizzate..."
    docker system prune -f
    info "Cleanup completato"
}

# Shell access
shell_access() {
    local service=$1
    if [ -z "$service" ]; then
        error "Specificare il servizio: $0 shell [oacs-a|alter-dev|db|mailrelay|nginx]"
        exit 1
    fi
    
    info "Accesso shell a $service..."
    docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" exec "$service" /bin/sh
}

# Menu principale
show_help() {
    cat << EOF
OpenACS Production Management Script

Usage: $0 [comando]

Comandi disponibili:

  deploy          Deploy iniziale (prima installazione)
  start           Avvia tutti i servizi
  stop            Arresta tutti i servizi
  restart         Riavvia tutti i servizi
  status          Mostra stato dei servizi
  logs [service]  Mostra logs (opzionale: specifica servizio)
  
  backup-db       Backup del database PostgreSQL
  backup-volumes  Backup dei volumi OpenACS (codice)
  restore-db FILE Restore database da backup
  
  update          Aggiorna immagini Docker
  cleanup         Pulizia risorse Docker inutilizzate
  shell SERVICE   Accesso shell al container
  
  help            Mostra questo messaggio

Esempi:
  $0 deploy
  $0 logs openacs-a
  $0 backup-db
  $0 restore-db ./backups/db_backup_20250131_120000.sql.gz
  $0 shell alter-dev

EOF
}

# Main
case "${1:-help}" in
    deploy)
        deploy_initial
        ;;
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs "$2"
        ;;
    backup-db)
        backup_database
        ;;
    backup-volumes)
        backup_volumes
        ;;
    restore-db)
        restore_database "$2"
        ;;
    update)
        update_services
        ;;
    cleanup)
        cleanup
        ;;
    shell)
        shell_access "$2"
        ;;
    help|*)
        show_help
        ;;
esac
