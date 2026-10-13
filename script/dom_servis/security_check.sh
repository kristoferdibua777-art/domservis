#!/usr/bin/env bash
# Дом-Сервис: проверка защиты персональных данных на рабочем VPS.
# Только читает и ничего не меняет. Запуск из каталога установки:
#   cd /srv/dom-servis && sudo bash security_check.sh
# Результат: строки OK / ВНИМАНИЕ / ПРОБЛЕМА и итог в процентах.

set -uo pipefail

ok=0; total=0
pass() { ok=$((ok + 1)); total=$((total + 1)); echo "OK        $*"; }
warn() { total=$((total + 1)); echo "ВНИМАНИЕ  $*"; }
fail() { total=$((total + 1)); echo "ПРОБЛЕМА  $*"; }

if [[ ! -f docker-compose.yml ]]; then
  echo "Запустите из каталога установки (обычно /srv/dom-servis)."; exit 1
fi
dc() { docker compose "$@"; }

echo "== 1. Открытые наружу порты"
public=$(ss -ltnH | awk '{print $4}' | grep -vE '^(127\.|\[::1\]|::1)' | sed -E 's/.*:([0-9]+)$/\1/' | sort -un | tr '\n' ' ')
echo "          слушают на внешних адресах: ${public:-нет}"
for p in 5432 9200 9300 6379 11211 3000 8080 6042; do
  if grep -qw "$p" <<<"$public"; then fail "порт $p открыт наружу (база/поиск/кэш/приложение должны быть только внутри Docker)"; else pass "порт $p закрыт снаружи"; fi
done
grep -qw 443 <<<"$public" && pass "HTTPS (443) работает" || fail "443 не слушается — нет HTTPS"

echo "== 2. Межсетевой экран"
if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
  pass "ufw включён"
  echo "          помните: порты, опубликованные Docker, ufw не закрывает — важен пункт 1"
else
  warn "ufw не включён (разрешите только 22, 80, 443)"
fi

echo "== 3. SSH"
sshd_cfg=$(sshd -T 2>/dev/null)
grep -q "^passwordauthentication no" <<<"$sshd_cfg" && pass "вход по паролю SSH выключен" || warn "SSH разрешает вход по паролю — лучше только по ключу"
grep -q "^permitrootlogin no" <<<"$sshd_cfg" && pass "вход root по SSH запрещён" || warn "вход root по SSH разрешён"
systemctl is-active --quiet fail2ban && pass "fail2ban работает" || warn "fail2ban не установлен/не запущен"

echo "== 4. Права на секреты"
perm=$(stat -c %a .env 2>/dev/null || echo "нет")
[[ "$perm" == "600" ]] && pass ".env доступен только владельцу" || warn ".env права $perm — выполните: chmod 600 .env"

echo "== 5. Настройки Zammad"
report=$(dc exec -T zammad-railsserver bundle exec rails runner '
  puts "VERSION=#{Version.get}"
  puts "ENFORCE=#{Array(Setting.get("two_factor_authentication_enforce_role_ids")).compact_blank.size}"
  puts "APP2FA=#{Setting.get("two_factor_authentication_method_authenticator_app")}"
  puts "SIGNUP=#{Setting.get("user_create_account")}"
  puts "PWMIN=#{Setting.get("password_min_size")}"
  puts "ADMINS=#{User.with_permissions("admin").where(active: true).count}"
  puts "NO2FA=#{User.with_permissions("ticket.agent").where(active: true).count { |u| !u.two_factor_configured? }}"
' 2>/dev/null)
get() { sed -n "s/^$1=//p" <<<"$report"; }
if [[ -z "$report" ]]; then
  warn "не удалось прочитать настройки (контейнер zammad-railsserver не запущен?)"
else
  echo "          версия: $(get VERSION)"
  [[ "$(get APP2FA)" == "true" ]] && pass "2FA через приложение включена" || fail "2FA выключена: Настройки → Безопасность → Двухфакторная аутентификация"
  [[ "$(get ENFORCE)" -gt 0 ]] && pass "2FA обязательна для ролей" || fail "2FA не обязательна — назначьте её ролям сотрудников"
  [[ "$(get NO2FA)" == "0" ]] && pass "у всех сотрудников настроен 2FA" || warn "сотрудников без 2FA: $(get NO2FA)"
  [[ "$(get SIGNUP)" == "false" ]] && pass "самостоятельная регистрация закрыта" || warn "любой может зарегистрироваться — выключите «Создание учётной записи»"
  [[ "$(get PWMIN)" -ge 10 ]] && pass "минимальная длина пароля $(get PWMIN)" || warn "минимальная длина пароля $(get PWMIN) — поставьте 10+"
  echo "          активных администраторов: $(get ADMINS) (чем меньше, тем лучше)"
fi

echo "== 6. Резервные копии"
latest=$(dc exec -T zammad-backup sh -c 'ls -t /var/tmp/zammad/*_zammad_db.psql.gz 2>/dev/null | head -1' 2>/dev/null | tr -d '\r')
if [[ -n "$latest" ]]; then
  age=$(dc exec -T zammad-backup sh -c "echo \$(( (\$(date +%s) - \$(stat -c %Y '$latest')) / 3600 ))" 2>/dev/null | tr -d '\r')
  [[ "${age:-999}" -le 30 ]] && pass "свежая копия базы ($age ч назад)" || fail "последняя копия базы $age ч назад"
  warn "копии лежат на том же сервере — раз в неделю забирайте их (install.md, раздел «Резервная копия»)"
else
  fail "копий базы не найдено"
fi

echo "== 7. Обновления системы"
if command -v apt-get >/dev/null; then
  n=$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst .*security' || true)
  [[ "$n" -eq 0 ]] && pass "нет ожидающих обновлений безопасности ОС" || warn "ожидают обновлений безопасности: $n (sudo apt upgrade)"
fi

echo
pct=$(( total > 0 ? ok * 100 / total : 0 ))
echo "ИТОГ: выполнено $ok из $total проверок — ${pct}% к цели."
