# API и модель доступа

Базовый путь — /api/v1 при стандартной конфигурации Rails.configuration.api_path.
Источники истины:
[dispatch routes](../../config/routes/dom_servis_dispatch.rb),
[request sources routes](../../config/routes/dom_servis_request_sources.rb).

## Авторизация

Контроллеры используют механизмы Zammad и Pundit.
Запрос от браузера должен нести сессию и CSRF-данные, которые передаёт существующий frontend.
Не отключайте CSRF ради удобства интеграции.

Для исследования API удобно использовать Network в DevTools на собственном тестовом окружении.
Скопированный запрос может содержать cookie/токен: не публикуйте его и не добавляйте в Git.

| Пользователь | База | Разрешение Дом-Сервиса |
| --- | --- | --- |
| Мастер | Agent | dom_servis.master |
| Диспетчер | Agent | dom_servis.dispatcher |
| Администратор | Admin; для тикетных операций также Agent | dom_servis.admin |

Названия overlay-ролей: Dom-Servis Master, Dom-Servis Dispatcher, Dom-Servis Admin.
Состав задаёт [DispatchRoleCatalog](../../app/models/dom_servis/dispatch_role_catalog.rb).

Мастер видит свои записи и свободный pool; dispatcher/admin — все записи.
Организация не изолирует записи партнёров.
Эффективные actions, statuses и fields дополнительно зависят от сохранённой DispatchPolicy.

## Маршруты заявок

Все пути ниже начинаются с /api/v1/dom_servis/dispatch.

| Метод | Путь | Назначение |
| --- | --- | --- |
| GET | /jobs | Список в разрешённой области; visit_date=YYYY-MM-DD — только заявки этого дня |
| GET | /jobs/:id | Запись |
| POST | /jobs | Создание |
| PUT/PATCH | /jobs/:id | Generic update, без смены исполнителя |
| DELETE | /jobs/:id | Удаление |
| POST | /jobs/parse_input | Черновик из текста по ключевым словам |
| POST | /jobs/:id/take | Взять |
| POST | /jobs/:id/assign | Назначить активного мастера |
| POST | /jobs/:id/release | Вернуть в pool |
| POST | /jobs/:id/status | Изменить статус |
| POST | /jobs/:id/move_day | Изменить день |
| POST | /jobs/:id/change_priority | Изменить приоритет |
| POST | /jobs/:id/resync_ticket | Повторить синхронизацию backing ticket (диспетчер, администратор); 422, если снова не удалось |
| GET | /jobs/:job_id/events | История |
| GET/POST | /jobs/:job_id/attachments | Список / добавление файла |
| GET/DELETE | /jobs/:job_id/attachments/:id | Чтение / удаление файла |

Вложения используют собственный controller и контракт загрузки.
Не рассматривайте upload как обычный JSON CRUD — сверяйте
[attachments_controller](../../app/controllers/dom_servis/dispatch/attachments_controller.rb).

### Примеры тел запросов

Создание через POST /jobs, с тестовыми данными:

```json
{
  "service_type": "Сантехника",
  "address": "Тестовый адрес",
  "client_name": "Тестовый клиент",
  "client_phone": "+70000000000",
  "visit_date": "2026-09-07",
  "visit_day": "mon",
  "visit_time": "10:00",
  "priority": "medium",
  "status": "pool",
  "source": "manual",
  "work_tags": []
}
```

Дату и контакты заменить в тесте; произвольные новые work_tags backend не принимает.
Названия тегов должны существовать в общем словаре Zammad.

Поля ручного расписания используют единый backend-контракт: visit_date — реальная дата строго
в формате YYYY-MM-DD, visit_time — необязательное время HH:MM или окно HH:MM-HH:MM, а visit_day
должен соответствовать дню недели visit_date. Некорректная или противоречивая комбинация
возвращает 422. Первичный intake может сохранить свободный текст visit_time как snapshot источника;
любое последующее ручное изменение этого поля уже проверяется по каноническому формату.

Назначение:

```json
{ "assignee_id": 42 }
```

42 — пример ID, нужен реальный активный master.
Для status:

```json
{ "status": "in_progress" }
```

