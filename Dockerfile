# Dev Sandbox - Full-stack Development Environment
# Based on Microsoft DevContainers Universal Image
# With Claude Code Wrapper (Anthropic Messages API) integrated

FROM mcr.microsoft.com/devcontainers/universal:2-linux

LABEL maintainer="farewell"
LABEL description="Dev sandbox with Claude Code integration based on DevContainers"

# Avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai

# The universal image already includes:
# - Python 3.x with pip, pipx, venv
# - Node.js with npm, yarn
# - Go
# - Rust with cargo
# - Java with Maven, Gradle
# - .NET
# - PHP
# - Ruby
# - Docker CLI
# - Git, GitHub CLI, Azure CLI
# - Common development tools

# Install additional tools we need
USER root

# Fix yarn GPG key issue and install additional packages
RUN rm -f /etc/apt/sources.list.d/yarn.list 2>/dev/null || true \
    && apt-get update || true \
    && apt-get install -y --no-install-recommends \
    openssh-server \
    ripgrep \
    fd-find \
    bat \
    fzf \
    tmux \
    htop \
    tree \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Setup SSH server
RUN mkdir -p /var/run/sshd \
    && echo 'codespace:codespace' | chpasswd \
    && sed -i 's/^Port.*/Port 22/' /etc/ssh/sshd_config \
    && sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && echo 'AllowUsers codespace' >> /etc/ssh/sshd_config

# Add codespace user to docker group for Docker-in-Docker access
RUN groupadd -f docker && usermod -aG docker codespace

# Setup Claude Code Wrapper
WORKDIR /opt/claude-wrapper

# Copy wrapper source
COPY --chown=codespace:codespace claude-code-wrapper/ ./

# Create virtual environment and install dependencies
RUN python3 -m venv .venv \
    && . .venv/bin/activate \
    && pip install --upgrade pip \
    && pip install -r requirements.txt

# Create directories for AI config persistence
RUN mkdir -p /home/codespace/.claude \
    /home/codespace/.codex \
    /home/codespace/.gemini \
    && chown -R codespace:codespace /home/codespace/.claude \
    /home/codespace/.codex \
    /home/codespace/.gemini

# Setup workspaces directory (DevContainer standard)
RUN mkdir -p /workspaces && chown -R codespace:codespace /workspaces

# Copy entrypoint script
COPY --chmod=755 entrypoint.sh /entrypoint.sh

# Switch to non-root user
USER codespace

# Add ~/.local/bin to PATH (for non-interactive shells like SSH commands)
ENV PATH="/home/codespace/.local/bin:${PATH}"

# Install uv (fast Python package manager) for codespace user
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Install Claude Code (as codespace user)
RUN curl -fsSL https://claude.ai/install.sh | bash

# Install AI CLI tools for codespace user
RUN npm install -g @openai/codex @google/gemini-cli

# Add ~/.local/bin to PATH for Claude and uv (both interactive and non-interactive shells)
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc \
    && echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.profile \
    && echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bash_profile

# Create symlinks in /usr/local/bin for SSH non-interactive access (requires root)
USER root
RUN ln -sf /home/codespace/.local/bin/claude /usr/local/bin/claude \
    && ln -sf /home/codespace/.local/bin/uv /usr/local/bin/uv \
    && ln -sf /home/codespace/.local/bin/uvx /usr/local/bin/uvx
USER codespace

WORKDIR /workspaces

# Environment variables - CLAUDE_CWD will be set dynamically

# Expose ports
EXPOSE 8790 22

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8790/health || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["serve"]
