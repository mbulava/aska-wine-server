#!/usr/bin/env bash
set -euo pipefail

if [[ "${BEPINEX_ENABLED:-0}" != "1" ]]; then
  echo "BepInEx installer hook disabled (set BEPINEX_ENABLED=1 to enable)."
  exit 0
fi


BEPINEX_ZIP="${BEPINEX_ZIP:-/docker/BepInEx/ASKA BEPINEX - WINDOWS VERSION-66-V2-0-0-1773857940.zip}"

if [[ ! -f "${BEPINEX_ZIP}" ]]; then
  echo "BepInEx package not found at: ${BEPINEX_ZIP}" >&2
  exit 1
fi

mkdir -p "${ASKA_SERVER_DIR}"

echo "Extracting BepInEx from ${BEPINEX_ZIP} into ${ASKA_SERVER_DIR}..."
unzip -uo "${BEPINEX_ZIP}" -d "${ASKA_SERVER_DIR}"

# Prevent Wine Invalid Handle crash in BepInEx ConsoleLogListener (CoreCLR WindowsConsoleStream)
BEPINEX_CFG="${ASKA_SERVER_DIR}/BepInEx/config/BepInEx.cfg"
mkdir -p "$(dirname "${BEPINEX_CFG}")"

echo "Configuring BepInEx logging settings to avoid Wine console handle errors..."
if [ ! -f "${BEPINEX_CFG}" ]; then
  cat > "${BEPINEX_CFG}" <<'EOF'
[Logging]
UnityLogListening = true

[Logging.Console]
## Enables showing a console for log output.
# Setting type: Boolean
# Default value: false
Enabled = false

## Which standard output to redirect to.
# Setting type: StandardOutType
# Default value: StandardOut
# Acceptable values: Auto, None, ConsoleOut, StandardOut
StandardOutType = None

## Prevent console from closing when game exits.
# Setting type: Boolean
# Default value: false
PreventClose = false

[Logging.Disk]
## Enables writing log messages to LogOutput.log.
# Setting type: Boolean
# Default value: true
Enabled = true

[Logging.Unity]
## Enables forwarding BepInEx logs to Unity's log.
# Setting type: Boolean
# Default value: true
Enabled = true
EOF
else
  awk '
    /^\[Logging\.Console\]/ { in_console=1; seen_sot=0; print; next }
    /^\[/ {
      if (in_console && !seen_sot) { print "StandardOutType = None" }
      in_console=0
    }
    in_console && /^#?Enabled\s*=/ { print "Enabled = false"; next }
    in_console && /^#?StandardOutType\s*=/ { seen_sot=1; print "StandardOutType = None"; next }
    in_console && /^#?StandardOut\s*=/ { next }
    { print }
    END {
      if (in_console && !seen_sot) { print "StandardOutType = None" }
    }
  ' "${BEPINEX_CFG}" > "${BEPINEX_CFG}.tmp" && mv "${BEPINEX_CFG}.tmp" "${BEPINEX_CFG}"
fi


if [[ -n "${BEPINEX_POST_INSTALL_CMD:-}" ]]; then
  echo "Running BEPINEX_POST_INSTALL_CMD..."
  bash -lc "${BEPINEX_POST_INSTALL_CMD}"
fi

# Ensure BepInEx logs are linked into ASKA_SERVER_DIR/logs/bepinex
mkdir -p "${ASKA_SERVER_DIR}/logs/bepinex"
if [ -d "${ASKA_SERVER_DIR}/BepInEx" ]; then
  ln -sfn "${ASKA_SERVER_DIR}/BepInEx/LogOutput.log" "${ASKA_SERVER_DIR}/logs/bepinex/LogOutput.log" 2>/dev/null || true
  echo "BepInEx Logs can be found at ${ASKA_SERVER_DIR}/logs/bepinex/LogOutput.log"
fi

# Ensure BepInEx directory and plugins have read/write/traversal permissions
if [ -d "${ASKA_SERVER_DIR}/BepInEx" ]; then
  chmod -R u+rwX,go+rX "${ASKA_SERVER_DIR}/BepInEx" 2>/dev/null || true
fi
if [ -d "${ASKA_SERVER_DIR}/dotnet" ]; then
  chmod -R u+rwX,go+rX "${ASKA_SERVER_DIR}/dotnet" 2>/dev/null || true
fi

echo "BepInEx installer hook completed successfully."


echo ""
echo "Configuring Wine DLL overrides for BepInEx (winhttp)..."
echo ""

wine reg add "HKCU\\Software\\Wine\\DllOverrides" /v winhttp /d native,builtin /f

echo "DLL overrides configured successfully."

