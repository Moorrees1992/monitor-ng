# syntax=docker/dockerfile:1

ARG DEBIAN_VERSION=bookworm

FROM debian:${DEBIAN_VERSION}-slim AS build

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install --no-install-recommends --yes \
        build-essential \
        cmake \
        sox \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . .

RUN cmake -S . -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DPULSE_AUDIO_SUPPORT=OFF \
        -DSDL3_SCOPE=OFF \
        -DX11_SUPPORT=OFF \
    && cmake --build build --parallel

# Windows checkouts can carry CRLF line endings even though the test suite is
# executed in Linux. Normalize the shell files inside the disposable build stage.
RUN sed -i 's/\r$//' test/run_tests.sh test/lib/*.sh \
    && ./test/run_tests.sh
RUN cmake --install build


FROM debian:${DEBIAN_VERSION}-slim AS runtime

ARG BUILD_DATE
ARG SOURCE_URL="https://github.com/EliasOenal/multimon-ng"
ARG VERSION="1.6.0"
ARG VCS_REF

LABEL org.opencontainers.image.title="multimon-ng" \
      org.opencontainers.image.description="Digital radio transmission mode decoder" \
      org.opencontainers.image.licenses="GPL-2.0-or-later" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.source="${SOURCE_URL}" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}"

ARG DEBIAN_FRONTEND=noninteractive

# SoX is a runtime dependency for non-raw inputs. The base and MP3 format
# packages cover the formats advertised by multimon-ng without audio servers.
RUN apt-get update \
    && apt-get install --no-install-recommends --yes \
        libsox-fmt-base \
        libsox-fmt-mp3 \
        sox \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/local/ /usr/local/

RUN mkdir /data \
    && chown 65532:65532 /data

WORKDIR /data
USER 65532:65532

ENTRYPOINT ["/usr/local/bin/multimon-ng"]
CMD ["-"]
