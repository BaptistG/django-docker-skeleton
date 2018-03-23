#!/bin/bash

set -euo pipefail

# Make sure the application name is passed in as a parameted
if [[ "$#" -lt 1 ]]; then
  echo "usage: $0 <app_name>" 1>&2
  exit 1
fi

APP_NAME=$1
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_PATH="$ROOT/$APP_NAME"
VIRTUALENV_PATH="$ROOT/virtualenv"
CONTROLLERS_PATH="$APP_PATH/controllers"
TEMPLATES_PATH="$APP_PATH/templates"

# If APP_PATH already exists, exit out
if [[ -d "$APP_PATH" ]]; then
  echo "Error: $APP_NAME already exists and shouldn't be overriden" 1>&2
  exit 1
fi
# If manage.py already exists, exit out
if [[ -f "$APP_PATH/manage.py"  ]]; then
  echo "Error: manage.py already exists in $APP_PATH/manage.py" 1>&2
  exit 1
fi

printf "\n> Setup virtualenv\n"
docker-compose run app whoami > /dev/null
$ROOT/reset_virtualenv.sh

printf "\n> Create app directory\n"
$VIRTUALENV_PATH/bin/django-admin startproject $APP_NAME

printf "\n> Run migrations\n"
docker-compose run app $VIRTUALENV_PATH/bin/python migrate

printf "\n> Create app\n"
cd $APP_NAME
$VIRTUALENV_PATH/bin/python manage.py startapp main
sed "s/\'django.contrib.staticfiles\',\\n]/\'django.contrib.staticfiles\',    $APP_NAME,\\n]/"
mkdir ./main/templates
echo "<html>\n<head><title>Home Page</title></head>\n<body>\nHello world\n</body>\n</html>" > ./main/templates/index.html
cat <<END > "./main/views.py"
# -*- coding: utf-8 -*-
from __future__ import unicode_literals
from django.shortcuts import render
from django.views.generic import TemplateView
class HomeView(TemplateView):
    template_name = 'index.html'
END
cd ..

printf "\n> Setup URLs\n"
cat <<END > "./urls.py"
"""helloworld_project URL Configuration
The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/1.11/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  url(r'^$', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  url(r'^$', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.conf.urls import url, include
    2. Add a URL to urlpatterns:  url(r'^blog/', include('blog.urls'))
"""
from django.conf.urls import url
from django.contrib import admin
from my_app.views import HomeView
urlpatterns = [
    url(r'^admin/', admin.site.urls),
    url(r'^$', HomeView.as_view()),
]
END
