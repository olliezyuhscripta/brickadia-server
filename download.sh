#!/bin/bash
# Fetch the Brickadia dedicated server depot with DepotDownloader (x86-64).
# SteamCMD is unusable on gVisor kernels: only a 32-bit binary is shipped and
# IA32 emulation is absent. See README "What was actually hard".
set -euo pipefail

INSTALL_DIR="${1:-/opt/brickadia}"
APP_ID=3017590
TOOLS_DIR="${TOOLS_DIR:-/opt/depotdl}"
VERSION="3.4.0"
URL="https://github.com/SteamRE/DepotDownloader/releases/download/DepotDownloader_${VERSION}/DepotDownloader-linux-x64.zip"

if [ ! -x "${TOOLS_DIR}/DepotDownloader" ]; then
    echo "fetching DepotDownloader ${VERSION}"
    mkdir -p "${TOOLS_DIR}"
    tmp="$(mktemp -d)"
    trap 'rm -rf "${tmp}"' EXIT
    curl -fsSL "${URL}" -o "${tmp}/dd.zip"
    python3 -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" \
        "${tmp}/dd.zip" "${TOOLS_DIR}"
    chmod +x "${TOOLS_DIR}/DepotDownloader"
fi

# Manifest ids pin the exact build (Release-EA3-CL-16374). Drop the -manifest
# flags to track whatever is current instead.
echo "downloading app ${APP_ID} into ${INSTALL_DIR}"
"${TOOLS_DIR}/DepotDownloader" \
    -app "${APP_ID}" \
    -dir "${INSTALL_DIR}" \
    -manifest 3017592:1494791018044619310 \
    -anonymous \
    -os linux

server="${INSTALL_DIR}/Brickadia/Binaries/Linux/BrickadiaServer-Linux-Shipping"
if [ ! -f "${server}" ]; then
    echo "expected server binary missing: ${server}" >&2
    exit 1
fi
chmod +x "${server}" "${INSTALL_DIR}/Brickadia/Binaries/Linux/BrickadiaServer-Linux-Test" 2>/dev/null || true
echo "ok: ${server}"
