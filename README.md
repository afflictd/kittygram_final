# Kittygram: Docker и CI/CD

Приложение для публикации фотографий котов и их достижений.
После регистрации и входа можно просматривать, создавать, изменять и удалять
карточки котов, указывать имя, цвет, год рождения и достижения, загружать фото.
Через админку можно управлять пользователями и данными приложения.
Цель учебного проекта — настроить совместную работу приложения в контейнерах
и автоматизировать проверки, сборку и публикацию образов через GitHub Actions.

Стек: Python 3.10–3.12, Django 4.2, DRF, React 17, Node.js 18, PostgreSQL 13,
Gunicorn, Nginx, Docker Compose, GitHub Actions и Ruff.

## Локальный запуск

Нужны Git, Docker с Linux-контейнерами и Docker Compose v2 или новее.
В Windows предварительно запустите Docker Desktop.

```bash
git clone https://github.com/afflictd/kittygram_final.git
cd kittygram_final
```

Скопируйте `.env.example` в `.env`: `Copy-Item .env.example .env`
в PowerShell или `cp .env.example .env` в Bash.
Замените `POSTGRES_PASSWORD` и `SECRET_KEY` своими случайными значениями.

| Переменная | Назначение |
| --- | --- |
| POSTGRES_DB | Имя базы данных |
| POSTGRES_USER | Пользователь PostgreSQL |
| POSTGRES_PASSWORD | Пароль PostgreSQL |
| DB_HOST, DB_PORT | Адрес БД в сети Docker: db:5432 |
| SECRET_KEY | Секретный ключ Django |
| DEBUG | False для обычного запуска |
| ALLOWED_HOSTS | Разрешённые хосты через запятую |

```bash
docker compose up --build -d --wait
docker compose exec backend python manage.py createsuperuser
```

Приложение: <http://localhost:9000/>. Админка: <http://localhost:9000/admin/>.
API доступен по `/api/`: `users/`, `token/login/`, `token/logout/`,
`cats/`, `cats/{id}/`, `achievements/`.

Бэкенд ждёт готовности БД, применяет миграции, собирает статику и запускает
Gunicorn. Контейнер frontend копирует сборку в общий том и завершается
с кодом 0 — это штатное поведение. После подготовки фронтенда и бэкенда
запускается Nginx: он раздаёт React, статику и фотографии, а запросы
`/api/` и `/admin/` передаёт Gunicorn.

Данные сохраняются в томах `pg_data` (PostgreSQL), `static` (React и статика
Django), `media` (фотографии). Команда `docker compose down` останавливает
проект с сохранением данных. Для существующего тома БД переменные
POSTGRES_* должны совпадать с данными его первоначального создания.
Файл `.env` и секретные токены не добавляются в Git.

## Проверки

```bash
docker compose config --quiet
docker compose exec backend python manage.py check
docker compose exec backend python manage.py makemigrations --check --dry-run
docker compose exec backend python manage.py test cats --verbosity 2
docker compose run --rm --no-deps frontend npm test -- --watchAll=false --runInBand
```

Для проверок и автоматического форматирования перед коммитами:

```bash
python -m pip install -r requirements-dev.txt
pre-commit install
pre-commit run --all-files
ruff check backend/
ruff format --check backend/
pycodestyle backend/
```

Hooks автоматически форматируют Python-код, исправляют доступные Ruff
ошибки и проверяют стиль при каждом коммите.

Каталог `tests/` из исходного репозитория проверяет внешние сайты Taski,
Kittygram и Docker Hub. Для его запуска нужны реальные домены и файл
`tests.yml`. Это отдельная проверка после развёртывания на сервере.
Workflow запускает готовые тесты приложения из `backend/cats/tests.py`
и `frontend/src/components/app/app.test.js`.

## GitHub Actions

Workflow: `.github/workflows/main.yml`. Его копия для проверки задания:
`kittygram_workflow.yml` в корне. При изменении обновляйте оба файла.

Push в любую ветку и pull request в main запускают Ruff, проверку
форматирования и pycodestyle, проверку Django и миграций, тесты бэкенда
с PostgreSQL на Python 3.10, 3.11, 3.12 и тесты фронтенда.
Контейнер бэкенда использует Python 3.10. Push в main дополнительно
собирает и публикует три образа в Docker Hub: `kittygram_backend`,
`kittygram_frontend`, `kittygram_gateway`. Теги — latest и SHA коммита.
После публикации всех трёх образов приходит уведомление в Telegram
с автором, сообщением и ссылкой на коммит.
Workflow можно запустить вручную на вкладке Actions. Новый запуск
для той же ветки отменяет предыдущий.

В **Settings → Secrets and variables → Actions** создайте секреты:

| Секрет | Значение |
| --- | --- |
| DOCKER_USERNAME | Логин Docker Hub |
| DOCKER_PASSWORD | Токен Docker Hub с правом записи образов |
| TELEGRAM_TOKEN | Токен Telegram-бота |
| TELEGRAM_TO | ID чата, в котором пользователь запустил бота |

Нужны аккаунт Docker Hub и три публичных репозитория с указанными именами.
Бота создают через @BotFather, затем открывают чат с ним и нажимают Start.
Токены хранятся только в Actions secrets. Если настройки отсутствуют,
соответствующий шаг завершается ошибкой с именем недостающего секрета.

## Запуск опубликованных образов

Проверьте `DOCKERHUB_USERNAME` в `.env`: для этого репозитория используется
`afflictd`. При публикации в другой аккаунт укажите его логин.
Конфигурация production использует готовые образы без локальной сборки:

```bash
docker compose -f docker-compose.production.yml pull
docker compose -f docker-compose.production.yml up -d --wait
```

Образы проекта: [бэкенд](https://hub.docker.com/r/afflictd/kittygram_backend),
[фронтенд](https://hub.docker.com/r/afflictd/kittygram_frontend),
[Nginx](https://hub.docker.com/r/afflictd/kittygram_gateway).

Порт 9000 привязан к 127.0.0.1. На удалённом сервере внешний Nginx должен
направлять запросы домена Kittygram на http://127.0.0.1:9000, а домена Taski
на порт Taski. Домен Kittygram нужно добавить в ALLOWED_HOSTS.
Автоматическая установка проекта на удалённый сервер в workflow не включена.
