FROM postgres:17-bookworm AS builder

ENV POSTGRESQL_VERSION=17
ENV PGVECTOR_VERSION=0.8.0
ENV PGVECTORSCALE_VERSION=0.8.0
ENV SAFEUPDATE_URL=https://github.com/eradman/pg-safeupdate/archive/master.tar.gz

RUN apt update && \
    apt-get install -y \
    clang \
    curl \
    g++ \
    gcc \
    git \
    libclang-dev \
    libpq-dev \
    postgresql-${POSTGRESQL_VERSION} \
    postgresql-server-dev-${POSTGRESQL_VERSION} \
    make \
    zlib1g \
    zlib1g-dev \
    pkg-config \
    libssl-dev \
    ca-certificates \
    jq \
    wget
# install prerequisites
## rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
# build pgvectorscale
RUN cd /tmp && git clone --branch ${PGVECTORSCALE_VERSION} https://github.com/timescale/pgvectorscale && \
  cd pgvectorscale
WORKDIR /tmp/pgvectorscale
RUN ~/.cargo/bin/cargo install --locked cargo-pgrx --version $(~/.cargo/bin/cargo metadata --format-version 1 | jq -r '.packages[] | select(.name == "pgrx") | .version')
RUN ~/.cargo/bin/cargo pgrx init --pg${POSTGRESQL_VERSION} pg_config
WORKDIR /tmp/pgvectorscale/pgvectorscale
RUN ~/.cargo/bin/cargo pgrx package
# build pgvector
RUN cd /tmp && git clone --branch v${PGVECTOR_VERSION} https://github.com/pgvector/pgvector && cd pgvector && make
# pg-safeupdate
RUN cd /tmp && wget -q -O - $SAFEUPDATE_URL | tar xzf - && cd pg-safeupdate-master && gmake

FROM postgres:17-bookworm

ENV POSTGRESQL_VERSION=17
ENV PGROONGA_VERSION=4.0.1-1
ENV PGVECTORSCALE_VERSION=0.8.0
ENV POSTGIS_MAJOR=3
ENV SUPERCRONIC_VERSION=v0.2.34

