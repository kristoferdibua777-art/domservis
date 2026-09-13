# Локальная разработка и типовые изменения

## Получение проекта

Два репозитория должны быть соседями. Из выбранного рабочего каталога:

```bash
git clone https://github.com/koronamedia/Svib-Home-Service.git
git clone https://github.com/koronamedia/Svib-Home-Service-docker-compose.git
```

Ожидаемая структура:

```text
workspace/
  Svib-Home-Service/
  Svib-Home-Service-docker-compose/
```

В существующем checkout сначала выполните в каждом репозитории:

```bash
git status --short
git branch --show-current
git remote -v
```

Не перетирайте незакоммиченные изменения.
Создавайте ветку задачи от согласованной базы; имя и целевой релиз определяются задачей.

## Выбор окружения

| Режим | Для чего | Ограничения |
| --- | --- | --- |
| Полный локальный образ | Проверка доставки, migrations, скомпилированного UI | Пересборка занимает время |
| front-dev | Итерации Rails/Vue/legacy UI из исходников | Использует базу и storage основного Compose |
| Zammad devcontainer | Разработка с полноценными тестовыми зависимостями | Нужна отдельная настройка |
| Mobile sandbox | Эксперименты оформления | Нет настоящих API и прав |

### Полный локальный образ

В PowerShell, из runtime-репозитория:

```powershell
.\scripts\up-local.ps1
```

Скрипт использует соседние исходники, Dockerfile и docker-compose.local-build.yml.
Адрес по умолчанию — http://localhost:8080.
IMAGE_REPO и VERSION из окружения могут переопределить локальные defaults.

Остановка:

```powershell
.\scripts\down-local.ps1
```

На Linux эквивалент запуска из runtime-репозитория:

```bash
IMAGE_REPO=dom-servis/zammad-local VERSION=local ZAMMAD_BUILD_COMMIT_SHA=$(git -C ../Svib-Home-Service rev-parse HEAD) docker compose -f docker-compose.yml -f docker-compose.local-build.yml up -d --build
```

Не используйте серверную .env с клиентскими данными для локального тестирования.
На чистой базе выполните первоначальную настройку и подготовку модуля из [install.md](../../install.md).

### Front-dev

Из runtime-репозитория в PowerShell:

```powershell
.\scripts\up-front-dev.ps1 -Rebuild
```

Последующие запуски без перестройки образа:

```powershell
.\scripts\up-front-dev.ps1
```

Порты по умолчанию: Rails 3001, Vite 3036, websocket 6043.
Настройки — docker-compose.front-dev.yml runtime-репозитория.

Контейнер монтирует код в /opt/zammad и использует
[Dockerfile.front-dev](../../Dockerfile.front-dev) и
[entrypoint](../../docker/front-dev-entrypoint.sh).

На Linux сначала запустите зависимости, затем front-dev:

```bash
docker compose -f docker-compose.yml up -d zammad-postgresql zammad-redis zammad-memcached zammad-elasticsearch
docker compose -f docker-compose.yml -f docker-compose.front-dev.yml up -d --build zammad-front-dev
```

Это не отдельная тестовая база.
Если одновременно работают scheduler основного стека и worker front-dev, они используют общее окружение.
Для воспроизводимой проверки фоновых задач избегайте смешивания версий кода в этих процессах.

BUNDLE_WITHOUT=test в front-dev означает, что это не готовый RSpec-контейнер.
Для RSpec используйте отдельное тестовое окружение.

### Devcontainer

Официальный путь платформы:
[devcontainer setup](../developer_manual/development_environment/devcontainer-setup.md),
[manual setup](../developer_manual/development_environment/manual-setup.md).

Не запускайте pnpm dev как универсальное решение в неподготовленном Windows shell:
ему нужны Rails, зависимости, БД и процессы из Procfile.dev.
Учитывайте .ruby-version, packageManager и конфигурацию среды.

## Рецепты изменений

### Изменить карточку или кнопку

1. Найти обработчик в dispatch_board.coffee.
2. Найти соответствующий блок board.jst.eco.
3. Обновить CSS для desktop и mobile.
4. Проверить роль, состояние загрузки, ошибку API и повторный рендер.
5. Проверить итоговые скомпилированные assets в локальном образе.

ECO и CoffeeScript имеют собственный синтаксис: не вставляйте в них JavaScript/Vue конструкции автоматически.
В июльской истории есть серия исправлений компиляции именно на этой границе.

### Добавить поле заявки

1. Миграция схемы DispatchJob.
2. Валидация, defaults и нормализация в модели.
3. Strong params контроллера.
4. FIELD_METADATA / политика видимости и редактирования.
5. JS-модель, форма, карточка.
6. Решение: проецируется ли поле в Ticket и влияет ли на приём формы?
7. Тест сохранения, запрета изменения чужой ролью и round-trip через UI.

Не добавляйте поле только в шаблон: generic edit зависит от матрицы полей.

### Добавить действие или статус

Проверить одновременно:
STATUSES, registry политики, default-матрицы, controller guards, record policy,
события, lifecycle timestamps, mapper тикета, фильтры UI и callbacks уведомлений.

Не предполагать, что наличие статуса в перечислении уже описывает все допустимые переходы.
Условия перехода должны проверяться сервером.

### Изменить партнёрскую форму

Начать с [контракта](../dom-servis-partner-intake-registry.md), RequestSource,
FormController, TicketAdapter, DispatchJobCreator и embed HTML.
Проверять токен, paused-источник, origin, организацию, повторный запрос и высоту iframe.

Добавление source=email/webhook/ai в перечисление не создаёт готовый транспорт приёма.

### Изменить уведомления

Различать:
событие обновления доски, OnlineNotification, очередь Web Push и системное уведомление устройства.
Для новой ветки события проверить получателей, повторную отправку, удалённую подписку и ошибки провайдера.
Проверять scheduler отдельно от ответа HTTP API.

## Windows и файлы

Читать текст PowerShell-командой Get-Content -Encoding UTF8 -LiteralPath.
Если кириллица выглядит повреждённой, сначала проверить декодирование терминала.

Dockerfile нормализует CRLF для ряда файлов. Изменения строк интерфейса проверять в браузере,
а не только по содержимому файла.

## Перед передачей изменения

Использовать [целевые проверки](testing.md).
После изменения контракта обновить этот комплект документации и основной partner intake-документ.
Не переносить локальные реквизиты, снимки БД или историю пользовательских чатов в репозиторий.

[К началу документации](../../developer.md)

