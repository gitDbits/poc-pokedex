#!/bin/sh
set -e

cat >> "$PGDATA/pg_hba.conf" <<EOF
host replication ${REPLICATION_USER} 0.0.0.0/0 scram-sha-256
EOF
