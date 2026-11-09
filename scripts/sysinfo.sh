#!/usr/bin/env bash
set -euo pipefail

echo "User: $(id -un) (effective UID: $(id -u))"
echo "Hostname: $(hostname)"
echo "Kernel release: $(uname -r)"
echo "Date (ISO-8601): $(date -Iseconds)"
echo "--- Disk usage ---"
df -h
echo "--- Memory usage ---"
free -h
echo "--- Docker daemon ---"
if docker info >/dev/null 2>&1; then
  echo "Docker daemon: running"
else
  echo "Docker daemon: not running or not reachable"
fi
