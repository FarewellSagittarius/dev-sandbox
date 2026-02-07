#!/bin/bash
set -e

# Start Docker daemon (Docker-in-Docker)
sudo sh -c 'dockerd &>/var/log/dockerd.log' &

# Wait for Docker to be ready
timeout=30
while ! sudo docker info &>/dev/null && [ $timeout -gt 0 ]; do
    sleep 1
    timeout=$((timeout - 1))
done

# Start SSH server
if [ -x /usr/sbin/sshd ]; then
    sudo /usr/sbin/sshd
fi

# Start Claude Code Wrapper
cd /opt/claude-wrapper
source .venv/bin/activate
exec uvicorn src.main:app --host 0.0.0.0 --port 8790
