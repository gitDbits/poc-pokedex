#!/bin/sh
set -e

PGDATA="${PGDATA:-/var/lib/postgresql/data}"
PRIMARY_HOST="pokedex-postgres-writer"
PRIMARY_PORT="5432"

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  echo "Replica bootstrap: preparing base backup from writer..."
  rm -rf "${PGDATA:?}"/*
  mkdir -p "$PGDATA"
  chmod 700 "$PGDATA"

  export PGPASSWORD="$REPLICATION_PASSWORD"
  until pg_basebackup \
    -h "$PRIMARY_HOST" \
    -p "$PRIMARY_PORT" \
    -U "$REPLICATION_USER" \
    -D "$PGDATA" \
    -R \
    -Fp \
    -Xs \
    -P; do
    echo "Replica bootstrap: writer not ready for basebackup, retrying in 2s..."
    sleep 2
  done
  unset PGPASSWORD

  chmod 700 "$PGDATA"
  echo "Replica bootstrap: base backup complete."
fi

exec docker-entrypoint.sh postgres
