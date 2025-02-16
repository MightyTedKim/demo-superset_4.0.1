#!/bin/bash

# Global Variables
CONTAINER_NAME="superset_app"
BASE_DIR=$(pwd)
LOG_FILE="$BASE_DIR/superset_manage.log"

# Logging Function
log() {
  local LEVEL="$1"
  local MESSAGE="$2"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$LEVEL] $MESSAGE" | tee -a "$LOG_FILE"
}

# Export Dashboards
export_dashboards() {
  local EXPORT_PATH="$BASE_DIR/exported_dashboards.zip"

  log "INFO" "Exporting dashboards to $EXPORT_PATH..."
  docker exec "$CONTAINER_NAME" superset export-dashboards -f /app/exported_dashboards.zip
  if [ $? -eq 0 ]; then
    docker cp "$CONTAINER_NAME:/app/exported_dashboards.zip" "$EXPORT_PATH"
    log "INFO" "Dashboards exported successfully to $EXPORT_PATH."
  else
    log "ERROR" "Failed to export dashboards."
    exit 1
  fi
}

import_dashboards() {
  local DASHBOARD_FILE="$BASE_DIR/exported_dashboards.zip"

  log "INFO" "Importing dashboards from $DASHBOARD_FILE..."

  # Check if the dashboard file exists
  if [ ! -f "$DASHBOARD_FILE" ]; then
    log "ERROR" "Dashboard file $DASHBOARD_FILE not found. Aborting import."
    exit 1
  fi

  # Copy the dashboard ZIP file into the Superset container
  docker cp "$DASHBOARD_FILE" "$CONTAINER_NAME:/app/dashboard_file.zip"
  if [ $? -ne 0 ]; then
    log "ERROR" "Failed to copy dashboard file to the Superset container."
    exit 1
  fi

  # Run the Superset import-dashboards command with --username
  docker exec "$CONTAINER_NAME" superset import-dashboards --path /app/dashboard_file.zip --username admin
  if [ $? -eq 0 ]; then
    log "INFO" "Dashboards imported successfully from $DASHBOARD_FILE."
  else
    log "ERROR" "Failed to import dashboards."
    exit 1
  fi
}


# Import Roles
import_roles() {
  # Use the provided file name or fall back to 'roles_sample.json'
  local ROLES_FILE="${1:-roles_sample.json}"
  local FILE_PATH="$BASE_DIR/$ROLES_FILE"

  log "INFO" "Importing roles from $FILE_PATH..."

  # Check if the roles file exists
  if [ ! -f "$FILE_PATH" ]; then
    log "ERROR" "Roles file $FILE_PATH not found. Aborting import."
    exit 1
  fi

  # Copy the roles file into the Superset container
  docker cp "$FILE_PATH" "$CONTAINER_NAME:/app/$ROLES_FILE"
  if [ $? -ne 0 ]; then
    log "ERROR" "Failed to copy roles file to the Superset container."
    exit 1
  fi

  # Run the Superset import-roles command
  docker exec "$CONTAINER_NAME" superset fab import-roles -p /app/$ROLES_FILE
  if [ $? -eq 0 ]; then
    log "INFO" "Roles imported successfully from $FILE_PATH."
  else
    log "ERROR" "Failed to import roles."
    exit 1
  fi
}


export_roles() {
  # Generate a timestamped file name for the backup
  local DATE=$(date '+%Y-%m-%d_%H-%M-%S')
  local EXPORT_PATH="$BASE_DIR/roles_backup_$DATE.json"

  log "INFO" "Exporting roles to $EXPORT_PATH..."

  # Run the Superset export-roles command with the -path option
  docker exec "$CONTAINER_NAME" superset fab export-roles --path "/app/roles_backup_$DATE.json"

  # Copy the exported file from the container to the host machine
  docker cp "$CONTAINER_NAME:/app/roles_backup_$DATE.json" "$EXPORT_PATH"

  # Check if the file was successfully copied and is not empty
  if [ ! -s "$EXPORT_PATH" ]; then
    log "ERROR" "Exported roles file is empty. Something went wrong during the export process."
    rm -f "$EXPORT_PATH"  # Remove the empty file
    exit 1
  fi

  log "INFO" "Roles exported successfully to $EXPORT_PATH."
}


load_examples() {
  log "INFO" "Checking if Superset example data already exists..."

  # Check if the "World Bank's Data" dashboard exists as an indicator of loaded examples
  if docker exec superset_app superset list-dashboards | grep -q "World Bank's Data"; then
    log "INFO" "Superset examples already exist. Skipping load-examples step."
    return
  fi

  # If examples do not exist, load them
  log "INFO" "Loading Superset example data..."
  docker exec superset_app superset load-examples
  if [ $? -eq 0 ]; then
    log "INFO" "Example data loaded successfully."
  else
    log "ERROR" "Failed to load example data."
    exit 1
  fi
}


# Help Function
show_help() {
  echo "Usage: $0 {export-dashboards|import-dashboards|import-roles|export-roles}"
  echo ""
  echo "Commands:"
  echo "  export-dashboards   Export all dashboards to a ZIP file."
  echo "  import-dashboards   Import dashboards from a ZIP file."
  echo "  import-roles        Import roles from a JSON file."
  echo "  export-roles        Export roles to a JSON file."
  echo "  load-examples        Load Examples"
}

# Main Script Logic
case "$1" in
  import-roles)
    import_roles "$2"
    ;;
  export-roles)
    export_roles
    ;;
  export-dashboards)
    export_dashboards
    ;;
  import-dashboards)
    import_dashboards
    ;;
  *)
    show_help
    ;;
esac

