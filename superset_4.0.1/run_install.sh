#!/bin/bash

# Define global variables
BASE_DIR=$(cd "$(dirname "$0")" && pwd)
TARGET_DIR="$BASE_DIR/superset"
REPO_URL="https://github.com/apache/superset.git"
BRANCH_NAME="4.0.1"
SUPERSET_ADMIN_PASSWORD="sample"
LOG_FILE="$BASE_DIR/superset_setup.log"

# Logging function
log() {
  local LEVEL="$1"
  local MESSAGE="$2"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$LEVEL] $MESSAGE" | tee -a "$LOG_FILE"
}

##################################
# Clone Repository
##################################
# Clone the repository and checkout the branch in one command
clone_and_checkout_branch() {
  log "INFO" "Cloning repository and checking out branch $BRANCH_NAME..."

  # If the directory already exists, skip the cloning process
  if [ -d "$BASE_DIR/superset" ]; then
    log "INFO" "Directory $BASE_DIR/superset already exists. Skipping clone."
    return 0
  fi

  # Clone the repository with the specified branch
  git clone --depth 1 --branch "$BRANCH_NAME" "$REPO_URL" "$BASE_DIR/superset"
  if [ $? -eq 0 ]; then
    log "INFO" "Repository cloned and branch $BRANCH_NAME checked out successfully."
  else
    log "ERROR" "Failed to clone repository or checkout branch $BRANCH_NAME."
    exit 1
  fi
}

###################################
# Configurations
###################################
create_requirements_file() {
  FILE_PATH="$BASE_DIR/superset/docker/requirements-local.txt"
  log "INFO" "Creating requirements-local.txt at $FILE_PATH..."
  mkdir -p "$(dirname "$FILE_PATH")"
  cat > "$FILE_PATH" <<EOL
trino==0.330.0
prophet==1.1.6
EOL
  if [ -f "$FILE_PATH" ]; then
    log "INFO" "requirements-local.txt successfully created."
  else
    log "ERROR" "Failed to create requirements-local.txt."
    exit 1
  fi
}

change_exposed_port() {
  COMPOSE_FILE="$BASE_DIR/superset/docker-compose-non-dev.yml"
  OLD_PORT="8088"
  NEW_PORT="30001"
  log "INFO" "Changing exposed port from $OLD_PORT to $NEW_PORT in $COMPOSE_FILE..."

  if [ ! -f "$COMPOSE_FILE" ]; then
    log "ERROR" "$COMPOSE_FILE not found."
    exit 1
  fi

  sed -i "s/\b$OLD_PORT:$OLD_PORT\b/$NEW_PORT:$OLD_PORT/" "$COMPOSE_FILE"
  if grep -q "$NEW_PORT:$OLD_PORT" "$COMPOSE_FILE"; then
    log "INFO" "Port mapping successfully updated to $NEW_PORT."
  else
    log "ERROR" "Failed to update port mapping."
    exit 1
  fi
}

create_superset_config() {
  FILE_PATH="$BASE_DIR/superset/docker/pythonpath_dev/superset_config_docker.py"
  log "INFO" "Creating superset_config_docker.py at $FILE_PATH..."
  mkdir -p "$(dirname "$FILE_PATH")"
  cat > "$FILE_PATH" <<EOL
print('Loaded superset_config_docker.py')
# Limits and timeouts
ROW_LIMIT = 5000
SUPERSET_WEBSERVER_TIMEOUT = 300

# Feature flags
FEATURE_FLAGS = {
    "ENABLE_TEMPLATE_PROCESSING": True,
    "ENABLE_TEMPLATE_REMOVE_FILTERS": True,
    "DASHBOARD_RBAC": True,
}

# Landing page customization
from flask import redirect, g
from flask_appbuilder import expose, IndexView
from superset.utils.core import get_user_id

class SupersetIndexView(IndexView):
    @expose("/")
    def index(self):
        if not g.user or not get_user_id():
            return redirect("/login")
        return redirect("/dashboard/list")

FAB_INDEX_VIEW = f"{SupersetIndexView.__module__}.{SupersetIndexView.__name__}"

# Theme overrides
THEME_OVERRIDES = {
  "borderRadius": 16,
   "colors": {
     "primary": {
       "base": '#804479',
     },
     "secondary": {
       "base": 'green',
     },
     "grayscale": {
       "base": '#e46268',
     }
   }
}

##LOGO
APP_NAME = 'TEST_DEMO'
APP_ICON = '/static/assets/images/custom.png'
APP_ICON_WIDTH = 200
LOGO_TARGET_PATH = '/'
LOGO_TOOLTIP = 'TEST DEMO'
EOL
  if [ -f "$FILE_PATH" ]; then
    log "INFO" "superset_config_docker.py successfully created."
  else
    log "ERROR" "Failed to create superset_config_docker.py."
    exit 1
  fi
}

