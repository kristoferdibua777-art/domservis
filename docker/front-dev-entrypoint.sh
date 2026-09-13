#!/usr/bin/env bash
set -euo pipefail

APP_ROOT=/opt/zammad
RAILS_PORT="${ZAMMAD_RAILS_PORT:-3000}"
WEBSOCKET_PORT="${ZAMMAD_WEBSOCKET_PORT:-6042}"
BUNDLE_STAMP=/usr/local/bundle/.dom-servis-gemfile.lock.sha256
PNPM_STAMP=node_modules/.dom-servis-pnpm.sha256

cd "$APP_ROOT"

find bin script -type f -exec sed -i 's/\r$//' {} +

if [[ ! -f config/database.yml ]]; then
  cp config/database/database.yml config/database.yml
fi

current_bundle_sum="$(sha256sum Gemfile.lock | awk '{print $1}')"
if [[ ! -f "$BUNDLE_STAMP" ]] || [[ "$(cat "$BUNDLE_STAMP")" != "$current_bundle_sum" ]] || ! bundle check >/dev/null 2>&1; then
  bundle install
  printf '%s' "$current_bundle_sum" > "$BUNDLE_STAMP"
fi

current_pnpm_sum="$(
  cat package.json pnpm-lock.yaml .eslint-plugin-zammad/package.json .eslint-plugin-zammad/pnpm-lock.yaml | sha256sum | awk '{print $1}'
)"
if [[ ! -d node_modules/.pnpm ]] || [[ ! -f "$PNPM_STAMP" ]] || [[ "$(cat "$PNPM_STAMP")" != "$current_pnpm_sum" ]]; then
  CI=true pnpm install --frozen-lockfile
  printf '%s' "$current_pnpm_sum" > "$PNPM_STAMP"
fi

rm -f tmp/pids/server.pid tmp/pids/websocket.pid

if [[ "${FRONT_DEV_DB_PREPARE:-0}" == "1" ]]; then
  bundle exec rails db:prepare
fi

pids=()

cleanup() {
  for pid in "${pids[@]:-}"; do
    if kill -0 "$pid" >/dev/null 2>&1; then
      kill "$pid" >/dev/null 2>&1 || true
    fi
  done
  wait || true
}

trap cleanup EXIT INT TERM

bundle exec rails server -b 0.0.0.0 -p "$RAILS_PORT" &
pids+=($!)

bundle exec script/background-worker.rb start &
pids+=($!)

WEBSOCKET_SERVER_LOG_TO_STDOUT=1 bundle exec script/websocket-server.rb start -b 0.0.0.0 -p "$WEBSOCKET_PORT" &
pids+=($!)

ZAMMAD_BIND_IP=127.0.0.1 VITE_RUBY_HOST=localhost bundle exec script/vite-server.rb dev &
pids+=($!)

while true; do
  for pid in "${pids[@]}"; do
    if ! kill -0 "$pid" >/dev/null 2>&1; then
      wait "$pid"
      exit $?
    fi
  done
  sleep 1
done