# install pgroonga
RUN \
  apt update && \
  apt install -y -V --no-install-recommends lsb-release wget ca-certificates curl pgbackrest tzdata libxml2 libssh2-1 && \
  wget https://apache.jfrog.io/artifactory/arrow/debian/apache-arrow-apt-source-latest-$(lsb_release --codename --short).deb && \
  apt install -y -V ./apache-arrow-apt-source-latest-$(lsb_release --codename --short).deb && \
  rm apache-arrow-apt-source-latest-$(lsb_release --codename --short).deb && \
  wget https://packages.groonga.org/debian/groonga-apt-source-latest-$(lsb_release --codename --short).deb && \
  apt install -y -V ./groonga-apt-source-latest-$(lsb_release --codename --short).deb && \
  rm groonga-apt-source-latest-$(lsb_release --codename --short).deb && \
  apt update && \
  apt install -y -V --no-install-recommends \
    postgresql-${POSTGRESQL_VERSION}-cron \
    postgresql-${POSTGRESQL_VERSION}-postgis-${POSTGIS_MAJOR} \
    postgresql-${POSTGRESQL_VERSION}-postgis-${POSTGIS_MAJOR}-scripts \
    postgresql-${POSTGRESQL_VERSION}-pgdg-pgroonga=${PGROONGA_VERSION} \
    groonga-normalizer-mysql \
    groonga-token-filter-stem \
    groonga-tokenizer-mecab && \
  apt clean && \
  rm -rf /var/lib/apt/lists/*

# install pgvector & pgvectorscale
RUN mkdir -p /usr/local/lib/postgresql/
RUN mkdir -p /usr/local/share/postgresql/extension/
# copy pgvector
COPY --from=builder /tmp/pgvector/vector.so /usr/lib/postgresql/${POSTGRESQL_VERSION}/lib/
COPY --from=builder /tmp/pgvector/vector.control /usr/share/postgresql/${POSTGRESQL_VERSION}/extension/
COPY --from=builder /tmp/pgvector/sql/*.sql /usr/share/postgresql/${POSTGRESQL_VERSION}/extension/
# copy pgvectorscale
COPY --from=builder /tmp/pgvectorscale/target/release/vectorscale-pg${POSTGRESQL_VERSION}/usr/lib/postgresql/${POSTGRESQL_VERSION}/lib/vectorscale-${PGVECTORSCALE_VERSION}.so /usr/lib/postgresql/${POSTGRESQL_VERSION}/lib/
COPY --from=builder /tmp/pgvectorscale/target/release/vectorscale-pg${POSTGRESQL_VERSION}/usr/share/postgresql/${POSTGRESQL_VERSION}/extension/*.* /usr/share/postgresql/${POSTGRESQL_VERSION}/extension/
# copy pg-safeupdate
COPY --from=builder /tmp/pg-safeupdate-master/safeupdate.so /usr/lib/postgresql/${POSTGRESQL_VERSION}/lib/

RUN mkdir -p /docker-entrypoint-initdb.d
COPY ./initdb-postgis.sh /docker-entrypoint-initdb.d/10_postgis.sh
COPY ./update-postgis.sh /usr/local/bin
COPY ./initdb-pgbackrest.sh /docker-entrypoint-initdb.d/20_pgbackrest.sh
COPY ./entrypoint.sh /usr/local/bin/
# Add execute permissions to all scripts in /usr/local/bin
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/update-postgis.sh

RUN echo "shared_preload_libraries='pg_cron,safeupdate'" >> /usr/share/postgresql/postgresql.conf.sample && \
  echo "cron.database_name='${POSTGRES_DB:-postgres}'" >> /usr/share/postgresql/postgresql.conf.sample

# supercronic
RUN ARCH=$(dpkg --print-architecture) && \
    case "$ARCH" in \
        amd64)  SUPERCRONIC=supercronic-linux-amd64 ;; \
        arm64)  SUPERCRONIC=supercronic-linux-arm64 ;; \
        *)      echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac && \
    wget -q "https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/${SUPERCRONIC}" && \
    chmod +x "$SUPERCRONIC" && \
    mv "$SUPERCRONIC" /usr/local/bin/supercronic
# pgbackrest
RUN chmod -R 755 /usr/bin/pgbackrest && \
    mkdir -p /etc/pgbackrest && mkdir -p /etc/pgbackrest/conf.d && touch /etc/pgbackrest/pgbackrest.conf && chown -R postgres:postgres /etc/pgbackrest && chmod -R 750 /etc/pgbackrest && \
    mkdir -p /var/log/pgbackrest && chown -R postgres:postgres /var/log/pgbackrest && chmod -R 770 /var/log/pgbackrest && \
    mkdir -p /var/lib/pgbackrest && chown -R postgres:postgres /var/lib/pgbackrest && chmod -R 770 /var/lib/pgbackrest && \
    mkdir -p /var/spool/pgbackrest && chown -R postgres:postgres /var/spool/pgbackrest && chmod -R 750 /var/spool/pgbackrest && \
    mkdir -p /tmp/pgbackrest && chown -R postgres:postgres /tmp/pgbackrest && chmod -R 750 /tmp/pgbackrest && \
    echo "wal_level = replica" >> /usr/share/postgresql/postgresql.conf.sample && \
    echo "wal_compression = on" >> /usr/share/postgresql/postgresql.conf.sample && \
    echo "max_wal_senders = 4" >> /usr/share/postgresql/postgresql.conf.sample && \
    echo "archive_mode = on" >> /usr/share/postgresql/postgresql.conf.sample && \
    echo "archive_command = 'pgbackrest --stanza=default archive-push %p'" >> /usr/share/postgresql/postgresql.conf.sample && \
    echo "archive_timeout = 1800" >> /usr/share/postgresql/postgresql.conf.sample


HEALTHCHECK --interval=10s --timeout=5s --start-period=5s --retries=5 \
  CMD pg_isready -U "${POSTGRES_USER:-postgres}" || exit 1

ENTRYPOINT ["entrypoint.sh"]
CMD ["postgres"]
