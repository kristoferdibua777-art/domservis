#!/usr/bin/env bash

set -o errexit
set -o pipefail

# shellcheck disable=SC1091
source /etc/profile.d/rvm.sh
# shellcheck disable=SC1091
source .gitlab/environment.env

echo "Checking assets generation…"
bundle exec rake assets:precompile

echo "Running front end tests…"
# TEMPORARY: DOMSERVIS_DIAGNOSTIC_TICKET_CREATE_USER=1 enables the narrowly-
# gated logging already used by test-diagnostic.yml's Stage 2/6 (see
# tests/support/diagnostic-ticket-create-user.ts) to observe the exact
# FormUpdater request sequence around the two intermittent full-suite-only
# timeouts in ticket-create-user.spec.ts. The plain "CI" workflow run here
# is what actually reproduces the hang consistently (the temporary
# diagnostic workflow does not), so this run's log is the one that needs
# the detailed sequence. Remove once the root cause is found and fixed.
DOMSERVIS_DIAGNOSTIC_TICKET_CREATE_USER=1 pnpm test

echo "Running basic rspec tests…"
bundle exec rake zammad:db:init
bundle exec rspec --exclude-pattern "spec/system/**/*_spec.rb" -t ~searchindex -t ~integration -t ~required_envs

echo "Running basic minitest tests…"
bundle exec rake zammad:db:reset
bundle exec rake test:units
