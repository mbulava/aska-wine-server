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

1. `/docker-entrypoint-initwine.d` (after `wineboot`, before Steam update)
2. `/docker-entrypoint-initbepinex.d` (after Steam update, before server launch)

Both hook stages run in the container with `WINEPREFIX`, `ASKA_SERVER_DIR`, and ASKA env vars available, so custom setup (for example `winetricks` or BepInEx installer actions) can be performed safely before launch.

You can override hook locations with:

- `WINE_HOOK_DIR` (default: `/docker-entrypoint-initwine.d`)
- `BEPINEX_HOOK_DIR` (default: `/docker-entrypoint-initbepinex.d`)