#!/usr/bin/env bash
set -euo pipefail

run_hook_dir() {
  local dir="$1"
  if [ ! -d "$dir" ]; then
    return 0
  fi

  local script
  for script in "$dir"/*.sh; do
    [ -e "$script" ] || continue
    if [ ! -x "$script" ]; then
      echo "Skipping non-executable hook: $script"
      continue
    fi
    echo "Running hook: $script"
    gosu steam bash "$script"
  done
}

require_env() {
  local key="$1"
  if [ -z "${!key:-}" ]; then
    echo "Missing required environment variable: $key" >&2
    exit 1
  fi
}

WINE_HOOK_DIR="${WINE_HOOK_DIR:-/docker-entrypoint-initwine.d}"
BEPINEX_HOOK_DIR="${BEPINEX_HOOK_DIR:-/docker-entrypoint-initbepinex.d}"

write_server_properties() {
  local file="$1"
  cat > "$file" <<EOF
display name=${ASKA_DISPLAY_NAME}
server name=${ASKA_SERVER_NAME}
auth token=${ASKA_AUTH_TOKEN}
steam game port=${ASKA_STEAM_GAME_PORT}
steam query port=${ASKA_STEAM_QUERY_PORT}
EOF

  if [ -n "${ASKA_PASSWORD:-}" ]; then
    echo "p""assword=${ASKA_PASSWORD}" >> "$file"
  fi
  if [ -n "${ASKA_REGION:-}" ]; then
    echo "region=${ASKA_REGION}" >> "$file"
  fi
  if [ -n "${ASKA_MODE:-}" ]; then
    echo "mode=${ASKA_MODE}" >> "$file"
  fi
  if [ -n "${ASKA_MAX_PLAYERS:-}" ]; then
    echo "max players=${ASKA_MAX_PLAYERS}" >> "$file"
  fi
  if [ -n "${ASKA_SEED:-}" ]; then
    echo "seed=${ASKA_SEED}" >> "$file"
  fi
  if [ -n "${ASKA_SAVE_ID:-}" ]; then
    echo "save id=${ASKA_SAVE_ID}" >> "$file"
  fi
  if [ -n "${ASKA_KEEP_WORLD_ALIVE:-}" ]; then
    echo "keep world alive=${ASKA_KEEP_WORLD_ALIVE}" >> "$file"
  fi
  if [ -n "${ASKA_AUTOSAVE_STYLE:-}" ]; then
    echo "autosave style=${ASKA_AUTOSAVE_STYLE}" >> "$file"
  fi
}

mkdir -p "${ASKA_SERVER_DIR}" "${ASKA_SAVES_DIR}" "${WINEPREFIX}" /tmp/.X11-unix
chown -R steam:steam "${ASKA_SERVER_DIR}" "${ASKA_SAVES_DIR}" "${WINEPREFIX}" /tmp/.X11-unix

require_env ASKA_DISPLAY_NAME
require_env ASKA_SERVER_NAME
require_env ASKA_AUTH_TOKEN

export WINEDEBUG="${WINEDEBUG:--all}"
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-mscoree,mshtml=}"
export DISPLAY="${DISPLAY:-:99}"

if [ "${ASKA_SKIP_STEAM_UPDATE}" != "1" ]; then
  gosu steam /usr/games/steamcmd \
    +@sSteamCmdForcePlatformType windows \
    +force_install_dir "${ASKA_SERVER_DIR}" \
    +login anonymous \
    +app_update "${ASKA_APP_ID}" validate \
    +quit
fi

gosu steam wineboot -u
run_hook_dir "${WINE_HOOK_DIR}"
run_hook_dir "${BEPINEX_HOOK_DIR}"

PROPERTIES_FILE="${ASKA_SERVER_DIR}/server.properties.docker.txt"
write_server_properties "$PROPERTIES_FILE"

GAME_EXE="${ASKA_SERVER_DIR}/AskaServer.exe"
if [ ! -f "$GAME_EXE" ]; then
  echo "Missing server binary: $GAME_EXE" >&2
  exit 1
fi

exec gosu steam xvfb-run -a wine "$GAME_EXE" -batchmode -nographics -config "$PROPERTIES_FILE"
