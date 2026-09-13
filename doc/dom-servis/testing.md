# Проверки и диагностика

## Уровни доказательства

Различайте:
синтаксическая проверка → unit/request-тест → интеграция с БД/очередью →
браузерный сценарий → проверка выпущенного образа.

Успешный RSpec не подтверждает push на телефоне.
HTTP 200 от формы не подтверждает создание корректной DispatchJob.
Успешная сборка не подтверждает работоспособность после миграции.

## Тестовое окружение

Рекомендуемый путь RSpec — отдельный devcontainer по
[инструкции платформы](../developer_manual/development_environment/devcontainer-setup.md).
Подготовка БД и assets описана в
[RSpec manual](../developer_manual/cookbook/how-to-test-with-rspec-and-capybara.md).

Не выполнять db:drop, bootstrap/reset или test preparation в production-контейнере
либо в front-dev с общей рабочей DATABASE_URL.
Сначала подтвердите RAILS_ENV и имя фактической базы.

Front-dev по умолчанию исключает test gems; простая команда rspec внутри него может не работать.

В подготовленном тестовом окружении, из корня приложения:

```bash
RAILS_ENV=test bundle exec rspec spec/models/dom_servis spec/requests/dom_servis spec/services/dom_servis
```

Целевые проверки:

```bash
RAILS_ENV=test bundle exec rspec spec/requests/dom_servis/dispatch/jobs_controller_spec.rb
RAILS_ENV=test bundle exec rspec spec/services/dom_servis/dispatch/backing_ticket_spec.rb
RAILS_ENV=test bundle exec rspec spec/services/dom_servis/intake/dispatch_job_creator_spec.rb
RAILS_ENV=test bundle exec rspec spec/requests/form_spec.rb
RAILS_ENV=test bundle exec rspec spec/models/user/dom_servis_ticket_group_access_spec.rb
```

Фактическое покрытие следует читать: в request-тесте jobs_controller синхронизация тикета замокана.
Поэтому его успешное выполнение не заменяет bridge-тесты и проверку реального потока.

### Vue

В Linux/devcontainer с установленными frontend-зависимостями:

```bash
pnpm test --run app/frontend/apps/mobile/components/layout/__tests__/LayoutBottomNavigation.spec.ts
```

Другие команды:
[package.json](../../package.json),
[Vitest/Cypress manual](../developer_manual/cookbook/how-to-test-with-vitest-and-cypress.md).

Vue-тесты навигации не покрывают основную CoffeeScript-доску.
Для legacy используйте проверку компиляции образа и browser smoke; при необходимости
[QUnit](../developer_manual/cookbook/how-to-test-with-qunit.md).

## Матрица приёмки

| Изменённая область | Минимальный сценарий |
| --- | --- |
| Создание заявки | Разрешённый оператор создаёт, сохраняются job/event/ticket |
| Назначение | Dispatcher назначает master; обычному master это запрещено |
| Взятие | Два разных мастера пытаются взять одну заявку; только один получает владение |
| Поля | Разрешённая роль меняет поле; запрещённая не может через прямой API |
| Статусы | Поля времени, фильтры и backing ticket соответствуют результату |
| Теги | Известный тег сохраняется и синхронизируется; неизвестный отвергается |
| Форма | Токен, paused, origin, организация, дубль, Ticket → DispatchJob |
| Realtime | Второй сеанс видит изменение; открытая форма не теряет ввод |
| Вложения | Upload/download/delete, права, тип вложения, ошибка файла |
| Push | Подписка, очередь, работа scheduler, доставка на реальное устройство |
| Миграции | Чистая база и обновление существующей базы |
| Mobile | Узкий экран, прокрутка, действие одной рукой, reload и повторный вход |

Не используйте один браузерный сеанс для проверки двух ролей.
Для кириллицы проверяйте значение в файле, API и отображение после сборки.

## Диагностика по цепочке

### Кнопка не появилась

Проверить маршрут, активную роль, effective policy, условие шаблона и реально загруженные assets.
Не менять права, пока не доказано, что причина в них.

### Заявка не публикуется

Network: HTTP status/body → Rails logs → validation/policy →
доступ оператора к группе → ошибка backing ticket.

### Заявка есть, тикет расходится

Проверить вызов sync_backing_ticket! и логи.
Не все update-операции откатывают изменение DispatchJob при ошибке проекции.

### Доска не обновилась

Проверить websocket, событие PushMessages, обработчик, pending refresh,
открытые create/edit формы и ответ повторного REST GET.

### Push не пришёл

1. HTTPS и правильный /dispatch/ маршрут.
2. Разрешение браузера/ОС.
3. Активная PushSubscription пользователя.
4. Оба VAPID-ключа.
5. Задание в очереди и scheduler.
6. Ответ WebPushSender и состояние подписки после ошибки.
7. Реальное системное уведомление.

Не генерировать новые VAPID-ключи как универсальный способ диагностики.

## Полезные команды runtime

Из каталога Compose:

```bash
docker compose ps -a
docker compose logs --tail=100 zammad-init zammad-railsserver zammad-nginx
docker compose logs --tail=100 zammad-scheduler zammad-websocket
docker compose exec -T zammad-railsserver bundle exec rake dom_servis:webpush:status
```

В полном локальном образе это те же сервисы.
При front-dev смотреть также контейнер zammad-front-dev соответствующего Compose-набора.

## Отчёт о проверке

Фиксировать commit, окружение, команду/сценарий, результат и непроверенные части.
Для UI — viewport, роль и скриншот при необходимости.
Для багов — воспроизведение до исправления и после него.

[К началу документации](../../developer.md)

