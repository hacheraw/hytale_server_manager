#!/bin/bash
#
# Hytale Server Manager - Linux Update Script
#
# This script checks for and applies updates to the Hytale Server Manager.
#
# Usage: sudo ./update.sh [OPTIONS]
#
# Options:
#   -p, --path PATH      Installation path (default: /opt/hytale-manager)
#   -c, --check          Only check for updates without installing
#   -f, --force          Force update even if on latest version
#   -h, --help           Show this help message
#

set -e

# Default values
INSTALL_PATH="/opt/hytale-manager"
SERVICE_NAME="hytale-manager"
CHECK_ONLY=false
FORCE=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Functions
print_status() { echo -e "${CYAN}[*]${NC} $1"; }
print_success() { echo -e "${GREEN}[+]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[-]${NC} $1"; }

show_help() {
    echo "Hytale Server Manager - Linux Update Script"
    echo ""
    echo "Usage: sudo $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p, --path PATH      Installation path (default: /opt/hytale-manager)"
    echo "  -c, --check          Only check for updates without installing"
    echo "  -f, --force          Force update even if on latest version"
    echo "  -h, --help           Show this help message"
    echo ""
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--path)
            INSTALL_PATH="$2"
            shift 2
            ;;
        -c|--check)
            CHECK_ONLY=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            ;;
    esac
done

echo ""
echo -e "${CYAN}======================================${NC}"
echo -e "${CYAN}  Hytale Server Manager Updater${NC}"
echo -e "${CYAN}======================================${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root (sudo)"
    exit 1
fi

# Verify installation exists
if [[ ! -f "$INSTALL_PATH/package.json" ]]; then
    print_error "Installation not found at: $INSTALL_PATH"
    echo "Please specify the correct path with -p or --path"
    exit 1
fi

# Get current version
print_status "Checking current version..."
CURRENT_VERSION=$(grep '"version"' "$INSTALL_PATH/package.json" | head -1 | sed 's/.*"version": "\([^"]*\)".*/\1/')
echo "Current version: $CURRENT_VERSION"

# Read config to get GitHub repo
GITHUB_REPO="yourusername/hytale-server-manager"
if [[ -f "$INSTALL_PATH/config.json" ]] && command -v jq &> /dev/null; then
    REPO=$(jq -r '.updates.githubRepo // empty' "$INSTALL_PATH/config.json")
    if [[ -n "$REPO" ]]; then
        GITHUB_REPO="$REPO"
    fi
fi

# Check for updates
print_status "Checking for updates from: $GITHUB_REPO"

RELEASE_DATA=$(curl -s "https://api.github.com/repos/$GITHUB_REPO/releases/latest" \
    -H "Accept: application/vnd.github.v3+json" \
    -H "User-Agent: HytaleServerManager-Updater")

if echo "$RELEASE_DATA" | grep -q '"message": "Not Found"'; then
    print_warning "No releases found on GitHub"
    echo "Repository: $GITHUB_REPO"
    exit 0
fi

