#!/bin/bash

# Verification script for devcontainer setup
# This script checks if all installed tools and configurations are working properly

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Counters
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# Helper functions
check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASS_COUNT++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAIL_COUNT++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARN_COUNT++))
}

check_command() {
    local cmd=$1
    local name=${2:-$1}
    if command -v "$cmd" &> /dev/null; then
        # Use timeout to prevent hanging on version checks
        local version=$(timeout 2s $cmd --version 2>&1 | head -n1 || echo "version unknown")
        check_pass "$name is installed: $version"
        return 0
    else
        check_fail "$name is not installed"
        return 1
    fi
}

check_command_simple() {
    local cmd=$1
    local name=${2:-$1}
    if command -v "$cmd" &> /dev/null; then
        check_pass "$name is installed"
        return 0
    else
        check_fail "$name is not installed"
        return 1
    fi
}

check_file() {
    local file=$1
    local desc=$2
    if [ -f "$file" ]; then
        check_pass "$desc exists"
        return 0
    else
        check_fail "$desc not found"
        return 1
    fi
}

check_dir() {
    local dir=$1
    local desc=$2
    if [ -d "$dir" ]; then
        check_pass "$desc exists"
        return 0
    else
        check_fail "$desc not found"
        return 1
    fi
}

echo -e "${PURPLE}========================================${NC}"
echo -e "${PURPLE}    DEVCONTAINER SETUP VERIFICATION${NC}"
echo -e "${PURPLE}========================================${NC}"
echo ""

# System Information
echo -e "${CYAN}=== System Information ===${NC}"
echo "User: $(whoami)"
echo "Home: $HOME"
echo "Shell: $SHELL"
echo "OS: $(lsb_release -d | cut -f2)"
echo ""

# Basic System Tools
echo -e "${CYAN}=== Basic System Tools ===${NC}"
check_command curl
check_command wget
check_command git
check_command vim
check_command nano
check_command sudo
check_command locale "Locale tools"
echo ""

# Development Tools
echo -e "${CYAN}=== Development Tools ===${NC}"
check_command gcc "GCC compiler"
check_command g++ "G++ compiler"
check_command make
check_command cmake
check_command pkg-config
check_command clang-format "Clang Format"
check_command shellcheck "ShellCheck"
echo ""

# Python Environment
echo -e "${CYAN}=== Python Environment ===${NC}"
check_command python3
check_command pip3 "pip"
check_command uv

if command -v uv &> /dev/null; then
    echo "uv Python versions available:"
    uv python list --installed 2>/dev/null | sed 's/^/  /'
fi
echo ""

# Node.js Environment
echo -e "${CYAN}=== Node.js Environment ===${NC}"
check_command node
check_command npm

if [ -d "$NVM_DIR" ]; then
    check_pass "NVM directory exists at $NVM_DIR"
else
    check_warn "NVM directory not found at $NVM_DIR"
fi
echo ""

# Shell and Terminal Tools
echo -e "${CYAN}=== Shell and Terminal Tools ===${NC}"
check_command zsh
check_command tmux
check_command htop
check_command tree
check_command jq "jq (JSON processor)"
check_command rg "ripgrep"
check_command fdfind "fd-find" || check_command fd "fd-find"
check_command batcat "bat" || check_command bat
check_command fzf "fzf (fuzzy finder)"
echo ""

# Network Tools
echo -e "${CYAN}=== Network Tools ===${NC}"
check_command_simple ping
check_command_simple netstat "netstat" || check_command_simple ss "ss (netstat alternative)"
check_command_simple nslookup
check_command_simple dig
check_command ssh "SSH client"
check_command sshd "SSH server"
echo ""

# Database Clients
echo -e "${CYAN}=== Database Clients ===${NC}"
check_command psql "PostgreSQL client"
check_command mysql "MySQL client"
check_command redis-cli "Redis client"
echo ""

# Docker
echo -e "${CYAN}=== Docker ===${NC}"
if [ -S /var/run/docker.sock ]; then
    check_pass "Docker socket exists"
    if [ -r /var/run/docker.sock ] && [ -w /var/run/docker.sock ]; then
        check_pass "Docker socket is accessible"
        if command -v docker &> /dev/null; then
            if docker version &> /dev/null; then
                check_pass "Docker is working"
                echo "Docker version:"
                docker version --format 'Client: {{.Client.Version}}, Server: {{.Server.Version}}' 2>/dev/null | sed 's/^/  /'
            else
                check_fail "Docker command exists but not working"
            fi
        else
            check_warn "Docker command not found (install docker-ce package if needed)"
        fi
    else
        check_fail "Docker socket exists but not accessible"
    fi
