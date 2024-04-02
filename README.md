

Running

docker compose up -d --build

If m


For postgres materialization add this to postgresql.conf

```
listen_addresses = '*'
max_replication_slots = 20
wal_level = logical
```

For mysql materialization add this to my.cnf

```
default-authentication-plugin = mysql_native_password
gtid-mode = ON
enforce-gtid-consistency = ON
```
