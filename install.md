# Установка «Дом-Сервиса» на VPS с Ubuntu

Пошаговая инструкция для владельца сервиса. Опыт программирования не нужен.

Сценарий — **новая установка на отдельном VPS**. Ubuntu, SSH, sudo, Docker и базовая безопасность уже настроены специалистом. Образ лежит на GitHub; собирать исходники на VPS не требуется.

## Содержание

1. [Что понадобится](#requirements)
2. [Подключение к серверу](#ssh)
3. [Домен и DNS](#dns)
4. [Выбор версии на GitHub](#image)
5. [Каталог и настройки](#configuration)
6. [HTTPS](#https)
7. [Первый запуск](#start)
8. [Администратор](#admin)
9. [Диспетчер и мастер](#staff)
10. [Уведомления](#notifications)
11. [Первая заявка](#first-job)
12. [Резервная копия](#backup)
13. [Обновление](#update)
14. [Устранение проблем](#troubleshooting)
15. [Проверка результата](#checklist)

<a id="requirements"></a>
## 1. Что понадобится

### Ресурсы VPS

| Параметр | Нижний ориентир для знакомства | Для рабочего сервиса по этой инструкции |
| --- | --- | --- |
| Процессор | 2 vCPU | 4 vCPU |
| RAM | 4 ГБ — ограниченный тест, стабильность не гарантируется | 12 ГБ или больше |
| Диск | 40 ГБ SSD — небольшой объём тестовых данных | От 80 ГБ SSD, с запасом под фото и копии |
| Архитектура | x86_64 / amd64 | x86_64 / amd64 |
| ОС | Ubuntu Server 24.04 LTS | Ubuntu Server 24.04 LTS |
| Сеть | Публичный IPv4, доступ в интернет | То же |

**Почему не обещаем полноценную работу на 4 ГБ:** Docker-инструкция Zammad указывает 4 ГБ как порог запуска контейнеров, а рекомендации по оборудованию — 6 ГБ для приложения с PostgreSQL и ещё 4 ГБ для Elasticsearch на том же сервере. Здесь запускается полный стек с Elasticsearch. Для рабочего VPS выбран запас — 12 ГБ. VPS на 4 ГБ лучше увеличить до установки; отключение поиска не входит в основной сценарий.

40/80 ГБ диска — стартовый ориентир этой инструкции, а не гарантия для любого количества заявок. Файлы, старые образы и копии расходуют место.

Источники: [оборудование Zammad](https://docs.zammad.org/en/latest/prerequisites/hardware.html), [Docker-установка](https://docs.zammad.org/en/latest/install/docker-compose.html).

Образ проекта собирается для linux/amd64. ARM-сервер для этой инструкции не подходит.

### Доступы и программы

Подготовьте:

- IP сервера, имя SSH-пользователя и пароль либо настроенный ключ.
- Возможность выполнять sudo.
- Собственный домен и доступ к управлению DNS.
- Рабочий email администратора.
- На компьютере — браузер и PowerShell в Windows либо Terminal в macOS/Linux.

На VPS нужны Docker Engine, **Docker Compose 2.24.4 или новее**, Git, curl, openssl и nano.

Порты 80/tcp и 443/tcp должны быть свободны и разрешены как в firewall Ubuntu, так и в сетевых правилах провайдера. SSH должен оставаться доступным.

### Как читать команды

Три места работы:

- **На компьютере:** SSH и браузер.
- **В панели домена:** DNS.
- **На VPS:** команды после подключения SSH.

Копируйте команды из блоков и нажимайте Enter. После ошибки сначала устраните её, затем переходите дальше. Пароль SSH/sudo может вводиться без отображения символов — это нормально.

После многострочной команды дождитесь возврата приглашения терминала. Ctrl+C прекращает просмотр логов, но не останавливает Docker-контейнеры.

| Пример в инструкции | Чем заменить |
| --- | --- |
| 203.0.113.10 | Публичный IP вашего VPS |
| deploy | Ваш SSH-пользователь |
| master.example.ru | Ваш домен приложения, без https:// и завершающего / |
| admin@example.ru | Ваш email |
| Тег образа | Значение с GitHub из раздела 4 |

Не используйте примерные IP, домен и email как реальные настройки.

<a id="ssh"></a>
## 2. Подключение к серверу

**На компьютере** откройте терминал:

~~~bash
ssh deploy@203.0.113.10
~~~

Замените пользователя и IP. Для нестандартного SSH-порта, например 2222:

~~~bash
ssh -p 2222 deploy@203.0.113.10
~~~

При первом подключении сверьте показанный отпечаток сервера с данными специалиста или панели VPS, затем подтвердите подключение.

**Теперь на VPS:**

~~~bash
uname -m
free -h
df -h /
sudo docker version
sudo docker compose version
git --version
command -v curl openssl nano
sudo ss -ltnp '( sport = :80 or sport = :443 )'
~~~

Ожидается x86_64, Docker Client и Server без ошибок, Compose 2.24.4 или новее, найденные программы и отсутствие чужих процессов на 80/443.

Задайте параметр ядра для Elasticsearch:

~~~bash
printf 'vm.max_map_count=1048576\n' | sudo tee /etc/sysctl.d/99-dom-servis.conf
sudo sysctl --system
sysctl vm.max_map_count
~~~

Последняя команда должна показать 1048576. Настройка сохраняется после перезагрузки.

<a id="dns"></a>
## 3. Домен и DNS

**В браузере на компьютере:**

1. Откройте панель сервиса, обслуживающего DNS вашего домена: регистратора или DNS-провайдера.
2. Перейдите в DNS / DNS-записи.
3. Для приложения master.example.ru создайте:

| Поле | Значение |
| --- | --- |
| Тип | A |
| Имя / Host | master |
| Значение / IP | IP вашего VPS |
| TTL | Автоматически или 300 |

Некоторые панели требуют полное master.example.ru вместо master. Для установки на основном example.ru обычно указывают @ вместо master. Тогда во всех остальных шагах используйте example.ru.

4. Замените старую A-запись или CNAME того же имени, чтобы не осталось конфликта.
5. Не создавайте AAAA без настроенного IPv6. Старая AAAA на другой сервер может мешать HTTPS.
6. В Cloudflare выберите **DNS only**, без оранжевого облака. Эта инструкция использует Caddy на VPS, а не Cloudflare Tunnel.

Подождите обновления DNS: обычно несколько минут, но старые кеши могут сохраняться до срока TTL.

**На VPS:**

~~~bash
getent ahostsv4 master.example.ru
~~~

Замените домен. Результат должен содержать IP вашего VPS. Не переходите к HTTPS, пока DNS указывает на другой сервер.

<a id="image"></a>
## 4. Как выбрать тег образа на GitHub

Образ — готовая сборка программы. Тег — обозначение версии.

**В браузере:**

1. Откройте [пакет svib-dom-servis](https://github.com/koronamedia/Svib-Home-Service/pkgs/container/svib-dom-servis).
2. Найдите Recent tagged image versions. Для полного списка — View all tagged versions.
3. Скопируйте у нужной свежей версии конкретный тег manual-… или release-….
4. Если такого обозначения нет, подойдёт полный sha-… из той же версии.
5. При сомнениях откройте [сборки docker-release](https://github.com/koronamedia/Svib-Home-Service/actions/workflows/docker-release.yaml): нужная сборка должна завершиться зелёным success. Это подтверждает сборку, но не приёмку всех функций продукта.

На дату подготовки опубликована версия **manual-20260715-13**, связанная с cdc71a1bd8. Это пример; при установке проверьте список заново.

Для фиксации версии не выбирайте плавающие develop или latest. Надпись Latest на странице GitHub не означает, что нужно вводить слово latest.

Если GitHub показывает:

~~~text
docker pull ghcr.io/koronamedia/svib-dom-servis:manual-20260715-13
~~~

то в VERSION дальше вставьте только:

~~~text
manual-20260715-13
~~~

Пакет публичный на дату проверки. Для скачивания аккаунт GitHub и токен не нужны.

<a id="configuration"></a>
## 5. Каталог и настройки

Все команды ниже — **на VPS**.

### 5.1. Скачайте конфигурацию запуска

~~~bash
sudo mkdir -p /srv/dom-servis
sudo chown "$USER":"$(id -gn)" /srv/dom-servis
git clone https://github.com/koronamedia/Svib-Home-Service-docker-compose.git /srv/dom-servis
cd /srv/dom-servis
~~~

Если каталог не пуст, не удаляйте его: проверьте, не установлено ли приложение ранее. Для существующей установки используйте раздел обновления.

На VPS нужен **Svib-Home-Service-docker-compose**. Репозиторий исходного приложения клонировать не требуется.

Все дальнейшие команды sudo docker compose выполняются из /srv/dom-servis. После нового подключения сначала:

~~~bash
cd /srv/dom-servis
~~~

### 5.2. Создайте .env

~~~bash
cp .env.dist .env
chmod 600 .env
openssl rand -hex 24
~~~

Последняя команда выдаст случайную строку — пароль внутренней базы. Сохраните её в менеджере паролей. Это не пароль входа в приложение.

~~~bash
nano .env
~~~

В начало файла вставьте блок, заменив тег, домен и пароль:

~~~dotenv
COMPOSE_PROJECT_NAME=dom-servis
IMAGE_REPO=ghcr.io/koronamedia/svib-dom-servis
VERSION=ВСТАВЬТЕ_ТЕГ_С_GITHUB
ZAMMAD_FQDN=master.example.ru
ZAMMAD_HTTP_TYPE=https
NGINX_SERVER_NAME=master.example.ru
NGINX_SERVER_SCHEME=https
POSTGRES_PASS=ВСТАВЬТЕ_СЛУЧАЙНУЮ_СТРОКУ
TZ=Europe/Moscow
RESTART=unless-stopped
ELASTICSEARCH_ENABLED=true
ELASTICSEARCH_JAVA_OPTS=-Xms1g -Xmx1g
BACKUP_TIME=03:00
HOLD_DAYS=7
~~~

Правила:

- Домен в ZAMMAD_FQDN и NGINX_SERVER_NAME одинаковый, без https://.
- VERSION — только тег.
- POSTGRES_PASS — строка из openssl, без пробелов.
- TZ — часовой пояс операторов, например Europe/Moscow или Asia/Krasnoyarsk.
- Строки с # — комментарии. Не оставляйте две активные строки одного параметра.
- После первого запуска не меняйте POSTGRES_PASS как обычную настройку: пароль существующей базы автоматически не изменится.

В nano: **Ctrl+O → Enter** — сохранить, **Ctrl+X** — выйти.

### 5.3. Добавьте HTTPS-контейнер

~~~bash
nano docker-compose.override.yml
~~~

Вставьте целиком, сохраняя отступы пробелами:

~~~yaml
services:
  zammad-nginx:
    ports: !override []

  caddy:
    image: caddy:2
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy-data:/data
      - caddy-config:/config
    depends_on:
      - zammad-nginx

volumes:
  caddy-data:
  caddy-config:
~~~

Сохраните и выйдите.

Compose автоматически читает docker-compose.yml и docker-compose.override.yml. Основной файл менять не нужно.

ports: !override [] убирает публикацию приложения на 8080. Снаружи работают только 80/443 Caddy; nginx доступен внутри сети контейнеров.

Эта конструкция требует [Compose 2.24.4 или новее](https://docs.docker.com/reference/compose-file/merge/).

<a id="https"></a>
## 6. HTTPS

Caddy получает и продлевает сертификат, затем передаёт запросы приложению.

~~~bash
nano Caddyfile
~~~

Вставьте, **заменив домен своим**:

~~~caddyfile
master.example.ru {
    reverse_proxy zammad-nginx:8080
}
~~~

Сохраните и выйдите. Домен должен совпадать с .env.

Для HTTPS необходимы правильный DNS, доступные 80/443, исходящий интернет и сохранность caddy-data, где хранятся сертификаты. Caddy запускается в следующем разделе вместе с приложением.

Покупать сертификат или запускать certbot не нужно. Caddy поддерживает WebSocket приложения. Источники: [автоматический HTTPS](https://caddyserver.com/docs/automatic-https), [reverse_proxy](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy).

<a id="start"></a>
## 7. Первый запуск

### 7.1. Проверка и скачивание

~~~bash
sudo docker compose config --quiet
sudo docker compose config --images
~~~

Первая команда при успехе ничего не выводит. Вторая должна показать ghcr.io/koronamedia/svib-dom-servis с вашим тегом, caddy:2 и инфраструктурные образы.

Если видите ghcr.io/zammad/zammad, вернитесь к .env.

~~~bash
sudo docker compose pull
~~~

Дождитесь завершения без ошибок. При первом скачивании загружается несколько больших образов.

### 7.2. Запуск

~~~bash
sudo docker compose up -d
sudo docker compose ps -a
sudo docker compose logs -f --tail=100 zammad-init
~~~

Правильная команда — **docker compose up -d**. Флаг -d запускает в фоне. Команда docker -a -d для этого не используется.

zammad-init подготавливает базу и поиск. В первые минуты сообщения об ожидании допустимы. Дождитесь завершения; Ctrl+C закрывает просмотр логов.

~~~bash
sudo docker compose ps -a
~~~

Нормально:

- zammad-init — **Exited (0)**: разовая задача завершена.
- Рабочие сервисы — **Up / running**.
- Постоянный Restarting или Exited с ненулевым кодом — ошибка.

Если 10–15 минут нет прогресса, откройте раздел устранения проблем вместо многократных перезапусков.

### 7.3. Подготовка модуля на чистой базе

В текущей версии часть настроек Дом-Сервиса может пропускаться до первоначального наполнения Zammad. Следующий блок добавляет недостающую конфигурацию после завершения init. Он не задаёт пароли и не создаёт сотрудников.

Скопируйте **весь блок целиком**:

~~~bash
sudo docker compose exec -T zammad-railsserver bundle exec rails runner - <<'RUBY'
abort 'Сначала дождитесь завершения zammad-init' unless Setting.exists?(name: 'system_init_done')

require Rails.root.join('db/migrate/20260318130001_add_dom_servis_dispatch_permissions').to_s
AddDomServisDispatchPermissions.new.up

require Rails.root.join('db/migrate/20260318212000_create_dom_servis_dispatch_policy_setting').to_s
CreateDomServisDispatchPolicySetting.new.up

require Rails.root.join('db/migrate/20260710120100_add_dom_servis_webpush_settings').to_s
AddDomServisWebpushSettings.new.up

require Rails.root.join('db/migrate/20260322010000_add_dom_servis_backing_ticket_fields').to_s
missing_fields = AddDomServisBackingTicketFields::FIELD_DEFINITIONS.any? do |field|
  ObjectManager::Attribute.get(object: 'Ticket', name: field[:name]).blank?
end
AddDomServisBackingTicketFields.new.up if missing_fields

DomServis::DispatchRoleCatalog.sync!
puts 'Дом-Сервис: настройки, поля и роли подготовлены.'
RUBY
~~~

Ожидается сообщение «Дом-Сервис: настройки, поля и роли подготовлены.». Если отсутствует файл или класс, версия отличается от описанной: передайте ошибку разработчику, не пропускайте шаг молча.

### 7.4. Открытие сайта

~~~bash
sudo docker compose logs --tail=100 caddy
~~~

**В браузере на компьютере** откройте свой адрес:

~~~text
https://master.example.ru
~~~

Должна появиться первоначальная настройка без предупреждения о сертификате. Название Zammad нормально: на нём построен Дом-Сервис.

Сразу создайте своего администратора по следующему разделу; не оставляйте первоначальный мастер незавершённым.

<a id="admin"></a>
## 8. Администратор

**В браузере:**

1. Выберите новую систему / Set up new system, а не импорт.
2. Укажите имя, фамилию, email и новый надёжный пароль.
3. Сохраните пароль.
4. Укажите название организации.
5. Если требуется URL, введите ваш адрес с https://.
6. Подключение почты можно пропустить и настроить позже. Для доски и Web Push SMTP не нужен.
7. Завершите мастер.

Названия кнопок могут немного отличаться по версии и языку.

Откройте **Администрирование → Пользователи**:

~~~text
https://master.example.ru/#manage/users
~~~

В своей записи проверьте роли:

- Admin.
- Agent.
- Dom-Servis Admin.

Добавьте недостающие. Не снимайте Admin с единственного администратора.

Для группы **Users** установите **Полный доступ / Full**, если ещё не выдан: он нужен связанным тикетам.

Сохраните, выйдите и войдите снова, чтобы обновились права. В личных настройках выберите русский язык и часовой пояс.

| Путь после вашего домена | Назначение |
| --- | --- |
| /#dom_servis/dispatch | Доска |
| /#manage/dom_servis_dispatch | Настройки политики |
| /#manage/users | Пользователи |
| /dispatch/ | Версия для установки на телефон |

<a id="staff"></a>
## 9. Диспетчер и мастер

Под администратором откройте **Администрирование → Пользователи → Новый пользователь**.

Создайте две отдельные записи:

| Поле | Диспетчер | Мастер |
| --- | --- | --- |
| Имя | Диспетчер Тест | Мастер Тест |
| Email | Email диспетчера | Другой email мастера |
| Роли | Agent + Dom-Servis Dispatcher | Agent + Dom-Servis Master |
| Активен | Да | Да |
| Группа Users | Полный доступ / Full | Полный доступ / Full |

Admin обычным сотрудникам не нужен. Customer не заменяет Agent.

Если форма позволяет задать пароль, задайте каждому свой временный пароль и попросите сменить его после входа. Письмо-приглашение без настроенного SMTP не придёт.

Если поля пароля нет, создайте запись, затем **на VPS** выполните:

~~~bash
read -r -p 'Email созданного сотрудника: ' STAFF_EMAIL
sudo docker compose exec -e STAFF_EMAIL="$STAFF_EMAIL" zammad-railsserver bundle exec rails runner 'require "io/console"; u = User.find_by(email: ENV.fetch("STAFF_EMAIL")); abort("Пользователь не найден") unless u; print "Новый пароль: "; a = STDIN.noecho(&:gets).to_s.chomp; puts; print "Повторите пароль: "; b = STDIN.noecho(&:gets).to_s.chomp; puts; abort("Пароли не совпадают или пустые") if a.empty? || a != b; u.update!(password: a); puts "Пароль сохранён"'
unset STAFF_EMAIL
~~~

Введите email, затем пароль дважды. Пароль вводится скрыто и не попадает в команду/историю shell. Повторите для второго сотрудника. Если пароль отклонён, выберите более длинный с разными типами символов.

Передайте сотруднику адрес и реквизиты лично. Для проверки откройте другой браузер или приватное окно и войдите под мастером — у разных пользователей должны быть разные сеансы.

<a id="notifications"></a>
## 10. Уведомления

### 10.1. Настройка сервера

~~~bash
sudo docker compose exec -T zammad-railsserver bundle exec rake dom_servis:webpush:status
~~~

Если оба VAPID-ключа показывают MISSING:

~~~bash
sudo docker compose exec -T zammad-railsserver bundle exec rake dom_servis:webpush:generate_keys
~~~

**Если уже configured, повторять генерацию нельзя как обычный шаг обновления:** смена ключей может потребовать повторного подключения устройств.

Укажите действующий контактный email:

~~~bash
read -r -p 'Контактный email администратора: ' PUSH_EMAIL
sudo docker compose exec -T -e PUSH_EMAIL="$PUSH_EMAIL" zammad-railsserver bundle exec rails runner 'Setting.set("dom_servis_webpush_subject", "mailto:" + ENV.fetch("PUSH_EMAIL")); puts "Контакт сохранён"'
unset PUSH_EMAIL
sudo docker compose restart zammad-railsserver zammad-scheduler zammad-websocket
sudo docker compose exec -T zammad-railsserver bundle exec rake dom_servis:webpush:status
~~~

Оба ключа должны быть configured. Active subscriptions: 0 пока нормально.

Если настроен лишь один ключ либо появляется Can't find config setting, проверьте шаг 7.3; не повторяйте генерацию по кругу.

### 10.2. Подключение телефона

**На телефоне мастера** откройте свой домен с путём /dispatch/:

~~~text
https://master.example.ru/dispatch/
~~~

Войдите под мастером.

**Android:**

1. Откройте в Chrome.
2. В меню — «Установить приложение» / «Добавить на главный экран».
3. Запустите через значок.
4. Нажмите включение уведомлений и разрешите их.

**iPhone/iPad:**

1. Нужна iOS/iPadOS 16.4 или новее.
2. Откройте адрес в Safari.
3. «Поделиться» → «На экран “Домой”».
4. Запустите через добавленный значок.
5. Включите уведомления и подтвердите разрешение.

Для этой схемы Web Push на iPhone важен запуск с главного экрана. [Поддержка WebKit](https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/).

После подключения нажмите **«Тест» / «Тест пуша»**. Проверьте системное уведомление; при необходимости сверните приложение и откройте центр уведомлений.

Каждое устройство подключается отдельно. Проверьте настройки уведомлений ОС и режим «Не беспокоить». Значок приложения не обеспечивает работу без интернета.

### 10.3. Какие события уведомляют

- Новая заявка в пуле — мастеров.
- Назначение — назначенного мастера.
- Возврат в пул — мастеров.
- Заявка остаётся в пуле после отложенной проверки — диспетчера и администратора.

По умолчанию проверка планируется через 120 минут после создания. Для первого теста ждать её не нужно: достаточно кнопки тестового push и новой заявки.

Почтовые уведомления — отдельная настройка с SMTP-реквизитами почтового провайдера. Web Push не включает отправку email.

<a id="first-job"></a>
## 11. Первая тестовая заявка

**Под диспетчером:**

1. Откройте /#dom_servis/dispatch.
2. Нажмите создание заявки.
3. Заполните услугу, клиента «Тестовая заявка», свой тестовый телефон, адрес, дату сегодня/завтра, будущее время визита и обычный приоритет.
4. В описании напишите «Проверка установки, выезд не требуется».
5. Если требуется организация, выберите «Частный заказ» либо созданную организацию.
6. Опубликуйте в пул и запишите номер.

**На телефоне под мастером:**

1. Проверьте уведомление.
2. Найдите заявку в пуле и нажмите «Взять».
3. Убедитесь, что она появилась среди ваших.
4. Переведите в работу, затем завершите.

**Под диспетчером:**

1. Проверьте исполнителя и конечный статус.
2. Изменения должны появляться без полной перезагрузки.
3. Проверьте действия в истории.
4. Найдите связанный тикет Zammad и сведения заявки. Поле/ссылка тикета может быть скрыто от мастера, поэтому проверяйте под диспетчером или администратором.

При ошибке группы проверьте Users → Full у оператора. При отсутствии ролей — шаг 7.3 и повторный вход.

<a id="backup"></a>
## 12. Резервная копия

zammad-backup сохраняет базу и файлы. Настройки выше задают 03:00 и хранение 7 дней. Фактическое создание проверяйте:

~~~bash
sudo docker compose logs --tail=50 zammad-backup
sudo docker compose exec -T zammad-backup ls -lh /var/tmp/zammad
~~~

Ожидаются свежие _zammad_db.psql.gz и _zammad_files.tar.gz, а в логах — backup finished.

Перед обновлением сделайте согласованную копию с краткой остановкой записи:

~~~bash
cd /srv/dom-servis
sudo docker compose stop caddy zammad-nginx zammad-railsserver zammad-scheduler zammad-websocket zammad-backup
sudo docker compose run --rm --no-deps zammad-backup bash -lc 'set -euo pipefail; stamp=$(date +%Y%m%d%H%M%S); export PGPASSWORD="$POSTGRESQL_PASS"; pg_dump -h "$POSTGRESQL_HOST" -p "$POSTGRESQL_PORT" -U "$POSTGRESQL_USER" "$POSTGRESQL_DB" | gzip > "/var/tmp/zammad/$stamp"_zammad_db.psql.gz; tar -czf "/var/tmp/zammad/$stamp"_zammad_files.tar.gz /opt/zammad/storage; echo "BACKUP_OK $stamp"'
~~~

Дождитесь BACKUP_OK. Предупреждение tar о ведущем / допустимо. При ошибке копирования обновление не начинайте.

Запустите текущую версию:

~~~bash
sudo docker compose up -d
~~~

Скопируйте архивы и настройки:

~~~bash
mkdir -p "$HOME/dom-servis-backup"
chmod 700 "$HOME/dom-servis-backup"
sudo docker compose cp zammad-backup:/var/tmp/zammad/. "$HOME/dom-servis-backup/"
cp .env docker-compose.yml docker-compose.override.yml Caddyfile "$HOME/dom-servis-backup/"
sudo chown -R "$USER":"$(id -gn)" "$HOME/dom-servis-backup"
chmod -R go-rwx "$HOME/dom-servis-backup"
~~~

**На компьютере**, в отдельном терминале, скачайте каталог, заменив пользователя и IP:

~~~bash
scp -r deploy@203.0.113.10:~/dom-servis-backup .
~~~

При нестандартном SSH-порте scp использует большую -P, например scp -P 2222 -r …

Каталог появится в текущей папке терминала компьютера. Храните его приватно: внутри данные клиентов и настройки доступа. Копия только на том же VPS не защищает от потери VPS.

Восстановление следует проверять на отдельной машине. После миграций возврат старого образа поверх новой базы может быть несовместим: нужны подходящие образ, база и файлы.

<a id="update"></a>
## 13. Обновление

1. Выберите новый тег на GitHub.
2. Проверьте описание выпуска на особые требования.
3. Сделайте и скачайте резервную копию по разделу 12.
4. На VPS:

~~~bash
cd /srv/dom-servis
cp .env .env.before-update
nano .env
~~~

Замените **только VERSION**. Пароль базы не меняйте. Сохраните.

~~~bash
sudo docker compose config --quiet
sudo docker compose config --images
sudo docker compose pull zammad-init zammad-railsserver zammad-scheduler zammad-websocket zammad-nginx zammad-backup
~~~

При ошибке скачивания новую версию пока не запускайте.

На время обновления остановите доступ и запись, затем выполните миграции нового образа:

~~~bash
sudo docker compose stop caddy zammad-nginx zammad-railsserver zammad-scheduler zammad-websocket zammad-backup
sudo docker compose run --rm --no-deps zammad-init
~~~

Дождитесь успешного завершения без ошибок. После этого:

~~~bash
sudo docker compose up -d
sudo docker compose ps -a
sudo docker compose logs --tail=100 zammad-init zammad-railsserver zammad-scheduler
~~~

Проверьте вход, доску, создание заявки и тестовый push.

Данные остаются в томах. **Не используйте docker compose down -v:** она удаляет тома с данными.

Для обычного обновления приложения git pull не требуется. Он нужен при изменении самого Compose-репозитория. Его изменения проверяют отдельно: там задаются в том числе версии PostgreSQL и Elasticsearch.

При ошибке миграции оставьте сервис закрытым и передайте ошибку разработчику. Возврат VERSION не отменяет изменений базы.

<a id="troubleshooting"></a>
## 14. Если что-то не работает

Команды выполнять из /srv/dom-servis.

| Симптом | Что проверить |
| --- | --- |
| docker: command not found | Подготовку VPS у специалиста |
| permission denied | Используется ли sudo |
| Неизвестный !override | Compose 2.24.4 или новее |
| manifest unknown / not found | Точный тег и IMAGE_REPO |
| denied / unauthorized | Публичность пакета и правильность имени образа |
| no matching manifest | Архитектуру x86_64 |
| port already allocated | Другой сервис на 80/443 |
| Сайт не найден | A-запись, IP, старую AAAA |
| Предупреждение сертификата | DNS, доступность 80/443, логи Caddy |
| 502 Bad Gateway | Завершение init, работу nginx и railsserver |
| zammad-init Exited (0) | Это штатный результат |
| Постоянный Restarting | Логи, RAM, свободный диск |
| Нет доски | Роли, активность, повторный вход |
| Ошибка группы при создании | Agent, роль Дом-Сервиса, Users → Full |
| Can't find config setting | Шаг 7.3 |
| Нет кнопки уведомлений | HTTPS, /dispatch/, ключи, браузер |
| Не приходит push | Разрешение ОС/браузера, подписку, scheduler |
| .env изменён, эффекта нет | Выполнен ли up -d: restart не перечитывает окружение |

~~~bash
sudo docker compose ps -a
sudo docker compose logs --tail=100 caddy
sudo docker compose logs --tail=100 zammad-init zammad-railsserver zammad-nginx
sudo docker compose logs --tail=100 zammad-scheduler zammad-websocket
sudo docker stats --no-stream
free -h
df -h /
~~~

Если настроенный сайт снова предлагает создать первого администратора, не проходите мастер заново. Проверьте каталог запуска, COMPOSE_PROJECT_NAME и тома: возможно, запущен другой пустой стек.

<a id="checklist"></a>
## 15. Проверка результата

- [ ] Домен указывает на VPS.
- [ ] HTTPS работает без предупреждений.
- [ ] init завершился с кодом 0, рабочие сервисы запущены.
- [ ] Создан администратор, сохранён пароль.
- [ ] Созданы диспетчер и мастер с ролями и доступом к группе.
- [ ] Диспетчер публикует заявку, мастер берёт и завершает.
- [ ] Тестовый push приходит на устройство.
- [ ] Копия базы и файлов скачана за пределы VPS.
- [ ] Известны текущий тег и каталог /srv/dom-servis.

Ежедневная работа — открыть домен и войти. SSH-окно держать открытым не нужно. Контейнеры запускаются после перезагрузки при включённой Docker-службе, если они не были остановлены вручную.

## Основания инструкции

Проверены конфигурация и исходники. Установка целиком на новой Ubuntu при подготовке документа не выполнялась.

- [Сборка образа](.github/workflows/docker-release.yaml).
- [Docker Compose](https://github.com/koronamedia/Svib-Home-Service-docker-compose/blob/master/docker-compose.yml).
- [Инициализация и запуск](bin/docker-entrypoint).
- [Роли](app/models/dom_servis/dispatch_role_catalog.rb).
- [Web Push](lib/tasks/dom_servis/webpush.rake).

