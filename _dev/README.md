# Dev-окружение

Точка входа — `./x`. На хосте нужны Bash, Docker Engine / Docker Desktop
и Docker Compose v2. PHP, Composer и Node.js на хост устанавливать не нужно.

## Linux и Windows

На Linux запускайте `./x` от обычного пользователя с доступом к Docker,
без `sudo`. UID/GID автоматически передаются в образ, поэтому созданные
контейнером файлы принадлежат пользователю хоста.

На Windows используйте терминал WSL2 с включённой интеграцией Docker Desktop.
Клонируйте проект в файловую систему WSL, например `~/projects/laravel-project`,
и выполняйте те же команды `./x`, включая `up` и `down`.
Запуск Bash-скрипта непосредственно из PowerShell не поддерживается.

Git хранит исполняемый бит `x`, а `.gitattributes` закрепляет LF для скриптов.
После обычного `git clone` выполнять `chmod` не требуется. Вспомогательные
скрипты запускаются через Bash/PHP и не требуют исполняемого бита.
При копировании проекта архивом с потерей прав можно использовать `bash x`.

## Новый проект

```bash
./x install laravel:11
./x artisan migrate
./x run dev
```

Укажите нужную основную версию Laravel. Composer проверяет её совместимость
с выбранной версией PHP; обёртка не переписывает требование PHP в `composer.json`.

Если `.env` отсутствует, обёртка создаёт его из `_dev/.env.example.development`
с правами `0600`. Чтобы настроить проект до первого запуска:

```bash
(umask 077; cp _dev/.env.example.development .env)
```

В `.env` используется `PHP_VERSION=8.4`. Dockerfile и Compose
по умолчанию также выбирают PHP 8.4; Composer требует ветку 8.4.x (`~8.4.0`).
После изменения версии выполните `./x up -b`: образ будет пересобран с использованием
кеша, зависимости установлены из lock-файлов. Проверьте `./x composer check-platform-reqs`.
Не задавайте `LOCAL_UID`/`LOCAL_GID` вручную — `x` берёт их у пользователя хоста.

Установка предназначена для новой обёртки без `composer.json`, `artisan`
и каталога `laravel-dev`. Файлы Laravel сначала создаются в `laravel-dev`.
Перед переносом проверяются конфликты с существующими файлами.
Правила `.gitignore` и `.gitattributes` объединяются с сохранением приоритета
настроек обёртки, значения корневого `.env` переносятся в Laravel `.env`.
Git index не изменяется.

При ошибке установка останавливается. Оставшийся `laravel-dev` сохраняется
для проверки и восстановления; он исключён из Git. Если ошибка возникла
после переноса приложения, исправьте её и выполните нужную команду зависимостей
через `./x composer` или `./x npm`, не запускайте установку поверх проекта.

## Существующий проект

```bash
./x up -b
./x artisan migrate
./x run dev
```

`up` запускает сервисы и проверяет сборку образа. Флаг `-b` дополнительно
выполняет `composer install` и `npm install`; при ошибке дальнейшие шаги
не выполняются. PostgreSQL и Redis проверяются healthcheck перед запуском app.

`./x stop` останавливает контейнеры без удаления, `./x start` запускает уже
созданные контейнеры без пересборки. Можно указать сервисы и параметры Compose:
`./x stop --timeout 12 app web`, `./x start app web`.
Для первого запуска или пересборки используйте `./x up`.

Приложение доступно по http://localhost. `run dev` запускает Vite на
`0.0.0.0:5173`. Очередь и планировщик уже работают под Supervisor в app,
поэтому `run dev` не запускает дополнительные экземпляры через Composer.
`run dev` включает встроенный Docker-режим `laravel-vite-plugin` через
`LARAVEL_SAIL=1`: Vite слушает `0.0.0.0`, а в `public/hot` записывает адрес
`localhost`, доступный браузеру и на Linux, и на Windows. Команда предполагает
стандартный Laravel-скрипт `scripts.dev` с Vite. Явные настройки `server` в
`vite.config.*` и дополнительные CLI-аргументы имеют приоритет.

PHP-FPM, Composer, npm, worker и scheduler работают от `www-data` с UID/GID
пользователя хоста. При старте исправляется владелец root-файлов, оставленных
старой обёрткой в `storage` и `bootstrap/cache`. Права на запись всем
пользователям не выдаются; владельцы остальных файлов проекта не меняются.
Служебные логи Supervisor направлены в stdout контейнера.

## Команды

```bash
./x up
./x stop
./x start
./x down
./x down -v                 # Также удаляет данные PostgreSQL и Redis
./x restart app web
./x run build
./x run dev
./x artisan migrate
./x composer require vendor/package
./x npm install
./x help
```

Аргументы с пробелами передавайте в кавычках, как обычной команде.
Скрипт работает и при вызове по пути из другого каталога.
Внутри app можно выполнять `bash x artisan ...`, `bash x composer ...`,
`bash x npm ...`, `bash x run ...`; управление контейнерами выполняется на хосте.

Для просмотра логов из корня проекта после создания `.env`:

```bash
docker compose logs -f app
```

## Деплой на сервере

