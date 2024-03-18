FROM ubuntu:20.04

# see https://github.com/moby/moby/issues/4032#issuecomment-192327844
ARG DEBIAN_FRONTEND=noninteractive

# ARG for quick switch to a given ubuntu mirror
ARG apt_archive="http://archive.ubuntu.com"

# user/group precreated explicitly with fixed uid/gid on purpose.
# It is especially important for rootless containers: in that case entrypoint
# can't do chown and owners of mounted volumes should be configured externally.
# We do that in advance at the begining of Dockerfile before any packages will be
# installed to prevent picking those uid / gid by some unrelated software.
# The same uid / gid (101) is used both for alpine and ubuntu.
RUN sed -i "s|http://archive.ubuntu.com|${apt_archive}|g" /etc/apt/sources.list \
    && groupadd -r clickhouse --gid=101 \
    && useradd -r -g clickhouse --uid=101 --home-dir=/var/lib/clickhouse --shell=/bin/bash clickhouse \
    && apt-get update \
    && apt-get upgrade -yq \
    && apt-get install --yes --no-install-recommends \
        ca-certificates \
        locales \
        tzdata \
        wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/debconf /tmp/*

ARG REPO_CHANNEL="stable"
ARG REPOSITORY="deb [signed-by=/usr/share/keyrings/clickhouse-keyring.gpg] https://packages.clickhouse.com/deb ${REPO_CHANNEL} main"
ARG VERSION="24.2.2.71"
ARG PACKAGES="clickhouse-client clickhouse-server clickhouse-common-static"

# set non-empty deb_location_url url to create a docker image
# from debs created by CI build, for example:
# docker build . --network host --build-arg version="21.4.1.6282" --build-arg deb_location_url="https://..." -t ...
ARG deb_location_url=""
ARG DIRECT_DOWNLOAD_URLS=""

# set non-empty single_binary_location_url to create docker image
# from a single binary url (useful for non-standard builds - with sanitizers, for arm64).
ARG single_binary_location_url=""

ARG TARGETARCH

# install from direct URL
RUN if [ -n "${DIRECT_DOWNLOAD_URLS}" ]; then \
        echo "installing from custom predefined urls with deb packages: ${DIRECT_DOWNLOAD_URLS}" \
        && rm -rf /tmp/clickhouse_debs \
        && mkdir -p /tmp/clickhouse_debs \
        && for url in $DIRECT_DOWNLOAD_URLS; do \
            wget --progress=bar:force:noscroll "$url" -P /tmp/clickhouse_debs || exit 1 \
        ; done \
        && dpkg -i /tmp/clickhouse_debs/*.deb \
        && rm -rf /tmp/* ; \
    fi

# install from a web location with deb packages
RUN arch="${TARGETARCH:-amd64}" \
    && if [ -n "${deb_location_url}" ]; then \
        echo "installing from custom url with deb packages: ${deb_location_url}" \
        && rm -rf /tmp/clickhouse_debs \
        && mkdir -p /tmp/clickhouse_debs \
        && for package in ${PACKAGES}; do \
            { wget --progress=bar:force:noscroll "${deb_location_url}/${package}_${VERSION}_${arch}.deb" -P /tmp/clickhouse_debs || \
                wget --progress=bar:force:noscroll "${deb_location_url}/${package}_${VERSION}_all.deb" -P /tmp/clickhouse_debs ; } \
            || exit 1 \
        ; done \
        && dpkg -i /tmp/clickhouse_debs/*.deb \
        && rm -rf /tmp/* ; \
    fi

# install from a single binary
RUN if [ -n "${single_binary_location_url}" ]; then \
        echo "installing from single binary url: ${single_binary_location_url}" \
        && rm -rf /tmp/clickhouse_binary \
        && mkdir -p /tmp/clickhouse_binary \
        && wget --progress=bar:force:noscroll "${single_binary_location_url}" -O /tmp/clickhouse_binary/clickhouse \
        && chmod +x /tmp/clickhouse_binary/clickhouse \
        && /tmp/clickhouse_binary/clickhouse install --user "clickhouse" --group "clickhouse" \
        && rm -rf /tmp/* ; \
    fi

# A fallback to installation from ClickHouse repository
RUN if ! clickhouse local -q "SELECT ''" > /dev/null 2>&1; then \
        apt-get update \
        && apt-get install --yes --no-install-recommends \
            apt-transport-https \
            ca-certificates \
            dirmngr \
            gnupg2 \
        && mkdir -p /etc/apt/sources.list.d \
        && GNUPGHOME=$(mktemp -d) \
        && GNUPGHOME="$GNUPGHOME" gpg --no-default-keyring \
            --keyring /usr/share/keyrings/clickhouse-keyring.gpg \
            --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 8919F6BD2B48D754 \
        && rm -rf "$GNUPGHOME" \
        && chmod +r /usr/share/keyrings/clickhouse-keyring.gpg \
        && echo "${REPOSITORY}" > /etc/apt/sources.list.d/clickhouse.list \
        && echo "installing from repository: ${REPOSITORY}" \
        && apt-get update \
        && for package in ${PACKAGES}; do \
            packages="${packages} ${package}=${VERSION}" \
        ; done \
        && apt-get install --allow-unauthenticated --yes --no-install-recommends ${packages} || exit 1 \
        && rm -rf \
            /var/lib/apt/lists/* \
            /var/cache/debconf \
            /tmp/* \
        && apt-get autoremove --purge -yq libksba8 \
        && apt-get autoremove -yq \
    ; fi

# post install
# we need to allow "others" access to clickhouse folder, because docker container
# can be started with arbitrary uid (openshift usecase)
RUN clickhouse-local -q 'SELECT * FROM system.build_options' \
    && mkdir -p /var/lib/clickhouse /var/log/clickhouse-server /etc/clickhouse-server /etc/clickhouse-client \
    && chmod ugo+Xrw -R /var/lib/clickhouse /var/log/clickhouse-server /etc/clickhouse-server /etc/clickhouse-client

RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
ENV TZ UTC

RUN mkdir /docker-entrypoint-initdb.d

COPY ./config_files/docker_related_config.xml /etc/clickhouse-server/config.d/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 9000 8123 9009
VOLUME /var/lib/clickhouse

ARG CLICKHOUSE_DB
ARG CLICKHOUSE_USER
ARG CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT
ARG CLICKHOUSE_PASSWORD


ENV CLICKHOUSE_CONFIG /etc/clickhouse-server/config.xml

ENTRYPOINT ["/entrypoint.sh"]