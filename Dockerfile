FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    HOME=/home/steam \
    USER=steam \
    WINEPREFIX=/home/steam/.wine \
    ASKA_SERVER_DIR=/home/steam/aska_server \
    ASKA_SAVES_DIR=/aska-saves \
    ASKA_APP_ID=1898300 \
    ASKA_STEAM_GAME_PORT=27015 \
    ASKA_STEAM_QUERY_PORT=27016 \
    ASKA_SKIP_STEAM_UPDATE=0

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
      wine \
      winetricks \
      xvfb \
      xauth \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -s /bin/bash steam \
    && mkdir -p "${ASKA_SERVER_DIR}" "${ASKA_SAVES_DIR}" \
    && chown -R steam:steam "${HOME}" "${ASKA_SAVES_DIR}"

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

VOLUME ["/home/steam/aska_server", "/aska-saves", "/home/steam/.wine"]

EXPOSE 27015/udp 27016/udp

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