Допустимые переходы статуса задаёт [DispatchWorkflow](../../app/models/dom_servis/dispatch_workflow.rb),
модель описана в [архитектуре](architecture.md#модель-статусов).
Недопустимый переход возвращает 422, отсутствие нужного действия или статуса в политике — 403.
POST /jobs создаёт заявку только в pool: assignee_id, published_at, taken_at, completed_at, closed_at,
cancelled_at и status, отличный от pool, дают 422. Мастер назначается через assign или take.

Эти примеры не заменяют текущие strong params.
Ответы generic CRUD формирует Zammad; нельзя считать, что для всех действий существует один response envelope.

### История заявки

GET /jobs/:job_id/events возвращает события заявки, новые первыми:
event_type, actor_user_id, actor_name (имя автора), meta, created_at.
Каждое изменение бизнес-полей попадает в историю со старым и новым значением:

| Событие | meta |
| --- | --- |
| created, published | при создании на доске и при приёме из формы/webhook/AI; для приёма в created: source, request_source_id, channel_key, source_reference |
| status_changed, priority_changed, moved_weekday, organization_changed | from, to |
| taken | пусто: мастер — actor_user_id, переход pool → taken |
| assigned | from, to (id мастера); status {from, to}, если назначение перевело заявку из pool |
| released | from (id снятого мастера), status {from, to} |
| attachment_added, attachment_removed | attachment_id, kind, filename |
| comment_added, description_updated | новое значение (comment / description) и прежнее в from |
| tags_changed | from, to |
| updated | changes: { поле: { from, to } } для остальных полей: адрес, клиент, телефон, услуга, дата и время визита, источник, снятый при возврате в pool мастер |

Запрос, который ничего не изменил, событие не создаёт.
Удаление заявки удаляет и её историю.

## Политика, теги и источники

| Метод | Путь | Назначение |
| --- | --- | --- |
| GET | /api/v1/dom_servis/dispatch/policy | Эффективные правила текущего пользователя |
| GET/PUT/PATCH | /api/v1/dom_servis/dispatch/admin_policy | Чтение / сохранение административной политики |
| POST | /api/v1/dom_servis/dispatch/admin_policy/reset | Сброс политики |
| GET | /api/v1/dom_servis/dispatch/tags | Общий словарь и использование тегов |
| GET/POST | /api/v1/dom_servis/request_sources | Список / создание источника |
| GET/PUT/PATCH/DELETE | /api/v1/dom_servis/request_sources/:id | Работа с источником |
| GET/POST | /api/v1/dom_servis/request_sources/search | Поиск источников |

Формат административной матрицы формируется registry DispatchPolicy.
Клиент не должен подменять серверные проверки прав.

## Push-подписки

Фактический префикс: /api/v1/dom_servis/dispatch/push_subscriptions.

| Метод | Путь относительно префикса | Назначение |
| --- | --- | --- |
| POST | / | Сохранить подписку текущего пользователя |
| DELETE | /:id | Удалить разрешённую подписку |
| POST | /test | Поставить тестовые сообщения в очередь |

Тело подписки содержит endpoint и keys.p256dh / keys.auth.
Проверяйте [controller](../../app/controllers/dom_servis/push_subscriptions_controller.rb)
и [политику](../../app/policies/dom_servis/push_subscription_policy.rb).

HTTP success от /test подтверждает постановку в очередь, а не доставку на устройство.

## Ошибки и инварианты

- 401/403: аутентификация, разрешения, policy или запрещённое действие.
- 404: неверный ID или запись недоступна в scope.
- 409 при take: другой исполнитель уже забрал запись.
- 422: невалидные параметры или нарушенное условие действия.

Точное преобразование исключений выполняет инфраструктура Zammad.
Для диагностики сохраняйте HTTP status и тело, а не только сообщение UI.

Нельзя менять assignee через generic update.
Статус через generic update проходит ту же проверку перехода, что и /status.
Взятие должно сохранять атомарность.
Статус, доступ к полю и доступ к записи проверяются разными механизмами.
Если меняется API, обновляйте целевые request-тесты и вызывающий legacy frontend.

[К началу документации](../../developer.md)
