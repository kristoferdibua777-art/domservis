# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

Role.create_if_not_exists(
  id:                1,
  name:              __('Admin'),
  note:              __('To configure your system.'),
  preferences:       {},
  default_at_signup: false,
  updated_by_id:     1,
  created_by_id:     1
)
Role.create_if_not_exists(
  id:                2,
  name:              __('Agent'),
  note:              __('To work on Tickets.'),
  default_at_signup: false,
  preferences:       {},
  updated_by_id:     1,
  created_by_id:     1
)
Role.create_if_not_exists(
  id:                3,
  name:              __('Customer'),
  note:              __('People who create Tickets ask for help.'),
  preferences:       {},
  default_at_signup: true,
  updated_by_id:     1,
  created_by_id:     1
)

# Ensures the Dom-Servis overlay role catalog ('Dom-Servis Admin' /
# 'Dispatcher' / 'Master', see DomServis::DispatchRoleCatalog) exists on a
# fresh install. db/migrate/20260318190000_create_dom_servis_dispatch_roles.rb
# and db/migrate/20260318211000_add_dom_servis_admin_role.rb also call
# DomServis::DispatchRoleCatalog.sync!, but with no explicit actor_id - on an
# already-running installation being upgraded, that resolves to an existing
# user and succeeds; on a genuinely fresh database (nothing in db/migrate/
# ever creates a User row), it resolves to nil and sync! is a deliberate
# no-op (see DomServis::DispatchRoleCatalog#sync!). This is the fresh-install
# path: by the time this file runs, db/seeds/user_nr_1.rb has already created
# user id 1, so actor_id: 1 here is always valid. Previously
# User#bootstrap_dom_servis_roles (a User after_commit callback, removed) was
# what made this eventually self-heal on the first admin-permission user
# created after install; that callback also incorrectly auto-granted the
# overlay role to that user, which is why it was removed rather than kept -
# see spec/models/user/dom_servis_role_bootstrap_spec.rb.
DomServis::DispatchRoleCatalog.sync!(actor_id: 1)
