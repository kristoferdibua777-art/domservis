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

# The three roles above are created with explicit primary-key ids (1/2/3),
# which does NOT advance PostgreSQL's roles_id_seq - the column's backing
# sequence only auto-increments when an INSERT lets its `id` DEFAULT
# nextval(...) fire, and an explicit `id:` bypasses that entirely. On a fresh
# install this leaves the sequence at its untouched initial state, where the
# next nextval() call returns 1. db/seeds.rb only re-synchronizes every
# table's sequence once, via DbHelper.import_post, at the very end of the
# whole seed pipeline (after every file in its `seeds` array - including this
# one - has already run), so that hasn't happened yet at this point. Without
# resetting roles_id_seq here first, DomServis::DispatchRoleCatalog.sync!
# below - which creates its three roles with no explicit id, relying on that
# same nextval() default - would collide with the already-existing Role id=1
# (Admin) and raise ActiveRecord::RecordNotUnique / PG::UniqueViolation.
# ActiveRecord::Base.connection.reset_pk_sequence! is the repository's and
# Rails' own standard mechanism for this (see DbHelper.import_post above);
# calling it again here, and once more later via DbHelper.import_post, is
# harmless - it is idempotent, simply realigning the sequence to MAX(id).
ActiveRecord::Base.connection.reset_pk_sequence!('roles')

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