else
    check_warn "Docker socket not found (Docker-outside-of-Docker may not be configured)"
fi

# Check if user is in docker group
if groups | grep -q docker; then
    check_pass "User is in docker group"
else
    check_warn "User is not in docker group (may need to restart shell)"
fi
echo ""

# SSH Configuration
echo -e "${CYAN}=== SSH Configuration ===${NC}"
check_file /etc/ssh/sshd_config "SSH daemon config"
check_dir ~/.ssh "SSH directory"

if [ -d ~/.ssh ]; then
    # Check permissions
    ssh_perm=$(stat -c %a ~/.ssh 2>/dev/null || stat -f %Lp ~/.ssh 2>/dev/null)
    if [ "$ssh_perm" = "700" ]; then
        check_pass "SSH directory permissions are correct (700)"
    else
        check_warn "SSH directory permissions are $ssh_perm (should be 700)"
    fi

    # Check for keys
    if ls ~/.ssh/*.pub &> /dev/null; then
        check_pass "SSH public keys found"
    else
        check_warn "No SSH public keys found"
    fi

    check_file ~/.ssh/authorized_keys "SSH authorized_keys"
fi

# Check if SSH service is running
if sudo service ssh status &> /dev/null; then
    check_pass "SSH service is running"
    if sudo ss -tlnp | grep :22 &> /dev/null || sudo netstat -tlnp | grep :22 &> /dev/null; then
        check_pass "SSH is listening on port 22"
    else
        check_fail "SSH service running but not listening on port 22"
    fi
else
    check_fail "SSH service is not running"
fi
echo ""

# Zsh Configuration
echo -e "${CYAN}=== Zsh Configuration ===${NC}"
check_dir ~/.oh-my-zsh "Oh My Zsh"
check_file ~/.zshrc "Zsh config"

if [ -d ~/.oh-my-zsh ]; then
    # Check theme
    if [ -d ~/.oh-my-zsh/custom/themes/powerlevel10k ]; then
        check_pass "Powerlevel10k theme installed"
    else
        check_fail "Powerlevel10k theme not found"
    fi

    # Check plugins
    plugins=("zsh-autosuggestions" "zsh-syntax-highlighting" "fast-syntax-highlighting" "zsh-bat" "you-should-use")
    for plugin in "${plugins[@]}"; do
        if [ -d ~/.oh-my-zsh/custom/plugins/$plugin ]; then
            check_pass "Plugin $plugin installed"
        else
            check_fail "Plugin $plugin not found"
        fi
    done
fi

check_file ~/.p10k.zsh "Powerlevel10k config"
echo ""

# Environment Variables
echo -e "${CYAN}=== Environment Variables ===${NC}"
if [ -n "$GITHUB_USERNAME" ]; then
    check_pass "GITHUB_USERNAME is set: $GITHUB_USERNAME"
else
    check_warn "GITHUB_USERNAME is not set"
fi

if command -v uv &> /dev/null; then
    check_pass "uv is available in PATH"
else
    check_warn "uv is not available in PATH"
fi

if [ -n "$NVM_DIR" ]; then
    check_pass "NVM_DIR is set: $NVM_DIR"
else
    check_warn "NVM_DIR is not set"
fi
echo ""

# Welcome Script
echo -e "${CYAN}=== Welcome Script ===${NC}"
check_file ~/welcome.sh "Welcome script"
if [ -f ~/welcome.sh ]; then
    if [ -x ~/welcome.sh ]; then
        check_pass "Welcome script is executable"
    else
        check_warn "Welcome script exists but is not executable"
    fi
fi
echo ""

# Summary
echo -e "${PURPLE}========================================${NC}"
echo -e "${PURPLE}              SUMMARY${NC}"
echo -e "${PURPLE}========================================${NC}"
echo -e "Passed: ${GREEN}$PASS_COUNT${NC}"
echo -e "Failed: ${RED}$FAIL_COUNT${NC}"
echo -e "Warnings: ${YELLOW}$WARN_COUNT${NC}"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    if [ $WARN_COUNT -eq 0 ]; then
        echo -e "${GREEN}All checks passed! Your devcontainer is fully configured.${NC}"
    else
        echo -e "${GREEN}Setup is functional with some warnings.${NC}"
        echo -e "${YELLOW}Review the warnings above for optional improvements.${NC}"
    fi
else
    echo -e "${RED}Some checks failed. Please review the errors above.${NC}"
    echo -e "${YELLOW}You may need to rebuild the container or run the setup scripts again.${NC}"
fi

# Exit with appropriate code
if [ $FAIL_COUNT -gt 0 ]; then
    exit 1
else
    exit 0
fi