#!/usr/bin/env bash
set -euo pipefail

if [[ "${BEPINEX_ENABLED:-0}" != "1" ]]; then
  echo "BepInEx installer hook disabled (set BEPINEX_ENABLED=1 to enable)."
  exit 0
fi

echo "Configuring Wine DLL overrides for BepInEx (winhttp)..."
wine reg add "HKCU\\Software\\Wine\\DllOverrides" /v winhttp /d native,builtin /f

BEPINEX_ZIP="${BEPINEX_ZIP:-/docker/BepInEx/ASKA BEPINEX - WINDOWS VERSION-66-V2-0-0-1773857940.zip}"

if [[ ! -f "${BEPINEX_ZIP}" ]]; then
  echo "BepInEx package not found at: ${BEPINEX_ZIP}" >&2
  exit 1
fi

mkdir -p "${ASKA_SERVER_DIR}"

echo "Extracting BepInEx from ${BEPINEX_ZIP} into ${ASKA_SERVER_DIR}..."
unzip -uo "${BEPINEX_ZIP}" -d "${ASKA_SERVER_DIR}"

if [[ -n "${BEPINEX_POST_INSTALL_CMD:-}" ]]; then
  echo "Running BEPINEX_POST_INSTALL_CMD..."
  bash -lc "${BEPINEX_POST_INSTALL_CMD}"
fi

echo "BepInEx installer hook completed successfully."
