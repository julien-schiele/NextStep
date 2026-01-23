# NextStep

**NextStep** – Progress one day at a time.

## Set up your environment

Before starting the stack, you need to create a `.env` file and define the following variables:

```env
# PostgreSQL
POSTGRES_DB=NextStep
POSTGRES_USER=username
POSTGRES_PASSWORD=password

# Django
DB_ENGINE=django.db.backends.postgresql
DB_HOST=database
DB_PORT=5432
DB_NAME=${POSTGRES_DB}
DB_USER=${POSTGRES_USER}
DB_PASSWORD=${POSTGRES_PASSWORD}

# PgAdmin
PGADMIN_DEFAULT_EMAIL=email
PGADMIN_DEFAULT_PASSWORD=password
