#!/bin/bash

# Post-create script for devcontainer
# This script runs once when the container is first created

set -e

# Color codes for output
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
echo -e "${PURPLE}     POST-CREATE SCRIPT EXECUTION${NC}"
echo -e "${PURPLE}========================================${NC}"

# Update package lists
log_info "Updating package lists..."
sudo apt-get update

# Install essential packages in categories
log_info "Installing system utilities..."
sudo apt-get install -y --no-install-recommends \
    curl ca-certificates gnupg lsb-release \
    locales sudo vim nano \
    wget unzip zip

log_info "Installing development tools..."
sudo apt-get install -y --no-install-recommends \
    git build-essential cmake pkg-config \
    clang-format shellcheck

log_info "Installing Python development dependencies..."
sudo apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv python3-dev \
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
    libsqlite3-dev libncursesw5-dev xz-utils tk-dev \
    libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev

log_info "Installing shell and terminal tools..."
sudo apt-get install -y --no-install-recommends \
    zsh tmux htop tree jq \
    ripgrep fd-find bat fzf

log_info "Installing network tools..."
sudo apt-get install -y --no-install-recommends \
    net-tools iputils-ping dnsutils \
    openssh-server

log_info "Installing database clients..."
sudo apt-get install -y --no-install-recommends \
    postgresql-client postgresql-dev libpq-dev

# Fix bat command if installed as batcat
if command -v batcat &> /dev/null && ! command -v bat &> /dev/null; then
    log_info "Creating bat symlink..."
    sudo ln -sf /usr/bin/batcat /usr/local/bin/bat
    log_success "bat command configured"
fi

# Install uv
log_info "Installing uv..."
if ! command -v uv &> /dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh

    # Add uv to shell profiles
    UV_CONFIG='
# uv configuration
export PATH="$HOME/.local/bin:$PATH"
'
    echo "$UV_CONFIG" >> ~/.bashrc
    echo "$UV_CONFIG" >> ~/.zshrc

    log_success "uv installed and configured"
else
    log_info "uv already installed"
fi

# Set default password for vscode user
log_info "Setting up user authentication..."
echo "vscode:vscode" | sudo chpasswd
log_success "Default password set for vscode user (password: vscode)"

# Configure SSH daemon
log_info "Configuring SSH daemon..."
sudo sed -i 's/^#*ListenAddress .*/ListenAddress 0.0.0.0/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i 's/^#*Port .*/Port 22/' /etc/ssh/sshd_config

# Add SSH performance optimizations
if ! grep -q "Performance and keep-alive settings" /etc/ssh/sshd_config; then
    sudo tee -a /etc/ssh/sshd_config > /dev/null << 'EOF'

# Performance and keep-alive settings
ClientAliveInterval 60
ClientAliveCountMax 3
TCPKeepAlive yes
UseDNS no
Compression yes
EOF
    log_success "SSH configuration updated"
fi

# Generate SSH host keys
log_info "Generating SSH host keys..."
sudo ssh-keygen -A
log_success "SSH host keys generated"

# Install Zsh plugins and themes
log_info "Installing Zsh customizations..."
if [ -d ~/.oh-my-zsh ]; then
    ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}

    # Install Powerlevel10k theme
    if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $ZSH_CUSTOM/themes/powerlevel10k
        log_success "Powerlevel10k theme installed"
    fi

    # Install Zsh plugins
    plugins=(
        "zsh-users/zsh-autosuggestions:zsh-autosuggestions"
        "zsh-users/zsh-syntax-highlighting:zsh-syntax-highlighting"
        "zdharma-continuum/fast-syntax-highlighting:fast-syntax-highlighting"
        "marlonrichert/zsh-autocomplete:zsh-autocomplete"
        "fdellwing/zsh-bat:zsh-bat"
        "MichaelAquilina/zsh-you-should-use:you-should-use"
    )

    for plugin_spec in "${plugins[@]}"; do
        plugin_repo="${plugin_spec%%:*}"
        plugin_name="${plugin_spec##*:}"
        if [ ! -d "$ZSH_CUSTOM/plugins/$plugin_name" ]; then
            git clone --depth=1 "https://github.com/$plugin_repo" "$ZSH_CUSTOM/plugins/$plugin_name" 2>/dev/null
        fi
    done
    log_success "Zsh plugins installed"

    # Configure .zshrc
    sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc
    sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting fast-syntax-highlighting zsh-bat you-should-use)/' ~/.zshrc

    # Add shell configurations
    if ! grep -q "Plugin configurations" ~/.zshrc; then
        cat >> ~/.zshrc << 'EOF'

