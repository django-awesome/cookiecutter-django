#!/bin/bash

# Enable logging
LOG_FILE="/tmp/post-start.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ${CYAN}[INFO]${NC} $1"
}

log_success() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ${RED}[ERROR]${NC} $1"
}

echo -e "${PURPLE}========================================${NC}"
echo -e "${PURPLE}     POST-START SCRIPT EXECUTION${NC}"
echo -e "${PURPLE}========================================${NC}"

# Fix Docker permissions (runtime-specific because socket is mounted at runtime)
log_info "Fixing Docker permissions..."
if [ -S /var/run/docker.sock ]; then
    # Add vscode user to docker group if it exists
    if getent group docker > /dev/null 2>&1; then
        sudo usermod -aG docker vscode
        log_success "Added vscode user to docker group"
    else
        # Create docker group if it doesn't exist
        sudo groupadd docker
        sudo usermod -aG docker vscode
        log_success "Created docker group and added vscode user"
    fi

    # Fix docker socket permissions
    sudo chmod 666 /var/run/docker.sock
    log_success "Docker socket permissions fixed"
else
    log_warning "Docker socket not found at /var/run/docker.sock"
fi

# Fix SSH permissions (runtime-specific because .ssh is mounted at runtime)
log_info "Fixing SSH permissions..."
if [ -d ~/.ssh ]; then
    chmod 700 ~/.ssh
    find ~/.ssh -type f -exec chmod 600 {} \;
    log_success "SSH permissions fixed"

    # Set up authorized_keys for SSH key authentication
    log_info "Setting up SSH key authentication..."

    # Create authorized_keys file
    touch ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys

    # Fetch GitHub public keys if GITHUB_USERNAME is set
    if [ -n "$GITHUB_USERNAME" ] && [ "$GITHUB_USERNAME" != "your-github-username" ]; then
        log_info "Fetching SSH keys from GitHub user: $GITHUB_USERNAME"

        if curl -sS "https://github.com/${GITHUB_USERNAME}.keys" >> ~/.ssh/authorized_keys 2>/dev/null; then
            log_success "GitHub SSH keys added for user: $GITHUB_USERNAME"
        else
            log_error "Failed to fetch SSH keys from GitHub for user: $GITHUB_USERNAME"
        fi
    else
        log_warning "GITHUB_USERNAME not set or is default value"
        log_info "Set GITHUB_USERNAME in devcontainer.json to enable automatic SSH key setup"
    fi

    # Also add local mounted keys if they exist
    if [ -f ~/.ssh/id_rsa.pub ] || [ -f ~/.ssh/id_ed25519.pub ]; then
        log_info "Adding local SSH keys to authorized_keys..."
        [ -f ~/.ssh/id_rsa.pub ] && cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
        [ -f ~/.ssh/id_ed25519.pub ] && cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
        log_success "Local SSH keys added"
    fi

    # Remove duplicates and empty lines
    sort -u ~/.ssh/authorized_keys | grep -v '^$' > ~/.ssh/authorized_keys.tmp
    mv ~/.ssh/authorized_keys.tmp ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
else
    log_warning "No ~/.ssh directory found"
fi

# Start SSH service (runtime service)
log_info "Starting SSH service..."
sudo service ssh stop 2>/dev/null || true

# Try to start SSH service with retries
MAX_RETRIES=3
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if sudo service ssh start; then
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    log_warning "SSH start attempt $RETRY_COUNT failed, retrying..."
    sleep 2
done

# Verify SSH is running
sleep 1
if sudo service ssh status > /dev/null 2>&1; then
    log_success "SSH service started successfully"

    # Check if SSH is actually listening
    if sudo ss -tlnp | grep :22 > /dev/null 2>&1 || sudo netstat -tlnp | grep :22 > /dev/null 2>&1; then
        log_success "SSH is listening on port 22"

        # Display connection info
        log_info "SSH connection info:"
        log_info "  - Port: 22 (mapped to host port 2221)"
        log_info "  - Username: vscode"
        log_info "  - Password: vscode (or use SSH key)"

        # Get container IP if possible
        CONTAINER_IP=$(hostname -I | awk '{print $1}')
        if [ -n "$CONTAINER_IP" ]; then
            log_info "  - Container IP: $CONTAINER_IP"
        fi
    else
        log_error "SSH not listening on port 22"
        log_info "Checking SSH daemon logs..."
        sudo journalctl -u ssh -n 20 --no-pager || sudo tail -20 /var/log/auth.log
    fi
else
    log_error "SSH service failed to start after $MAX_RETRIES attempts"
    sudo service ssh status
fi

# Source Powerlevel10k instant prompt if available
if [ -f ~/.p10k.zsh ] && [ ! -f ~/.p10k-instant-prompt-${USER}.zsh ]; then
    log_info "Enabling Powerlevel10k instant prompt..."
    # This ensures instant prompt works on subsequent shells
    touch ~/.p10k-instant-prompt-${USER}.zsh
fi

echo -e "${PURPLE}========================================${NC}"
echo -e "${GREEN}Post-start script completed!${NC}"
echo -e "${PURPLE}========================================${NC}"

# Add any additional runtime-specific startup commands here as needed