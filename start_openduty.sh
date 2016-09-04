#!/bin/bash
cd /opt/openduty

#patch config files
if [ -n "$MYSQL_PORT_3306_TCP" ]; then
  if [ -z "$OPENDUTY_DB_HOST" ]; then
    OPENDUTY_DB_HOST='mysql'
  else
    echo >&2 'warning: both OPENDUTY_DB_HOST and MYSQL_PORT_3306_TCP found'
    echo >&2 "  Connecting to OPENDUTY_DB_HOST ($OPENDUTY_DB_HOST)"
    echo >&2 '  instead of the linked mysql container'
  fi
fi

if [ -z "$OPENDUTY_DB_HOST" ]; then
  echo >&2 'error: missing OPENDUTY_DB_HOST and MYSQL_PORT_3306_TCP environment variables'
  echo >&2 '  Did you forget to --link some_mysql_container:mysql or set an external db'
  echo >&2 '  with -e OPENDUTY_DB_HOST=hostname:port?'
  exit 1
fi

# if we're linked to MySQL and thus have credentials already, let's use them
: ${OPENDUTY_DB_USER:=${MYSQL_ENV_MYSQL_USER:-root}}
if [ "$OPENDUTY_DB_USER" = 'root' ]; then
  : ${OPENDUTY_DB_PASSWORD:=$MYSQL_ENV_MYSQL_ROOT_PASSWORD}
fi
: ${OPENDUTY_DB_PASSWORD:=$MYSQL_ENV_MYSQL_PASSWORD}
: ${OPENDUTY_DB_NAME:=${MYSQL_ENV_MYSQL_DATABASE:-openduty}}

if [ -z "$OPENDUTY_DB_PASSWORD" ]; then
  echo >&2 'error: missing required OPENDUTY_DB_PASSWORD environment variable'
  echo >&2 '  Did you forget to -e OPENDUTY_DB_PASSWORD=... ?'
  echo >&2
  echo >&2 '  (Also of interest might be OPENDUTY_DB_USER and OPENDUTY_DB_NAME.)'
  exit 1
fi

SECRET_KEY=$(date | md5sum)

: ${OPENDUTY_BASE_URL:=${OPENDUTY_BASE_URL:-http://localhost:8000}}
: ${OPENDUTY_ADMIN_USER:=${OPENDUTY_ADMIN_USER:-opendutyadmin}}
: ${OPENDUTY_ADMIN_EMAIL:=${OPENDUTY_ADMIN_EMAIL:-openduty@example.com}}
: ${OPENDUTY_ADMIN_PASSWORD:=${OPENDUTY_ADMIN_PASSWORD:-openforduty}}

cat >/opt/openduty/openduty/settings_docker.py <<EOF
from settings import *

DEBUG = False
TEMPLATE_DEBUG = False
ALLOWED_HOSTS = ['*']

import sys
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': '${OPENDUTY_DB_NAME}',
        'USER': '${OPENDUTY_DB_USER}',
        'PASSWORD': '${OPENDUTY_DB_PASSWORD}',
        'HOST': '${OPENDUTY_DB_HOST}',
        'PORT': '3306'
    }
}

BASE_URL = "${OPENDUTY_BASE_URL}"

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = '${SECRET_KEY}'

PAGINATION_DEFAULT_PAGINATION = 3

AUTHENTICATION_BACKENDS = (
    'django.contrib.auth.backends.ModelBackend',
)

MIDDLEWARE_CLASSES = MIDDLEWARE_CLASSES + (
    'openduty.middleware.basicauthmiddleware.BasicAuthMiddleware',
)
EOF

export DJANGO_SETTINGS_MODULE=openduty.settings_docker
read

python manage.py syncdb --noinput
python manage.py syncdb --noinput

python manage.py migrate --noinput
echo "from django.contrib.auth.models import User; User.objects.create_superuser('${OPENDUTY_ADMIN_USER}', '${OPENDUTY_ADMIN_EMAIL}', '${OPENDUTY_ADMIN_PASSWORD}')" | python manage.py shell
exec python manage.py runserver 0.0.0.0:80
