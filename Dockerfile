FROM postgres:16

# Install dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        postgresql-16-postgis-3 \
        postgresql-16-postgis-3-scripts \
        postgresql-16-pgvector \
        wget \
        gnupg \
        lsb-release \
        curl \
        ca-certificates \
        libicu-dev \
    && rm -rf /var/lib/apt/lists/*

# Install pg_search from ParadeDB
RUN curl -L "https://github.com/paradedb/paradedb/releases/download/v0.19.4/postgresql-16-pg-search_0.19.4-1PARADEDB-noble_amd64.deb" -o /tmp/pg_search.deb \
    && apt-get update \
    && apt-get install -y /tmp/pg_search.deb \
    && rm /tmp/pg_search.deb \
    && rm -rf /var/lib/apt/lists/*

# Add TimescaleDB repository and install
RUN echo "deb https://packagecloud.io/timescale/timescaledb/debian/ $(lsb_release -c -s) main" | tee /etc/apt/sources.list.d/timescaledb.list \
    && wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | gpg --dearmor -o /etc/apt/trusted.gpg.d/timescaledb.gpg \
    && apt-get update \
    && apt-get install -y timescaledb-2-postgresql-16 \
    && rm -rf /var/lib/apt/lists/*

# Run timescaledb-tune with recommended settings
# RUN timescaledb-tune --quiet --yes

# Copy initialization script
COPY init-extensions.sql /docker-entrypoint-initdb.d/

# Set shared_preload_libraries
RUN echo "shared_preload_libraries = 'timescaledb,pg_search'" >> /usr/share/postgresql/postgresql.conf.sample

EXPOSE 5432