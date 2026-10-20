#!/bin/sh
set -eu

python manage.py migrate --noinput
python manage.py collectstatic --noinput
mkdir -p /backend_static/static
cp -r /app/static/. /backend_static/static/

exec "$@"
