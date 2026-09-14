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

set_property() {
  local file="$1"
  local key="$2"
  local val="$3"

  export _KEY="$key"
  export _VAL="$val"

  awk '
    BEGIN {
      k = ENVIRON["_KEY"]
      v = ENVIRON["_VAL"]
      IGNORECASE = 1
    }
    $0 ~ ("^[[:space:]]*" k "[[:space:]]*=") {
      print k "=" v
      next
    }
    { print }
  ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"

  if ! grep -qiE "^[[:space:]]*${key}[[:space:]]*=" "$file"; then
    echo "${key}=${val}" >> "$file"
  fi
}

write_server_properties() {
  local target_file="$1"
  local base_file="${ASKA_SERVER_DIR}/server properties.txt"

  # If base server properties.txt exists and target is different, copy it as baseline
  if [ -f "$base_file" ] && [ "$base_file" != "$target_file" ]; then
    cp -f "$base_file" "$target_file"
  elif [ ! -f "$target_file" ]; then
    cat > "$target_file" <<'EOF'
# ASKA Dedicated Server Properties
display name=
server name=
authentication token=
steam game port=27015
steam query port=27016
region=usa west
mode=normal
max players=4
keep world alive=false
autosave style=every morning
EOF
  fi

  # Fill in required and configured properties
  local clean_token
  clean_token="$(echo "${ASKA_AUTH_TOKEN}" | tr -d '\r\n"' | xargs)"

  set_property "$target_file" "display name" "${ASKA_DISPLAY_NAME}"
  set_property "$target_file" "server name" "${ASKA_SERVER_NAME}"
  set_property "$target_file" "authentication token" "${clean_token}"
  set_property "$target_file" "steam game port" "${ASKA_STEAM_GAME_PORT:-27015}"
  set_property "$target_file" "steam query port" "${ASKA_STEAM_QUERY_PORT:-27016}"

  if [ -n "${ASKA_REGION:-}" ]; then
    set_property "$target_file" "region" "${ASKA_REGION}"
  fi
  if [ -n "${ASKA_MODE:-}" ]; then
    set_property "$target_file" "mode" "${ASKA_MODE}"
  fi
  if [ -n "${ASKA_MAX_PLAYERS:-}" ]; then
    set_property "$target_file" "max players" "${ASKA_MAX_PLAYERS}"
  fi
  if [ -n "${ASKA_KEEP_WORLD_ALIVE:-}" ]; then
    set_property "$target_file" "keep world alive" "${ASKA_KEEP_WORLD_ALIVE}"
  fi
  if [ -n "${ASKA_AUTOSAVE_STYLE:-}" ]; then
    set_property "$target_file" "autosave style" "${ASKA_AUTOSAVE_STYLE}"
  fi
  if [ -n "${ASKA_PASSWORD:-}" ]; then
    set_property "$target_file" "password" "${ASKA_PASSWORD}"
  fi
  if [ -n "${ASKA_SEED:-}" ]; then
    set_property "$target_file" "seed" "${ASKA_SEED}"
  fi

  local save_id
  save_id="$(resolve_save_id)"
  if [ -n "${save_id}" ]; then
    set_property "$target_file" "save id" "${save_id}"
  fi
}


LOGS_DIR="${ASKA_SERVER_DIR}/logs"
mkdir -p "${ASKA_SERVER_DIR}" "${LOGS_DIR}" "${LOGS_DIR}/steam" "${LOGS_DIR}/bepinex" "${ASKA_SAVES_DIR}" "${WINEPREFIX}" "${HOME}/.steam" "${HOME}/Steam" /tmp/.X11-unix

# Link Steam logs to ASKA_SERVER_DIR/logs/steam
ln -sfn "${LOGS_DIR}/steam" "${HOME}/.steam/logs" 2>/dev/null || true
ln -sfn "${LOGS_DIR}/steam" "${HOME}/Steam/logs" 2>/dev/null || true

chown -R steam:steam "${HOME}" "${ASKA_SERVER_DIR}" "${ASKA_SAVES_DIR}" "${WINEPREFIX}" /tmp/.X11-unix
chmod -R u+rwX,go+rX "${HOME}" "${ASKA_SERVER_DIR}" "${ASKA_SAVES_DIR}" "${WINEPREFIX}" /tmp/.X11-unix 2>/dev/null || true

require_env ASKA_DISPLAY_NAME
require_env ASKA_SERVER_NAME
require_env ASKA_AUTH_TOKEN

export WINEDEBUG="${WINEDEBUG:--all}"
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-mscoree,mshtml=}"
# Clean up any stale X locks
rm -f /tmp/.X99-lock /tmp/.X11-unix/X99 2>/dev/null || true