LATEST_VERSION=$(echo "$RELEASE_DATA" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": "v\?\([^"]*\)".*/\1/')
echo "Latest version:  $LATEST_VERSION"

# Compare versions
version_gt() {
    test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"
}

if ! version_gt "$LATEST_VERSION" "$CURRENT_VERSION" && [[ "$FORCE" != true ]]; then
    print_success "You are already running the latest version!"
    exit 0
fi

if version_gt "$LATEST_VERSION" "$CURRENT_VERSION"; then
    echo ""
    print_warning "Update available: $CURRENT_VERSION -> $LATEST_VERSION"
fi

if [[ "$CHECK_ONLY" == true ]]; then
    echo ""
    echo "Release notes:"
    echo "$RELEASE_DATA" | grep '"body"' | head -1 | sed 's/.*"body": "\([^"]*\)".*/\1/' | sed 's/\\n/\n/g'
    echo ""
    exit 0
fi

# Find Linux download asset
DOWNLOAD_URL=$(echo "$RELEASE_DATA" | grep -o '"browser_download_url": "[^"]*linux[^"]*\.tar\.gz"' | head -1 | sed 's/.*"\(http[^"]*\)".*/\1/')

if [[ -z "$DOWNLOAD_URL" ]]; then
    print_error "No Linux release package found"
    exit 1
fi

# Confirm update
if [[ "$FORCE" != true ]]; then
    echo ""
    read -p "Do you want to install this update? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Update cancelled."
        exit 0
    fi
fi

# Stop the service
SERVICE_WAS_RUNNING=false
if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    print_status "Stopping service..."
    systemctl stop "$SERVICE_NAME"
    SERVICE_WAS_RUNNING=true
    print_success "Service stopped"
fi

# Create backup
BACKUP_DIR="$INSTALL_PATH/backups/update-$(date +%Y%m%d-%H%M%S)"
print_status "Creating backup: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
cp "$INSTALL_PATH/config.json" "$BACKUP_DIR/" 2>/dev/null || true
cp -r "$INSTALL_PATH/data" "$BACKUP_DIR/" 2>/dev/null || true
print_success "Backup created"

# Download update
DOWNLOAD_PATH="/tmp/hsm-update.tar.gz"
print_status "Downloading update..."
curl -L -o "$DOWNLOAD_PATH" "$DOWNLOAD_URL"
print_success "Download complete"

# Extract update
EXTRACT_PATH="/tmp/hsm-update"
print_status "Extracting update..."
rm -rf "$EXTRACT_PATH"
mkdir -p "$EXTRACT_PATH"
tar -xzf "$DOWNLOAD_PATH" -C "$EXTRACT_PATH"

# Find extracted directory
EXTRACTED_DIR=$(find "$EXTRACT_PATH" -maxdepth 1 -type d | tail -1)
print_success "Extracted successfully"

# Get service user
SERVICE_USER=$(stat -c '%U' "$INSTALL_PATH")

# Apply update (preserve config and data)
print_status "Applying update..."

# Remove old files except config and data
find "$INSTALL_PATH" -mindepth 1 -maxdepth 1 \
    ! -name 'config.json' \
    ! -name 'data' \
    ! -name 'backups' \
    -exec rm -rf {} \;

# Copy new files
cp -r "$EXTRACTED_DIR"/* "$INSTALL_PATH/"

# Set permissions
chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_PATH"

print_success "Files updated"

# Run database migrations
print_status "Running database migrations..."
cd "$INSTALL_PATH"

# Create database backup before migration
DB_PATH="$INSTALL_PATH/data/db/hytalepanel.db"
DB_BACKUP_PATH="$BACKUP_DIR/hytalepanel.db.pre-migration"
if [ -f "$DB_PATH" ]; then
    cp "$DB_PATH" "$DB_BACKUP_PATH"
    print_success "Database backed up before migration"
fi

npx prisma generate
if ! npx prisma migrate deploy; then
    print_warning "Database migration failed"
    if [ -f "$DB_BACKUP_PATH" ]; then
        print_status "Restoring database from backup..."
        cp "$DB_BACKUP_PATH" "$DB_PATH"
        print_success "Database restored from backup"
    fi
    print_error "Update completed but migrations failed. Please check the database manually."
else
    print_success "Database migrations applied"
fi

# Cleanup
print_status "Cleaning up..."
rm -f "$DOWNLOAD_PATH"
rm -rf "$EXTRACT_PATH"

# Restart service
if [[ "$SERVICE_WAS_RUNNING" == true ]]; then
    print_status "Starting service..."
    systemctl start "$SERVICE_NAME"
    print_success "Service started"
fi

# Done
echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  Update Complete!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "Updated from $CURRENT_VERSION to $LATEST_VERSION"
echo "Backup saved to: $BACKUP_DIR"
echo ""

if [[ "$SERVICE_WAS_RUNNING" == true ]]; then
    echo "Service is running. Check status with: sudo systemctl status $SERVICE_NAME"
else
    echo "Start the application with: sudo systemctl start $SERVICE_NAME"
fi

echo ""