`./x deploy` выполняется **на самом сервере без Docker**, от root либо пользователя
с беспарольным `sudo` для `systemctl` и `chown`. Нужны PHP, Composer, npm, Git,
OpenSSH, systemd и flock. Предполагается уже установленное приложение с `vendor`
и `.env`, чистый Git checkout и настроенная upstream-ветка. SSH-хост должен быть
известен серверу через `known_hosts`.

Добавьте в серверный `.env`:

```dotenv
DEPLOY_SSH_KEY=/root/.ssh/website_ed25519
DEPLOY_SERVICES="stage-notifications-queue stage-queue"
```

`DEPLOY_SERVICES` — список systemd-сервисов через пробел; при использовании
отдельного SSR-процесса включите и его сервис. Переменные окружения имеют
приоритет над `.env`. Содержимое `.env` не исполняется как shell-код.

Команда блокирует параллельный деплой, включает maintenance mode и останавливает
сервисы. Затем очищает кеши конфигурации/маршрутов/представлений/Filament,
выполняет `git pull --ff-only`, устанавливает Composer-зависимости без dev-пакетов,
запускает `npm ci --include=dev` и сборку клиента/SSR, затем миграции с `--force`.
После пересборки кешей владельцем только `storage` и `bootstrap/cache` становится
`www-data:www-data`; сервисы запускаются, maintenance mode выключается.
Прикладной кеш не очищается.

Это обновление на месте с простоем. При ошибке дальнейшие шаги не выполняются,
maintenance mode автоматически не выключается; остановленные сервисы остаются
остановленными. Исправьте причину и повторите `./x deploy`. Автоматического отката
кода и миграций нет. Настройте `TimeoutStopSec` сервисов с учётом длительности
заданий, чтобы systemd давал воркерам время завершить текущую работу.

## Worker диагностики вебхуков

В локальном app Supervisor автоматически запускает отдельную программу
`webhook-logs-worker` наряду с обычной очередью и scheduler. Она выполняет
`webhook-logs:work`, перезапускается после выхода и получает до 60 секунд на остановку.
Если образ был собран до появления этой программы, пересоздайте стек через
`./x down` и `./x up -b` (без `-v`, чтобы сохранить volumes).

Команды для ручной диагностики из корня проекта:

```bash
./x artisan webhook-logs:status --no-interaction
./x artisan webhook-logs:work --stop-when-empty --no-interaction
```

Постоянный дополнительный worker локально не требуется. Используйте именно
`webhook-logs:work`: он выбирает отдельное Redis-подключение, очередь из
`WEBHOOK_LOG_QUEUE` и отключает сохранение failed payload в своём процессе.
Обычный worker бизнес-очередей на эту очередь подписывать не нужно.

На сервере без Docker создайте отдельный systemd-сервис по существующему образцу
очередей, например `stage-webhook-logs.service`. Ниже шаблон: замените каталог,
PHP binary и пользователя на значения своего сервера. `ExecStart` запускает PHP
хоста; Docker-обёртка для этого серверного unit не используется.

```ini
[Unit]
Description=Webhook diagnostics queue
After=network.target
Requires=redis-server.service

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/var/www/laravel-project
ExecStart=/usr/bin/php /var/www/laravel-project/artisan webhook-logs:work --no-interaction
Restart=always
RestartSec=5
KillSignal=SIGTERM
TimeoutStopSec=60

[Install]
WantedBy=multi-user.target
```

Worker завершает работу через час, поэтому нужен `Restart=always`, в том числе
после успешного выхода. Timeout задания — 30 секунд, Redis retry_after — 90 секунд,
число попыток — до 3. Сервис требует установленного приложения, применённых
миграций, настроенных PostgreSQL/Redis и доступа пользователя к `.env`, `storage`
и `bootstrap/cache`. После установки unit администратор должен перечитать units
systemd, включить и запустить сервис. Этот раздел сам по себе сервер не настраивает.

После создания сервиса добавьте его к **существующему** серверному списку, например:

```dotenv
DEPLOY_SERVICES="stage-notifications-queue stage-queue stage-webhook-logs"
```

Сохраняйте остальные сервисы окружения. `./x deploy` будет останавливать и запускать
также диагностический worker. Не добавляйте имя до установки unit: ошибка
управления сервисом прервёт деплой. Уже работающий серверный scheduler нужен для
очистки каждые 15 минут и `webhook-logs:status --log` каждые 5 минут; при нескольких
scheduler-узлах используйте общий cache store с atomic locks.

Режимы, лимиты, маскирование, права Developer, временный Full и ограничения
доставки описаны в [Webhook Debugger](../docs/architecture/webhook-debug.md).

## Обновление .env

`bash _dev/env_updater [source] [target]` запускается там, где установлен PHP
(обычно внутри app). По умолчанию переносит `.env` в `laravel-dev/.env`.
Поддерживаются однострочные `KEY=value`, комментарии, CRLF, спецсимволы
и последняя строка без перевода строки. Значения не выполняются как код.
Замена атомарная, права целевого файла сохраняются; неизвестные целевые ключи
остаются на месте. Многострочные значения не поддерживаются.

## Проверки

Регрессионные проверки на Linux требуют Python 3 и PHP CLI:

```bash
python3 -m unittest discover -s _dev/tests -v
docker compose --env-file _dev/.env.example.development -f _dev/docker-compose.yml config --quiet
```

Проверки команд используют подставной Docker и временные проекты; рабочее
приложение и Docker volumes не изменяются.
