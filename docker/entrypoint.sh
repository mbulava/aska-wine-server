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

resolve_save_id() {
  local save_id="${ASKA_SAVE_ID:-}"

  if [ "${ASKA_RESET_WORLD:-0}" = "1" ] || [ "${ASKA_FORCE_NEW_WORLD:-0}" = "1" ]; then
    >&2 echo "ASKA_RESET_WORLD is set. Starting a fresh world (ignoring existing saves)."
    echo ""
    return 0
  fi

  if [ -n "${save_id}" ]; then
    echo "${save_id}"
    return 0
  fi

  # 1. Check previous properties files in server directory
  for prop_file in "${ASKA_SERVER_DIR}/server properties.txt" "${ASKA_SERVER_DIR}/server.properties.docker.txt" "${ASKA_SERVER_DIR}/server.properties.txt"; do
    if [ -f "$prop_file" ]; then
      local extracted
      extracted="$(grep -Ei '^\s*save id\s*=' "$prop_file" 2>/dev/null | tail -n 1 | cut -d'=' -f2- | tr -d '\r\n ' || true)"
      if [ -n "${extracted}" ]; then
        >&2 echo "Auto-detected existing save id '${extracted}' from ${prop_file}"
        echo "${extracted}"
        return 0
      fi
    fi
  done

  # 2. Check for existing save directories in ASKA_SAVES_DIR
  if [ -d "${ASKA_SAVES_DIR}" ]; then
    local latest_save
    latest_save="$(find "${ASKA_SAVES_DIR}" -mindepth 1 -maxdepth 2 -type d ! -path '*/.*' 2>/dev/null | while read -r d; do
      printf "%s\t%s\n" "$(stat -c %Y "$d" 2>/dev/null || echo 0)" "$(basename "$d")"
    done | sort -nr | head -n 1 | cut -f2 || true)"
    if [ -n "${latest_save}" ]; then
      >&2 echo "Auto-detected latest existing world save '${latest_save}' from ${ASKA_SAVES_DIR}"
      echo "${latest_save}"
      return 0
    fi
  fi

  echo ""
}

write_server_properties() {
  local file="$1"
  local display_name="${ASKA_DISPLAY_NAME}"
  local server_name="${ASKA_SERVER_NAME}"
  local auth_token="${ASKA_AUTH_TOKEN}"
  local game_port="${ASKA_STEAM_GAME_PORT:-27015}"
  local query_port="${ASKA_STEAM_QUERY_PORT:-27016}"
  local region="${ASKA_REGION:-usa west}"
  local mode="${ASKA_MODE:-normal}"
  local max_players="${ASKA_MAX_PLAYERS:-4}"
  local keep_world_alive="${ASKA_KEEP_WORLD_ALIVE:-false}"
  local autosave_style="${ASKA_AUTOSAVE_STYLE:-every morning}"
  local save_id
  save_id="$(resolve_save_id)"

  cat > "$file" <<EOF
display name=${display_name}
server name=${server_name}
authentication token=${auth_token}
auth token=${auth_token}
steam game port=${game_port}
steam query port=${query_port}
region=${region}
mode=${mode}
max players=${max_players}
keep world alive=${keep_world_alive}
autosave style=${autosave_style}
EOF

  if [ -n "${ASKA_PASSWORD:-}" ]; then
    echo "password=${ASKA_PASSWORD}" >> "$file"
  fi
  if [ -n "${ASKA_SEED:-}" ]; then
    echo "seed=${ASKA_SEED}" >> "$file"
  fi
  if [ -n "${save_id}" ]; then
    echo "save id=${save_id}" >> "$file"
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
export SteamAppId="${ASKA_GAME_APP_ID:-1898300}"

if [ "${ASKA_SKIP_STEAM_UPDATE}" != "1" ]; then
  echo "Installing / Updating ASKA server via SteamCMD (App ID: ${ASKA_APP_ID})..."
  gosu steam /usr/games/steamcmd \
    +@sSteamCmdForcePlatformType windows \
    +force_install_dir "${ASKA_SERVER_DIR}" \
    +login anonymous \
    +app_update "${ASKA_APP_ID}" validate \
    +quit
fi

gosu steam wineboot -u

# Ensure Wine AppData save path links to the persistent ASKA_SAVES_DIR volume
APPDATA_LOCALLOW="${WINEPREFIX}/drive_c/users/steam/AppData/LocalLow"
mkdir -p "${APPDATA_LOCALLOW}/SandSailorStudio" "${ASKA_SAVES_DIR}"
if [ ! -e "${APPDATA_LOCALLOW}/SandSailorStudio/Aska" ]; then
  ln -sf "${ASKA_SAVES_DIR}" "${APPDATA_LOCALLOW}/SandSailorStudio/Aska"
fi
chown -R steam:steam "${ASKA_SAVES_DIR}" "${WINEPREFIX}"

run_hook_dir "${WINE_HOOK_DIR}"
run_hook_dir "${BEPINEX_HOOK_DIR}"

PROPERTIES_FILE="${ASKA_SERVER_DIR}/server.properties.docker.txt"
write_server_properties "$PROPERTIES_FILE"
write_server_properties "${ASKA_SERVER_DIR}/server properties.txt"

GAME_EXE="${ASKA_SERVER_DIR}/AskaServer.exe"
if [ ! -f "$GAME_EXE" ]; then
  # Fallback search if binary is located in a subdirectory
  FOUND_EXE="$(find "${ASKA_SERVER_DIR}" -maxdepth 2 -iname "*Aska*Server*.exe" | head -n 1 || true)"
  if [ -n "${FOUND_EXE}" ] && [ -f "${FOUND_EXE}" ]; then
    GAME_EXE="${FOUND_EXE}"
  else
    echo "Missing server binary: $GAME_EXE" >&2
    exit 1
  fi
fi

cd "${ASKA_SERVER_DIR}"
echo "Starting ASKA Server via Wine (${GAME_EXE})..."
exec gosu steam xvfb-run -a wine "$GAME_EXE" -batchmode -nographics -logFile - -propertiesPath "server properties.txt" -config "$PROPERTIES_FILE"