# Plugin configurations
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#666666"
export ZSH_AUTOSUGGEST_STRATEGY=(history completion)
export YSU_MESSAGE_POSITION="after"
export YSU_MODE=ALL
export FORGIT_NO_ALIASES=1

# Python development
export PYTHONDONTWRITEBYTECODE=1
export PYTHONUNBUFFERED=1

# Node.js development
export NVM_DIR="/usr/local/share/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# AWS CLI
export AWS_CLI_AUTO_PROMPT=on-partial

# Better history
export HISTSIZE=100000
export SAVEHIST=100000
export HISTFILE=~/.zsh_history
setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_VERIFY
setopt SHARE_HISTORY
EOF
        log_success "Zsh configuration updated"
    fi
fi

# Copy Powerlevel10k configuration
if [ -f .devcontainer/configs/.p10k.zsh ]; then
    cp .devcontainer/configs/.p10k.zsh ~/.p10k.zsh
    log_success "Powerlevel10k configuration copied"

    # Add p10k sourcing to .zshrc if not already present
    if ! grep -q "\.p10k\.zsh" ~/.zshrc; then
        echo '' >> ~/.zshrc
        echo '# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.' >> ~/.zshrc
        echo '[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh' >> ~/.zshrc
        log_success "Added Powerlevel10k sourcing to .zshrc"
    fi
else
    log_warning "Powerlevel10k config file not found at .devcontainer/configs/.p10k.zsh"
fi

# Copy welcome script
if [ -f .devcontainer/scripts/welcome.sh ]; then
    cp .devcontainer/scripts/welcome.sh ~/welcome.sh
    chmod +x ~/welcome.sh

    # Add to shell profiles
    if ! grep -q "welcome.sh" ~/.bashrc; then
        echo '/bin/bash ~/welcome.sh' >> ~/.bashrc
    fi
    if ! grep -q "welcome.sh" ~/.zshrc; then
        echo '/bin/bash ~/welcome.sh' >> ~/.zshrc
    fi
    log_success "Welcome message configured"
fi

# Initialize development environment (from Makefile init)
log_info "Setting up cookiecutter-django development environment..."
PYTHON_VERSION=${PYTHON_VERSION:-3.12.8}
PROJECT_NAME="cookiecutter-django"

# Source uv if available
export PATH="$HOME/.local/bin:$PATH"
if command -v uv &> /dev/null; then
    log_info "Installing Python ${PYTHON_VERSION} with uv..."
    uv python install ${PYTHON_VERSION}
    
    # Create virtual environment with uv
    log_info "Creating virtual environment with uv..."
    uv venv --python ${PYTHON_VERSION}
    
    # Activate the virtual environment
    source .venv/bin/activate
    
    log_success "Python environment configured with uv"
fi

# Install cookiecutter with uv
log_info "Installing cookiecutter with uv..."
if command -v uv &> /dev/null; then
    uv pip install cookiecutter
    log_success "cookiecutter installed with uv"
else
    # Fallback to pip if uv is not available
    log_info "Updating pip to the latest version..."
    python3 -m pip install --upgrade pip --break-system-packages
    pip install cookiecutter
    log_success "cookiecutter installed with pip"
fi

# Update npm
log_info "Updating npm to the latest version..."
if command -v npm &> /dev/null; then
    npm install -g npm@latest
    log_success "npm updated successfully"
else
    log_warning "npm not found, skipping npm update"
fi

# Install Claude Code globally if npm is available
if command -v npm &> /dev/null; then
    log_info "Installing Claude Code globally..."
    npm install -g @anthropic-ai/claude-code
    log_success "Claude Code installed globally"
fi

# Clean up apt cache to reduce image size
log_info "Cleaning up package cache..."
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*

echo -e "${PURPLE}========================================${NC}"
echo -e "${GREEN}Post-create script completed!${NC}"
echo -e "${PURPLE}========================================${NC}"