###################################
# Add Custom Logo to Docker Compose
###################################
add_custom_logo_to_docker_compose() {
  local COMPOSE_FILE="$BASE_DIR/superset/docker-compose-non-dev.yml"
  local LOGO_URL="https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTZSkOvE4B2wu6tqwvpv4rLxMKKu8nR2CXb_Q&s"
  local LOCAL_LOGO="$BASE_DIR/custom.png"
  local TARGET_LOGO_PATH="/app/superset/static/assets/images/custom.png"
  local CONTAINER_NAME="superset_app"

  log "INFO" "Adding custom logo to Docker Compose configuration at $COMPOSE_FILE..."

  # Check if the Docker Compose file exists
  if [ ! -f "$COMPOSE_FILE" ]; then
    log "ERROR" "Docker Compose file not found: $COMPOSE_FILE"
    exit 1
  fi

  # Download the custom logo if it doesn't exist locally
  if [ ! -f "$LOCAL_LOGO" ]; then
    log "INFO" "Downloading custom logo to $LOCAL_LOGO..."
    if curl -o "$LOCAL_LOGO" "$LOGO_URL"; then
      log "INFO" "Custom logo downloaded successfully to $LOCAL_LOGO"
    else
      log "ERROR" "Failed to download custom logo. Check URL or network connectivity."
      exit 1
    fi
  else
    log "INFO" "Custom logo already exists at $LOCAL_LOGO. Skipping download."
  fi

  # Add volume mapping to the Docker Compose file
  if grep -q "$LOCAL_LOGO:$TARGET_LOGO_PATH" "$COMPOSE_FILE"; then
    log "INFO" "Custom logo path already exists in Docker Compose configuration. Skipping addition."
  else
    log "INFO" "Adding custom logo path to Docker Compose configuration..."
    sed -i "25i \  - $LOCAL_LOGO:$TARGET_LOGO_PATH" "$COMPOSE_FILE"
    log "INFO" "Custom logo path added to Docker Compose configuration."
  fi
}

###################################
# Fix Ownership and Permissions
###################################
fix_static_file_permissions() {
  local CONTAINER_NAME="superset_app"
  local IMAGE_PATH="/app/superset/static/assets/images/custom.png"

  log "INFO" "Fixing ownership and permissions for $IMAGE_PATH in container $CONTAINER_NAME..."

  # Ensure the Docker container is running
  if ! docker ps | grep -q "$CONTAINER_NAME"; then
    log "ERROR" "Container $CONTAINER_NAME is not running. Please start Superset first."
    exit 1
  fi

  # Change ownership to superset:superset
  docker exec "$CONTAINER_NAME" chown -R superset:superset "$IMAGE_PATH"
  if [ $? -eq 0 ]; then
    log "INFO" "Ownership of $IMAGE_PATH fixed."
  else
    log "ERROR" "Failed to fix ownership for $IMAGE_PATH."
    exit 1
  fi

  # Set permissions to 755
  docker exec "$CONTAINER_NAME" chmod -R 644 "$IMAGE_PATH"
  if [ $? -eq 0 ]; then
    log "INFO" "Permissions of $IMAGE_PATH fixed."
  else
    log "ERROR" "Failed to fix permissions for $IMAGE_PATH."
    exit 1
  fi
}


# Reset admin password
reset_admin_password() {
  log "INFO" "Resetting Superset admin password..."
  docker exec superset_app superset fab reset-password --username admin --password "$SUPERSET_ADMIN_PASSWORD"
  if [ $? -eq 0 ]; then
    log "INFO" "Admin password reset successfully to '$SUPERSET_ADMIN_PASSWORD'."
  else
    log "ERROR" "Failed to reset admin password."
    exit 1
  fi
}

# Start Superset with optional example dashboard loading
start_superset() {
  log "INFO" "Starting Apache Superset with Docker Compose and TAG=$BRANCH_NAME..."
  TAG="$BRANCH_NAME" docker compose -f "$BASE_DIR/superset/docker-compose-non-dev.yml" up -d
  if [ $? -eq 0 ]; then
    log "INFO" "Apache Superset is starting with version $BRANCH_NAME."
    reset_admin_password
  else
    log "ERROR" "Failed to start Apache Superset."
    exit 1
  fi
}

print_summary() {
  echo "----------------------------------"
  echo "           SCRIPT SUMMARY         "
  echo "----------------------------------"
  echo "Base Directory: $BASE_DIR"
  echo "Target Directory: $TARGET_DIR"
  echo "Branch Name: $BRANCH_NAME"
  echo "Superset Admin Password: $SUPERSET_ADMIN_PASSWORD"
  echo "Exposed Port: $(grep -oE '30001:8088' "$BASE_DIR/superset/docker-compose-non-dev.yml")"
  echo "Requirements File: $BASE_DIR/superset/docker/pythonpath_dev/requirements-local.txt"
  echo "Config File: $BASE_DIR/superset/docker/pythonpath_dev/superset_config_docker.py"

  # Docker Containers
  echo "Running Containers:"
  docker ps --filter "ancestor=apache/superset:$BRANCH_NAME" --format "table {{.ID}}\t{{.Image}}\t{{.Status}}"

  # Docker Volumes
  echo "Docker Volumes in Use:"
  docker volume ls --filter "dangling=false"

  echo "----------------------------------"
}

###################################
# Handle Script Arguments
###################################
case "$1" in
  start)
    log "INFO" "Starting Apache Superset setup..."
    log "INFO" "Base directory: $BASE_DIR"
    clone_and_checkout_branch
    log "INFO" "Customizing repository..."
    create_requirements_file
    change_exposed_port
    create_superset_config
    add_custom_logo_to_docker_compose
    log "INFO" "Start superset"
    start_superset
    fix_static_file_permissions
    print_summary
    ;;
  stop)
    log "INFO" "Stopping Apache Superset..."
    docker compose -f "$BASE_DIR/superset/docker-compose-non-dev.yml" down
    log "INFO" "Apache Superset has been stopped."
    ;;
  restart)
    log "INFO" "Restarting Apache Superset..."
    bash "$0" stop
    bash "$0" start "$2"
    ;;
  status)
    log "INFO" "Checking Apache Superset status..."
    print_summary
    ;;
  *)
    log "Usage: $0|{start|stop|restart|status}"
    exit 1
    ;;
esac

exit 0