# Start Xvfb virtual display with 24-bit color depth required by Unity under Wine
Xvfb :99 -screen 0 1024x768x24 -nolisten tcp &
XVFB_PID=$!

export DISPLAY=:99

# Ensure Xvfb is terminated when the container stops
trap "kill -TERM $XVFB_PID 2>/dev/null || true" EXIT

# Runtime game App ID for Steamworks GSLT validation (Client App ID is 1898300)
ASKA_GAME_APP_ID="${ASKA_GAME_APP_ID:-1898300}"
export SteamAppId="${ASKA_GAME_APP_ID}"
export SteamGameId="${ASKA_GAME_APP_ID}"

if [ "${ASKA_SKIP_STEAM_UPDATE}" != "1" ]; then
  echo "Checking for ASKA server updates via SteamCMD (App ID: ${ASKA_APP_ID})..."
  VALIDATE_FLAG=""
  if [ "${ASKA_VALIDATE_STEAM_FILES:-0}" = "1" ] || [ ! -f "${ASKA_SERVER_DIR}/AskaServer.exe" ]; then
    VALIDATE_FLAG="validate"
  fi

  gosu steam /usr/games/steamcmd \
    +@sSteamCmdForcePlatformType windows \
    +force_install_dir "${ASKA_SERVER_DIR}" \
    +login anonymous \
    +app_update "${ASKA_APP_ID}" ${VALIDATE_FLAG} \
    +quit
fi

echo "Setting up wine, this will take some time..."
echo "Container path '/home/steam/.wine' should be persisted to a volume, or you're going to see this a lot..."
echo ""

gosu steam wineboot -u

# Ensure Wine AppData save path links to the persistent ASKA_SAVES_DIR volume
APPDATA_LOCALLOW="${WINEPREFIX}/drive_c/users/steam/AppData/LocalLow"
mkdir -p "${APPDATA_LOCALLOW}/Sand Sailor Studio" "${ASKA_SAVES_DIR}"
if [ ! -e "${APPDATA_LOCALLOW}/Sand Sailor Studio/Aska" ]; then
  ln -sf "${ASKA_SAVES_DIR}" "${APPDATA_LOCALLOW}/Sand Sailor Studio/Aska"
fi
chown -R steam:steam "${ASKA_SAVES_DIR}" "${WINEPREFIX}"

echo "Storage redirection: '${APPDATA_LOCALLOW}/Sand Sailor Studio/Aska' to '${ASKA_SAVES_DIR}' for local saves."
echo ""


run_hook_dir "${WINE_HOOK_DIR}"
echo "wine init completed"
echo ""

echo "Running BepInEx and post install hooks"

run_hook_dir "${BEPINEX_HOOK_DIR}"

echo "BepInEx and post install hooks completed"


PROPERTIES_FILE="${ASKA_SERVER_DIR}/server.properties.docker.txt"
write_server_properties "$PROPERTIES_FILE"
cp -f "$PROPERTIES_FILE" "${ASKA_SERVER_DIR}/server properties.txt"

# Set steam_appid.txt to base game App ID (1898300) so Steamworks matches the GSLT token
echo "${ASKA_GAME_APP_ID}" > "${ASKA_SERVER_DIR}/steam_appid.txt"
chown steam:steam "${ASKA_SERVER_DIR}/steam_appid.txt"


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

# Link Unity Player.log into ASKA_SERVER_DIR/logs if present
if [ -d "${APPDATA_LOCALLOW}/Sand Sailor Studio/Aska" ]; then
  ln -sfn "${APPDATA_LOCALLOW}/Sand Sailor Studio/Aska/Player.log" "${LOGS_DIR}/Player.log" 2>/dev/null || true
  ln -sfn "${APPDATA_LOCALLOW}/Sand Sailor Studio/Aska/Player-prev.log" "${LOGS_DIR}/Player-prev.log" 2>/dev/null || true
fi

# Final permissions and ownership check to ensure steam user can access all files/plugins
chown -R steam:steam "${ASKA_SERVER_DIR}" "${ASKA_SAVES_DIR}" "${WINEPREFIX}" 2>/dev/null || true
chmod -R u+rwX,go+rX "${ASKA_SERVER_DIR}" "${ASKA_SAVES_DIR}" "${WINEPREFIX}" 2>/dev/null || true

cd "${ASKA_SERVER_DIR}"
echo "Starting ASKA Server via Wine (${GAME_EXE})..."


exec gosu steam bash -c "export DISPLAY=:99; wine \"$GAME_EXE\" -batchmode -nographics -logFile - -propertiesPath \"server properties.txt\" 2>&1 "





