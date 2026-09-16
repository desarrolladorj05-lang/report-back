# SQL database objects

Database scripts are organized by object type and business domain:

```text
sql/
|-- functions/
|   |-- cash-petty/
|   |-- clients/
|   |-- liquidations/
|   |-- products/
|   `-- sales/
`-- indexes/
    |-- liquidations/
    `-- products/
```

Each function must live in its own `.sql` file and use the database function
name as the filename. Index scripts may contain the related indexes for one
dashboard or domain.
