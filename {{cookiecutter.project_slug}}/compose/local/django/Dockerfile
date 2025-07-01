# define an alias for the specific python version used in this file.
FROM docker.io/python:3.12.11-slim-bookworm AS python

# Python build stage
FROM python AS python-build-stage

ARG BUILD_ENVIRONMENT=local

# Install apt packages
RUN apt-get update && apt-get install --no-install-recommends -y \
  # dependencies for building Python packages
  build-essential \
  # psycopg dependencies
  libpq-dev

# Requirements are installed here to ensure they will be cached.
COPY ./requirements .

# Create Python Dependency and Sub-Dependency Wheels.
RUN pip wheel --wheel-dir /usr/src/app/wheels \
  -r ${BUILD_ENVIRONMENT}.txt


# Python 'run' stage
FROM python AS python-run-stage

ARG BUILD_ENVIRONMENT=local
ARG APP_HOME=/app

ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV BUILD_ENV=${BUILD_ENVIRONMENT}

WORKDIR ${APP_HOME}

# System utilities
RUN apt-get update && apt-get install --no-install-recommends -y \
  curl ca-certificates gnupg lsb-release \
  locales sudo vim nano \
  wget unzip zip \
  && rm -rf /var/lib/apt/lists/*

# Development tools
RUN apt-get update && apt-get install --no-install-recommends -y \
  git build-essential cmake pkg-config \
  clang-format shellcheck \
  && rm -rf /var/lib/apt/lists/*

# Python development dependencies
RUN apt-get update && apt-get install --no-install-recommends -y \
  python3-dev libssl-dev zlib1g-dev libbz2-dev \
  libreadline-dev libsqlite3-dev libncursesw5-dev \
  xz-utils tk-dev libxml2-dev libxmlsec1-dev \
  libffi-dev liblzma-dev \
  && rm -rf /var/lib/apt/lists/*

# Python runtime tools
RUN apt-get update && apt-get install --no-install-recommends -y \
  python3 python3-pip python3-venv \
  && rm -rf /var/lib/apt/lists/*

# Shell and terminal tools
RUN apt-get update && apt-get install --no-install-recommends -y \
  bash-completion htop tree jq \
  zsh tmux ripgrep fd-find bat fzf \
  && rm -rf /var/lib/apt/lists/*

# Network tools
RUN apt-get update && apt-get install --no-install-recommends -y \
  net-tools iputils-ping dnsutils \
  openssh-client openssh-server \
  && rm -rf /var/lib/apt/lists/*

# Database dependencies and clients
RUN apt-get update && apt-get install --no-install-recommends -y \
  libpq-dev postgresql-client \
  && rm -rf /var/lib/apt/lists/*

# Django specific
RUN apt-get update && apt-get install --no-install-recommends -y \
  wait-for-it gettext \
  && rm -rf /var/lib/apt/lists/*

{% if cookiecutter.use_cypress == "y" %}
# Install browser testing dependencies for Cypress
RUN apt-get update && apt-get install --no-install-recommends -y \
  xvfb libgtk-3-0 libgbm-dev libnotify-dev \
  libnss3 libxss1 libxtst6 xauth libasound2-dev \
  ffmpeg \
  && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
  && rm -rf /var/lib/apt/lists/*
{% endif %}

# Create devcontainer user and add it to sudoers
RUN groupadd --gid 1000 dev-user \
  && useradd --uid 1000 --gid dev-user --shell /bin/bash --create-home dev-user \
  && echo dev-user ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/dev-user \
  && chmod 0440 /etc/sudoers.d/dev-user

# All absolute dir copies ignore workdir instruction. All relative dir copies are wrt to the workdir instruction
# copy python dependency wheels from python-build-stage
COPY --from=python-build-stage /usr/src/app/wheels /wheels/

# use wheels to install python dependencies
RUN pip install --no-cache-dir --no-index --find-links=/wheels/ /wheels/* \
  && rm -rf /wheels/

COPY ./compose/production/django/entrypoint /entrypoint
RUN sed -i 's/\r$//g' /entrypoint
RUN chmod +x /entrypoint

COPY ./compose/local/django/start /start
RUN sed -i 's/\r$//g' /start
RUN chmod +x /start

{% if cookiecutter.use_celery == "y" %}
COPY ./compose/local/django/celery/worker/start /start-celeryworker
RUN sed -i 's/\r$//g' /start-celeryworker
RUN chmod +x /start-celeryworker

COPY ./compose/local/django/celery/beat/start /start-celerybeat
RUN sed -i 's/\r$//g' /start-celerybeat
RUN chmod +x /start-celerybeat

COPY ./compose/local/django/celery/flower/start /start-flower
RUN sed -i 's/\r$//g' /start-flower
RUN chmod +x /start-flower
{% endif %}

# copy application code to WORKDIR
COPY . ${APP_HOME}

ENTRYPOINT ["/entrypoint"]
