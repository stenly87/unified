# This image is for users who wish to build their images themselves. It uses the builder factory that is created
# via the builder.Dockerfile

FROM nwnxee/builder as builder
WORKDIR /nwnx/home
COPY ./ .
# Compile nwnx
ARG CC=gcc
ENV CC=$CC
ARG CXX=g++
ENV CXX=$CXX
RUN Scripts/buildnwnx.sh -j $(nproc)

FROM beamdog/nwserver:8193.16
RUN mkdir -p /nwn/nwnx
COPY --from=builder /nwnx/home/Binaries/* /nwn/nwnx/

# Install plugin run dependencies
RUN runDeps="hunspell \
    libmariadb3 \
    libpq5 \
    libsqlite3-0 \
    libruby2.5 \
    luajit libluajit-5.1 \
    libssl1.1 \
    inotify-tools \
    patch \
    unzip \
    dotnet-runtime-5.0 \
    dotnet-apphost-pack-5.0" \
    installDeps="ca-certificates wget" \
    && apt-get update \
    && apt-get install -y --no-install-recommends $installDeps \
    && wget https://packages.microsoft.com/config/debian/10/packages-microsoft-prod.deb -O packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get -y install --no-install-recommends $runDeps \
    && rm -rf /var/cache/apt /var/lib/apt/lists/*

# Patch run-server.sh with our modifications
COPY --from=builder /nwnx/home/Scripts/Docker/run-server.patch /nwn/
RUN patch /nwn/run-server.sh < /nwn/run-server.patch

# Configure nwserver to run with nwnx
ENV NWNX_CORE_LOAD_PATH=/nwn/nwnx/
ENV NWN_LD_PRELOAD="/nwn/nwnx/NWNX_Core.so"
# Use NWNX_ServerLogRedirector as default log manager
ENV NWNX_SERVERLOGREDIRECTOR_SKIP=n \
    NWN_TAIL_LOGS=n \
    NWNX_CORE_LOG_LEVEL=6 \
    NWNX_SERVERLOGREDIRECTOR_LOG_LEVEL=6
# Disable all other plugins by default.
ENV NWNX_CORE_SKIP_ALL=y
