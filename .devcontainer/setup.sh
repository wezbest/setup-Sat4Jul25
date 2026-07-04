#!/usr/bin/env bash

set -euxo pipefail

echo "🚀 Starting dev environment setup (as of $(date))..."

# ----------------------------
# 1. System Packages
# ----------------------------
echo "📦 Installing essential system packages..."
sudo apt update
sudo apt install -y \
    curl \
    wget \
    git \
    gnupg \
    build-essential \
    software-properties-common \
    libssl-dev \
    lsb-release \
    procps \
    xclip \
    ca-certificates

# ----------------------------
# 2. Fish Shell (v4 via official PPA)
# ----------------------------
if ! command -v fish >/dev/null || ! fish --version | grep -q 'version 4'; then
    echo "🐟 Installing Fish Shell v4..."
    # -y ensures add-apt-repository doesn't prompt
    sudo add-apt-repository ppa:fish-shell/release-4 -y
    sudo apt update
    sudo apt install -y fish
fi

# ----------------------------
# 3. Homebrew (Linuxbrew) – Fully Non-interactive
# ----------------------------
if ! command -v brew >/dev/null; then
    echo "🍺 Installing Homebrew (Linuxbrew)..."
    export NONINTERACTIVE=1 HOMEBREW_NO_ENV_HINTS=1
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if ! grep -q "brew shellenv" ~/.bashrc; then
        echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >>~/.bashrc
    fi

    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

command -v brew >/dev/null || {
    echo "❌ Homebrew failed to install"
    exit 1
}

# ----------------------------
# 4. Install shfmt via Homebrew (CRITICAL FIX: NO_ASK prevents hangs)
# ----------------------------
if ! command -v shfmt >/dev/null; then
    echo "🔧 Installing shfmt (for shell formatting)..."
    # HOMEBREW_NO_ASK=1 prevents the "[y/n]" prompt that blocks CI
    export HOMEBREW_NO_ASK=1
    brew install shfmt
    # Alternative: brew install -y shfmt
fi

shfmt --version

# ----------------------------
# 5. Docker-in-Docker Setup
# ----------------------------
if command -v dockerd >/dev/null; then
    echo "🐳 Configuring Docker-in-Docker..."

    if docker version --format '{{.Server.Version}}' >/dev/null 2>&1; then
        echo "✅ Docker is already operational."
    else
        echo "   Starting dockerd in background..."
        sudo dockerd --host=unix:///var/run/docker.sock >/tmp/dockerd.log 2>&1 &
        timeout 15s bash -c 'until [ -S /var/run/docker.sock ]; do sleep 1; done' || {
            echo "⚠️  Docker daemon did not start in time"
        }
        if docker version --format '{{.Server.Version}}' >/dev/null 2>&1; then
            echo "✅ Docker started successfully."
        else
            echo "⚠️ Docker daemon still not accessible – check /tmp/dockerd.log"
        fi
    fi

    if ! groups "$USER" | grep -qw docker; then
        sudo usermod -aG docker "$USER"
        echo "ℹ️  Added $USER to 'docker' group. Restart shell or container to apply."
    fi
else
    echo "ℹ️ Docker not detected — skipping Docker setup."
fi

# ----------------------------
# 6. Final Summary
# ----------------------------
echo
echo "✅ Dev environment setup complete!"
echo "✨ Installed:"
echo "   - Fish Shell: $(fish --version | head -n1)"
echo "   - Homebrew: $(brew --version | head -n1)"
echo "   - shfmt: $(shfmt --version)"
if command -v docker >/dev/null; then
    echo "   - Docker: $(docker --version)"
fi
echo
echo "💡 Reminder: Reopen your terminal or rebuild the container to fully activate group permissions (e.g., Docker)."
