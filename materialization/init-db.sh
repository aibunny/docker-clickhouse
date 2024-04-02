#!/bin/bash
set -e

echo "⚙️ 🔧🔧🔧🔧🔧🔧🔧🔧Adding database materialization for PostgreSQL (psql) / MYSQl 🔧🔧🔧🔧🔧🔧🔧⚙️"



#Optionally materialize psql databse

if [ "$MATERIALIZE_PSQL" == "True" ]; then
    clickhouse-client -n <<-EOSQL
        CREATE DATABASE $PSQL_DATABASE_NAME
        ENGINE = MaterializedPostgreSQL(
            '$PSQL_DATABASE_HOST:$PSQL_DATABASE_PORT',
            '$PSQL_DATABASE_NAME',
            '$PSQL_DATABASE_USER',
            '$PSQL_DATABASE_PASSWORD'
        );
EOSQL
fi


#Optionally materialize mysql database

if [ "$MATERIALIZE_MYSQL" == "True" ]; then
    clickhouse-client -n <<-EOSQL
        CREATE DATABASE $MYSQL_DATABASE_NAME
        ENGINE = MaterializedPostgreSQL(
            '$MYSQL_DATABASE_HOST:$MYSQL_DATABASE_PORT',
            '$MYSQL_DATABASE_NAME',
            '$MYSQL_DATABASE_USER',
            '$MYSQL_DATABASE_PASSWORD'
        );
EOSQL
fi