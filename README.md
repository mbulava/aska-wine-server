# aska-wine-server

Minimal container setup for running the **ASKA dedicated server** under Wine, with hook points to customize Wine and run **BepInEx-specific install actions**.

## Build

```bash
docker build -t aska-wine-server:local .
```

## Run

```bash
docker run --rm -it \
  -p 27015:27015/udp \
  -p 27016:27016/udp \
  -e ASKA_DISPLAY_NAME="My ASKA Server" \
  -e ASKA_SERVER_NAME="my-server" \
  -e ASKA_AUTH_TOKEN="YOUR_TOKEN_HERE" \
  -v ./server:/home/steam/aska_server \
  -v ./saves:/aska-saves \
  -v ./hooks/wine:/docker-entrypoint-initwine.d:ro \
  -v ./hooks/bepinex:/docker-entrypoint-initbepinex.d:ro \
  aska-wine-server:local
```

## Customization Hooks

The entrypoint runs executable `*.sh` scripts in this order:

1. Steam update/install step (unless `ASKA_SKIP_STEAM_UPDATE=1`)
2. `/docker-entrypoint-initwine.d` (after `wineboot`)
3. `/docker-entrypoint-initbepinex.d` (before server launch)

Both hook stages run in the container with `WINEPREFIX`, `ASKA_SERVER_DIR`, and ASKA env vars available, so custom setup (for example `winetricks` or BepInEx installer actions) can be performed safely before launch.

You can override hook locations with:

- `WINE_HOOK_DIR` (default: `/docker-entrypoint-initwine.d`)
- `BEPINEX_HOOK_DIR` (default: `/docker-entrypoint-initbepinex.d`)

## Example BepInEx Hook

An example installer script is included at:

- `/home/runner/work/aska-wine-server/aska-wine-server/examples/hooks/bepinex/10-install-bepinex.sh`

To use it, copy it to your mounted BepInEx hooks directory and make it executable:

```bash
cp /home/runner/work/aska-wine-server/aska-wine-server/examples/hooks/bepinex/10-install-bepinex.sh ./hooks/bepinex/
chmod +x ./hooks/bepinex/10-install-bepinex.sh
```

Then set:

- `BEPINEX_ENABLED=1`
- `BEPINEX_URL=<direct-download-url-to-a-bepinex-zip>`
- Optional: `BEPINEX_SHA256=<sha256>`
- Optional: `BEPINEX_POST_INSTALL_CMD=<custom command>` for extra install actions required by your setup