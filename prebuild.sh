#!/bin/bash

# Ensure the .env file is sourced to access environment variables
set -a
source .env
set +a

# Use envsubst to replace variables in init.sql.template and generate init.sql
envsubst < db/init.sql.template > db/init.sql

echo "Generated init.sql with environment variables."
