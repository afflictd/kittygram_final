# Бэкенд Kittygram

Django REST API для котов, достижений и пользователей. Данные хранятся
в PostgreSQL, авторизация работает через токены Djoser.

Запуск проекта и переменные окружения описаны в [основном README](../README.md).
Из корня репозитория:

```bash
docker compose up --build -d --wait
docker compose exec backend python manage.py createsuperuser
docker compose exec backend python manage.py test cats --verbosity 2
```

API: <http://localhost:9000/api/>. Основные маршруты: users/,
token/login/, token/logout/, cats/, cats/{id}/, achievements/.
Бэкенд сам применяет миграции и собирает статику перед запуском Gunicorn.
