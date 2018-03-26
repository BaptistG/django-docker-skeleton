#!/bin/bash

set -euo pipefail

# Make sure the project and application names are passed in as a parameted
if [[ "$#" -lt 2 ]]; then
  echo "usage: $0 <project_name> <app_name>" 1>&2
  exit 1
fi

PROJECT_NAME=$1
APP_NAME=$2
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_PATH="$ROOT/$PROJECT_NAME"
APP_PATH="$PROJECT_PATH/$APP_NAME"
VIRTUALENV_PATH="$ROOT/virtualenv"

# If PROJECT_PATH already exists, exit out
if [[ -d "$PROJECT_PATH" ]]; then
  echo "Error: $PROJECT_PATH already exists and shouldn't be overriden" 1>&2
  exit 1
fi
# If manage.py already exists, exit out
if [[ -f "$ROOT/manage.py"  ]]; then
  echo "Error: manage.py already exists in $ROOT/manage.py" 1>&2
  exit 1
fi

# Runs the docker build for the first run
docker-compose run app whoami > /dev/null
$ROOT/reset_virtualenv.sh

printf "\n>>> Create project and app directories\n"
docker-compose run app ./virtualenv/bin/django-admin startproject $PROJECT_NAME .
docker-compose run app bash -c "cd /app/$PROJECT_NAME && ../virtualenv/bin/django-admin startapp $APP_NAME"

printf "\n>>> Run migrations\n"
docker-compose run app ./virtualenv/bin/python manage.py migrate

printf "\n>>> Configure app\n"
docker-compose run app sed -i "s/'django.contrib.staticfiles',/'django.contrib.staticfiles',\n    '$APP_NAME',/" /app/$PROJECT_NAME/settings.py
docker-compose run app sed -i "s/import os/import os\nimport sys/" /app/$PROJECT_NAME/settings.py
docker-compose run app sed -i "s/BASE_DIR =.*/BASE_DIR = os.path.dirname(os.path.abspath(__file__))\nsys.path.insert(0, BASE_DIR)/" /app/$PROJECT_NAME/settings.py
mkdir $APP_PATH/templates
echo -e "<html>\n<head><title>Home Page</title></head>\n<body>\nHello world\n</body>\n</html>" > $APP_PATH/templates/index.html
cat <<END > $APP_PATH/views.py
# -*- coding: utf-8 -*-
from __future__ import unicode_literals
from django.shortcuts import render
from django.views.generic import TemplateView
class HomeView(TemplateView):
    template_name = 'index.html'
END

printf "\n>>> Setup URLs\n"
cat <<END > $PROJECT_PATH/urls.py
"""$PROJECT_NAME URL Configuration
The 'urlpatterns' list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/2.0/topics/http/urls/
Examples:
Function views
    1. Add an import:  from dashboards import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin
from django.urls import include, path

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('$APP_NAME.urls')),
]
END

cat <<END > $APP_PATH/urls.py
"""$APP_NAME URL Configuration
The 'urlpatterns' list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/2.0/topics/http/urls/
Examples:
Function views
    1. Add an import:  from $APP_NAME import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.urls import path
from $APP_NAME.views import HomeView
urlpatterns = [
    path('', HomeView.as_view(), name='home'),
]
END
echo -e "Done!\n"

# Cleanup
$ROOT/docker_cleanup.sh > /dev/null 2>&1
