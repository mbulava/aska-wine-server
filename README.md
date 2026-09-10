# aska-wine-server

Minimal container setup for running the **ASKA dedicated server** under Wine, with hook points to customize Wine and run **BepInEx-specific install actions**.

## Quick Start (Pre-built Image)

Pull and run the pre-built image from GitHub Container Registry:

```bash
docker run --rm -it \
  -p 27015:27015/udp \
  -p 27016:27016/udp \
  -e ASKA_DISPLAY_NAME="My ASKA Server" \
  -e ASKA_SERVER_NAME="my-server" \
  -e ASKA_AUTH_TOKEN="YOUR_TOKEN_HERE" \
  -v ./server:/home/steam/aska_server \
  -v ./saves:/aska-saves \
  ghcr.io/mbulava/aska-wine-server:latest
```

## Build Locally

```bash
docker build -t aska-wine-server:local .
```

To run your local build:

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

## BepInEx Support

The container includes built-in support for BepInEx. To enable it, pass `BEPINEX_ENABLED=1`:

```bash
docker run --rm -it \
  -p 27015:27015/udp \
  -p 27016:27016/udp \
  -e ASKA_DISPLAY_NAME="My ASKA Server" \
  -e ASKA_SERVER_NAME="my-server" \
  -e ASKA_AUTH_TOKEN="YOUR_TOKEN_HERE" \
  -e BEPINEX_ENABLED=1 \
  -v ./server:/home/steam/aska_server \
  -v ./saves:/aska-saves \
  aska-wine-server:local
```

When `BEPINEX_ENABLED=1`:
1. The Wine DLL override for `winhttp` (`native,builtin`) is configured automatically:
   ```bash
   wine reg add "HKCU\Software\Wine\DllOverrides" /v winhttp /d native,builtin /f
   ```
2. The packaged BepInEx Windows archive (`/docker/BepInEx/ASKA BEPINEX - WINDOWS VERSION-66-V2-0-0-1773857940.zip`) is extracted directly into `ASKA_SERVER_DIR` (only overwriting target files if newer).
3. The installation script is located at `scripts/10-install-bepinex.sh` and executed automatically before server launch.

Optional environment variables:
- `BEPINEX_ZIP=<custom-path-to-bepinex-zip>` (overrides default package location)
- `BEPINEX_POST_INSTALL_CMD=<custom command>` (extra install actions required by your setup)