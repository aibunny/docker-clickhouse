#!/bin/bash
set -e

if [ "$MATERIALIZE_PSQL" == "True" ]; then
    clickhouse-client -n <<-EOSQL
        SET allow_experimental_database_materialized_postgresql=1;
        CREATE DATABASE $PSQL_DATABASE_NAME
        ENGINE = MaterializedPostgreSQL(
            '$PSQL_DATABASE_HOST:$PSQL_DATABASE_PORT',
            '$PSQL_DATABASE_NAME',
            '$PSQL_DATABASE_USER',
            '$PSQL_DATABASE_PASSWORD'
        );
EOSQL
fi
