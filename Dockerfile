# =============================================================================
#  SAN ANDREAS RP — Multi-Stage Dockerfile (open.mp v1.6.7+ & Pawn Compiler)
#  Stage 1 (builder): Компиляция gamemodes/main.pwn -> gamemodes/main.amx (-O2 -d1)
#                     с проверкой кодировки Windows-1251 (CP1251) и 0 warnings.
#  Stage 2 (runtime): Минимальный изолированный образ Debian Bookworm Slim
#                     с 32-битными рантайм-библиотеками (i386) и запуском
#                     от непривилегированного пользователя ompuser (UID 1000).
# =============================================================================

# -----------------------------------------------------------------------------
#  STAGE 1: BUILDER (Компиляция Pawn-мода и валидация CP1251)
# -----------------------------------------------------------------------------
FROM debian:bookworm-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        coreutils \
        findutils \
        grep \
        libc-bin \
        libc6:i386 \
        libgcc-s1:i386 \
        libstdc++6:i386 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

COPY build.sh ./build.sh
COPY qawno ./qawno
COPY gamemodes ./gamemodes

RUN chmod +x ./build.sh ./qawno/pawncc \
    && ./build.sh \
    && test -s /build/gamemodes/main.amx

# -----------------------------------------------------------------------------
#  STAGE 2: RUNTIME (Чистый продакшн-образ без исходников .pwn и компилятора)
# -----------------------------------------------------------------------------
FROM debian:bookworm-slim AS runtime

ENV DEBIAN_FRONTEND=noninteractive \
    SARP_APP_DIR=/opt/omp-server

RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        jq \
        mariadb-client \
        tzdata \
        libc6:i386 \
        libgcc-s1:i386 \
        libstdc++6:i386 \
        libatomic1:i386 \
        libmariadb3:i386 \
        libssl3:i386 \
        zlib1g:i386 \
    && rm -rf /var/lib/apt/lists/*

# Создание непривилегированного пользователя ompuser (UID/GID 1000)
RUN groupadd --gid 1000 ompuser \
    && useradd --uid 1000 --gid 1000 --create-home --home-dir /opt/omp-server --shell /bin/bash ompuser

WORKDIR /opt/omp-server

# Копирование только рантайм-артефактов (без .pwn исходников и qawno/)
COPY --chown=ompuser:ompuser omp-server ./omp-server
COPY --chown=ompuser:ompuser log-core.so ./log-core.so
COPY --chown=ompuser:ompuser components ./components
COPY --chown=ompuser:ompuser plugins ./plugins
COPY --chown=ompuser:ompuser models ./models
COPY --chown=ompuser:ompuser scriptfiles ./scriptfiles
COPY --chown=ompuser:ompuser filterscripts ./filterscripts
COPY --chown=ompuser:ompuser npcmodes ./npcmodes
COPY --chown=ompuser:ompuser bans.json ./bans.json
COPY --chown=ompuser:ompuser config.json ./config.json
COPY --chown=ompuser:ompuser config.json ./config.template.json
COPY --chown=ompuser:ompuser deploy ./deploy
COPY --chown=ompuser:ompuser docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# Копирование скомпилированного байткода main.amx из стадии builder
COPY --from=builder --chown=ompuser:ompuser /build/gamemodes/main.amx ./gamemodes/main.amx

RUN chmod +x /opt/omp-server/omp-server \
             /opt/omp-server/deploy/*.sh \
             /usr/local/bin/docker-entrypoint.sh \
    && mkdir -p /opt/omp-server/logs /opt/omp-server/scriptfiles/backups /backups \
    && chown -R ompuser:ompuser /opt/omp-server /backups

USER ompuser

EXPOSE 7777/udp 7777/tcp

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["./omp-server"]
