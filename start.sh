#!/bin/bash
# Start the Brickadia dedicated server.
# Token: https://brickadia.com/ -> create a server hosting token.
# It is a credential; read it from the environment, never from this file.
set -euo pipefail

INSTALL_DIR="${1:-/opt/brickadia}"
PORT="${BRICKADIA_PORT:-7777}"
DATA_HOME="${BRICKADIA_HOME:-${INSTALL_DIR}-home}"

if [ -z "${BRICKADIA_TOKEN:-}" ]; then
    echo "BRICKADIA_TOKEN is not set (base64 server hosting token)" >&2
    exit 1
fi

# World, roles and the cached auth session live here.
mkdir -p "${DATA_HOME}/.config"

cd "${INSTALL_DIR}"
export HOME="${DATA_HOME}"
export LD_LIBRARY_PATH="${INSTALL_DIR}/Brickadia/Binaries/Linux${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

exec "${INSTALL_DIR}/Brickadia/Binaries/Linux/BrickadiaServer-Linux-Shipping" \
    -log "-port=${PORT}" "-token=${BRICKADIA_TOKEN}"
