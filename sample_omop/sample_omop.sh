#!/bin/bash

PG_HOST=localhost
PG_USER=bunny
PG_SCHEMA=public
export PGDATABASE=sample_omop

if [ ! -f OMOPCDM_v5.4.zip ]; then
    wget https://github.com/OHDSI/CommonDataModel/releases/download/v5.4.2/OMOPCDM_v5.4.zip
    unzip -d omopcdm OMOPCDM_v5.4.zip
fi

if [ ! -f Synthea27Nj_5.4.zip ]; then
    wget https://github.com/OHDSI/EunomiaDatasets/raw/refs/heads/main/datasets/Synthea27Nj/Synthea27Nj_5.4.zip
    unzip -d synthea27nj Synthea27Nj_5.4.zip
fi

sed s/@cdmDatabaseSchema/$PG_SCHEMA/g omopcdm/5.4/postgresql/OMOPCDM_postgresql_5.4_ddl.sql | psql -h"$PG_HOST" -U"$PG_USER" -f -
sed s/@cdmDatabaseSchema/$PG_SCHEMA/g omopcdm/5.4/postgresql/OMOPCDM_postgresql_5.4_primary_keys.sql | psql -h"$PG_HOST" -U"$PG_USER" -f -

# # Import data table by table
for f in synthea27nj/*.csv; do
  TABLE=$(echo "${f#*/}" | cut -d. -f1 | tr A-Z a-z)
  echo "Loading $f to table $TABLE"
  psql -h"$PG_HOST" -U"$PG_USER" -v ON_ERROR_STOP=1 -c "\\copy $TABLE FROM '$f' WITH CSV HEADER;"
done

# Setup constraints and indices
sed s/@cdmDatabaseSchema/$PG_SCHEMA/g omopcdm/5.4/postgresql/OMOPCDM_postgresql_5.4_constraints.sql | psql -h"$PG_HOST" -U"$PG_USER" -f -
sed s/@cdmDatabaseSchema/$PG_SCHEMA/g omopcdm/5.4/postgresql/OMOPCDM_postgresql_5.4_indices.sql | psql -h"$PG_HOST" -U"$PG_USER" -f -
