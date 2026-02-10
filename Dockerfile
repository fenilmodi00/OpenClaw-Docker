# OpenClaw Docker Image - Generic AI Gateway
FROM node:22-slim

# Set working directory
WORKDIR /app

# Install system dependencies (brew requirements included)
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    gosu \
    jq \
    tini \
    build-essential \
    procps \
    file \
  && rm -rf /var/lib/apt/lists/*

# Update npm and install OpenClaw
RUN npm install -g npm@latest \
 && npm install -g openclaw@2026.2.6-3

# Prepare Homebrew directories
RUN mkdir -p /home/linuxbrew \
 && chown -R node:node /home/linuxbrew

# Switch to node user for Homebrew install
USER node

# Install Homebrew (Linuxbrew) as non-root
ENV NONINTERACTIVE=1
RUN bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Set Homebrew environment
ENV HOMEBREW_PREFIX=/home/linuxbrew/.linuxbrew \
    HOMEBREW_CELLAR=/home/linuxbrew/.linuxbrew/Cellar \
    HOMEBREW_REPOSITORY=/home/linuxbrew/.linuxbrew/Homebrew \
    PATH=/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH

# Switch back to root
USER root

# Create OpenClaw workspace
RUN mkdir -p /home/node/.openclaw/workspace \
 && chown -R node:node /home/node

# Copy initialization script
COPY ./init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh

# Base environment
ENV HOME=/home/node \
    TERM=xterm-256color

# Expose OpenClaw ports
EXPOSE 18789 18790

# Switch to home
WORKDIR /home/node

# Entrypoint
ENTRYPOINT ["/usr/bin/tini", "--", "/bin/bash", "/usr/local/bin/init.sh"]
