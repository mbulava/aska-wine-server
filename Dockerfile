FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    HOME=/home/steam \
    USER=steam \
    WINEPREFIX=/home/steam/.wine \
    ASKA_SERVER_DIR=/home/steam/aska_server \
    ASKA_SAVES_DIR=/aska-saves \
    ASKA_APP_ID=3246670 \
    ASKA_STEAM_GAME_PORT=27015 \
    ASKA_STEAM_QUERY_PORT=27016 \
    ASKA_SKIP_STEAM_UPDATE=0 \
    BEPINEX_ENABLED=0

RUN dpkg --add-architecture i386 \
    && sed -i 's/^Components: main$/Components: main universe multiverse/' /etc/apt/sources.list.d/ubuntu.sources \
    && apt-get update \
    && echo "steam steam/question select I AGREE" | debconf-set-selections \
    && echo "steam steam/license note ''" | debconf-set-selections \
    && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      gosu \
      steamcmd \
      tini \
      unzip \
      wine \
      winetricks \
      xvfb \
      xauth \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -s /bin/bash steam \
    && mkdir -p "${ASKA_SERVER_DIR}" "${ASKA_SAVES_DIR}" /docker-entrypoint-initwine.d /docker-entrypoint-initbepinex.d /docker/BepInEx "${HOME}/.steam" "${HOME}/Steam" \
    && chown -R steam:steam "${HOME}" "${ASKA_SAVES_DIR}" \
    && gosu steam /usr/games/steamcmd +quit || true \
    && rm -rf "${HOME}/Steam/logs" "${HOME}/.steam/logs"

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY docker/BepInEx /docker/BepInEx
COPY scripts/ /docker-entrypoint-initbepinex.d/

RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh \
    && chmod +x /usr/local/bin/entrypoint.sh \
    && sed -i 's/\r$//' /docker-entrypoint-initbepinex.d/*.sh \
    && chmod +x /docker-entrypoint-initbepinex.d/*.sh

VOLUME ["/home/steam/aska_server", "/aska-saves", "/home/steam/.wine", "/home/steam/.steam"]


EXPOSE 27015/udp 27016/udp

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
