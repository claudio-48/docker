#!/bin/bash

set -e

DB_USER="postgres"

# imposto array di database da creare/importare
#dbn=("oacs-a" "oacs-b" "alter-dev")
dbn=("alter-dev")

for db in "${dbn[@]}"; do
  echo "Elaboro $db"

    # Variabili configurabili
    DB_NAME="$db"
    DUMP_FILE="/backup/${DB_NAME}.dmp"

    echo "Checking if database '$DB_NAME' exists..."

    # Controlla se il database esiste già
    if PGPASSWORD="$POSTGRES_PASSWORD" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1" >/dev/null 2>&1; then
        echo "Database '$DB_NAME' already exists. Skipping import."
    else

        echo "Database '$DB_NAME' not found. Creating and importing..."

        # Crea il database
        createdb -U "$DB_USER" -T "template0" "$DB_NAME"

        # Importa il dump se esiste
        if [ -f "$DUMP_FILE" ]; then
            echo "Importing database dump from $DUMP_FILE..."
    
            echo "Detected binary/custom PostgreSQL dump"
            pg_restore -U "$DB_USER" -d "$DB_NAME" -O -Fc "$DUMP_FILE" && \
            echo "'$DB_NAME' import completed successfully!"
    
            # Controllo errori
            if [ $? -ne 0 ]; then
                echo "ERROR: Import failed!" >&2
                exit 1
            fi
    
        else
            echo "WARNING: Dump file $DUMP_FILE not found. Database '$DB_NAME' created empty."
        fi
	
    fi

done

echo "Database setup completed!"
