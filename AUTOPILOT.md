# AUTOPILOT

Рабочий журнал автономного воркера по DomServis. Раздел «Бэклог» редактирует человек,
в раздел «Журнал» воркер только дописывает записи (новые — внизу).

Правила запуска: [.dev/ai-agent-instructions.md](.dev/ai-agent-instructions.md),
[developer.md](developer.md), [doc/dom-servis/limitations.md](doc/dom-servis/limitations.md).
Деплой ([install.md](install.md)) без явного запроса не трогать.

## Бэклог

Порядок = приоритет.

1. Довести до готовности к мержу серию «Round 7»: ветки `fix/rubocop-baseline` и
   `fix/round7-rspec-vitest-diagnostics` (RuboCop, переводы, нестабильные тесты,
   RSpec/Vitest диагностика). Цель — зелёный CI на GitHub Actions.
2. После пункта 1 — продолжить `feat/partner-intake-db-foundation`
   (фундамент БД для приёма заявок от партнёров).

## Журнал

### 2026-09-18 — первый запуск (только разведка, кодовых правок нет)

**Окружение.** Рабочая копия: `C:\Users\user\domservis-round7-clean`.
Доступно: git, Node 24. Отсутствуют: Ruby/bundler, pnpm (corepack не запустился), `gh`, WSL.
GitHub API без токена упирается в rate limit, встроенный браузер к github.com не допущен.
Следствие: RSpec, RuboCop, Vitest и `pnpm lint` локально не запускались,
статус CI/PR прочитать не удалось.

**Состояние веток (по `git ls-remote` и `git log`, на 2026-09-18).**

- `origin/main` = `088efff`; он предок `fix/rubocop-baseline`, конфликтов при мерже не ожидается.
- `origin/fix/rubocop-baseline` = `762c7de`, на 33 коммита впереди `main`. Содержит перевод каталога,
  RuboCop-правки Round 7 и два последних коммита про Vitest-таймаут
  (`098678b` «avoid nested async waits», `762c7de` «wait for expected FormUpdater call count»).
- `origin/fix/round7-rspec-vitest-diagnostics` = `cfd24d3`. Это более ранний вариант того же фикса
  (`current_user_id: 1` на четырёх DomServis-спеках, диагностический workflow). Всё это уже есть в
  `fix/rubocop-baseline` (коммит `9cec6bf` + RuboCop-правки), поэтому ветка выглядит замещённой.
  Закрывать ли её — решение человека.
- `origin/feat/partner-intake-db-foundation` = `08424cf`: 2 коммита, на 4 позади `main`. Не начиналась.

**Что мешает мержу `fix/rubocop-baseline` (временные артефакты, которые должны уйти).**

- `.github/workflows/test-diagnostic.yml` — запускается на каждом `pull_request` и дублирует `ci.yaml`;
  сам называется «temporary».
- `.github/workflows/rubocop-autofix.yml`, `.github/workflows/translation-catalog-fix.yml` —
  вспомогательные workflow, нужно решить, оставлять ли их в `main`.
- `app/frontend/tests/support/diagnostic-ticket-create-user.ts`, вызовы `diagnosticTicketCreateUserLog`
  в `ticket-create-user.spec.ts`, диагностические типы в `app/frontend/tests/graphql/builders/mocks.ts`.
  (Заглушка `scrollTo` в `vitest.setup.ts` — обычная правка jsdom, не диагностика, её не удалять.)

Удалять их нужно отдельным коммитом только после зелёного прогона Vitest и RSpec на `762c7de`.
Иначе теряется инструмент для расследования таймаута, если он всё ещё воспроизводится.

**Что дальше.**

1. Человеку: открыть последний прогон «Test diagnostic (temporary)» на `762c7de` и приложить итоги
   стадий Vitest / RSpec / Minitest (или выдать воркеру `gh` с токеном / `GITHUB_TOKEN`).
2. Если Vitest и RSpec зелёные: коммит «Remove temporary Round 7 diagnostics» (список выше),
   затем повторный прогон CI.
3. Если красные: править минимально по логам, а не вслепую.
4. Для следующего запуска воркеру нужны Ruby 3.4.9 (см. `Gemfile`) с bundler и pnpm.
   Иначе проверки из правил проекта выполнить нельзя.
5. После зелёного Round 7 — пункт 2 бэклога (rebase `feat/partner-intake-db-foundation` на актуальный `main`).
