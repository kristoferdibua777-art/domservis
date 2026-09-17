# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe DomServis::DispatchRoleCatalog do
  # Round 6a.1: db/seeds/roles.rb now successfully calls
  # DomServis::DispatchRoleCatalog.sync!(actor_id: 1) as part of the normal
  # seed pipeline (see the comment there). That seed pipeline runs once,
  # before the very first example of the whole suite - either via
  # `bundle exec rake zammad:db:init` as an explicit CI step (CI sets
  # CI_SKIP_DB_RESET=true precisely so RSpec's own `before(:suite)` hook,
  # below, does not redundantly repeat it), or, when that env var is unset
  # (e.g. local/non-CI runs), via that same `before(:suite)` hook calling
  # `zammad:db:reset` itself (see spec/support/db_initial_state.rb, and
  # zammad:db:reset's own `db:seed` step, in lib/tasks/zammad/db/reset.rake).
  # Either way, the three Dom-Servis overlay roles are already committed,
  # persistent rows by the time the first example starts.
  #
  # spec/support/db_transactional_fixtures.rb wraps every example in a
  # transaction that is rolled back afterwards (`use_transactional_fixtures
  # = true`) - but that only undoes changes made *inside* an example; it
  # rolls back to the suite's seeded baseline, not to an empty catalog. So
  # `DomServis::DispatchRoleCatalog.seeded?` is `true` before every example
  # in this file even starts, and examples here must not assume otherwise.
  #
  # Each example below therefore establishes its own explicit "catalog
  # absent" precondition by removing the three overlay Role rows first.
  # Destroying them inside a transactional example is safe and does not
  # corrupt shared baseline state for other examples/specs: the transaction
  # rollback after each example restores the seeded baseline exactly as
  # zammad:db:init/db:reset left it, the same way it undoes any other
  # in-example change.
  describe '.sync!' do
    it 'creates the three overlay roles with their matching permissions granted, and reports itself seeded', :aggregate_failures do
      Role.where(name: described_class.names).destroy_all
      expect(described_class.seeded?).to be(false)

      expect(described_class.sync!(actor_id: 1)).to be(true)

      expect(described_class.seeded?).to be(true)

      expect(Role.find_by(name: 'Dom-Servis Admin')&.with_permission?('dom_servis.admin')).to be(true)
      expect(Role.find_by(name: 'Dom-Servis Dispatcher')&.with_permission?('dom_servis.dispatcher')).to be(true)
      expect(Role.find_by(name: 'Dom-Servis Master')&.with_permission?('dom_servis.master')).to be(true)
    end

    it 'does nothing and returns false without an actor id, and does not raise', :aggregate_failures do
      Role.where(name: described_class.names).destroy_all
      expect(described_class.seeded?).to be(false)

      expect(described_class.sync!(actor_id: nil)).to be(false)

      expect(described_class.seeded?).to be(false)
    end
  end

  describe 'fresh-install seeding' do
    # db/migrate/20260318190000 and .../20260318211000 call .sync! with no
    # explicit actor_id, which only succeeds on an already-populated database
    # (see the .sync! comment above and db/seeds/roles.rb) - on a genuinely
    # fresh install, db/seeds/roles.rb is what actually seeds the catalog, by
    # calling .sync!(actor_id: 1) after db/seeds/user_nr_1.rb has created
    # user id 1.
    #
    # On a truly fresh install, roles_id_seq has never been advanced past its
    # initial state when this runs (the stock Admin/Agent/Customer roles just
    # above are created with explicit ids, which does not consume the
    # sequence - see the comment in db/seeds/roles.rb), so the next
    # nextval('roles_id_seq') call returns 1, colliding with the already
    # -existing Role id=1 ('Admin').
    #
    # As explained above the describe block, this suite's own baseline
    # already has the three overlay roles seeded and its roles_id_seq
    # already far advanced by the time any example runs - so merely
    # `load`-ing db/seeds/roles.rb here, without first removing those rows,
    # would not exercise the bug at all: DomServis::DispatchRoleCatalog.sync!
    # uses Role.find_or_initialize_by(name:), so if a row with that name
    # already exists it is simply found and updated, never re-inserted, and
    # roles_id_seq's nextval() default is never even called. To actually
    # reproduce the collision, this example removes the three overlay rows
    # first (see the describe block comment - safe under transactional
    # fixtures) so .sync! is forced down its Role.new/INSERT path, and then
    # rewinds roles_id_seq to the untouched-fresh-install state. PostgreSQL
    # sequences are not transactional, so this example's rollback would not
    # undo that `setval` on its own - the `ensure` block always realigns it
    # back to MAX(id) afterwards, pass or fail, so no stale sequence state
    # leaks into whichever spec runs next.
    it 'does not collide with the already-existing explicit-id Admin role when roles_id_seq has not been advanced', :aggregate_failures do
      Role.where(name: described_class.names).destroy_all
      expect(Role.exists?(id: 1)).to be(true) # the seeded 'Admin' role
      expect(described_class.seeded?).to be(false)

      ActiveRecord::Base.connection.execute("SELECT setval('roles_id_seq', 1, false)")

      expect { load Rails.root.join('db/seeds/roles.rb') }.not_to raise_error

      expect(described_class.seeded?).to be(true)
    ensure
      ActiveRecord::Base.connection.reset_pk_sequence!('roles')
    end
  end

  # Permission rows referenced by an overlay Role are removed via the Role
  # first - `destroy_all` on the HABTM association cleans up its own
  # permissions_roles join rows - before removing the Permission rows
  # themselves by name, rather than a broader delete.
  describe '.ensure_permissions!' do
    it 'creates the three DomServis permissions with the same attributes as the migration, when absent', :aggregate_failures do
      Role.where(name: described_class.names).destroy_all
      Permission.where(name: described_class::PERMISSION_DEFINITIONS.keys).destroy_all
      expect(Permission.where(name: described_class::PERMISSION_DEFINITIONS.keys).count).to eq(0)

      expect(described_class.ensure_permissions!).to be(true)

      expect(Permission.find_by(name: 'dom_servis.admin')).to have_attributes(
        label:        'Dom-Servis Admin',
        description:  'Access the Dom-Servis administrative workspace and dispatch policy controls.',
        allow_signup: false,
        active:       true,
        preferences:  include(prio: 3490, translations: ['Dom-Servis Admin']),
      )
      expect(Permission.find_by(name: 'dom_servis.dispatcher')).to have_attributes(
        label:        'Dom-Servis Dispatcher',
        description:  'Access the Dom-Servis dispatcher workspace.',
        allow_signup: false,
        active:       true,
        preferences:  include(prio: 3500),
      )
      expect(Permission.find_by(name: 'dom_servis.master')).to have_attributes(
        label:        'Dom-Servis Master',
        description:  'Access the Dom-Servis master workspace.',
        allow_signup: false,
        active:       true,
        preferences:  include(prio: 3510),
      )
    end

    it 'is idempotent - calling it again when the permissions already exist does not raise or duplicate rows', :aggregate_failures do
      Role.where(name: described_class.names).destroy_all
      Permission.where(name: described_class::PERMISSION_DEFINITIONS.keys).destroy_all

      expect(described_class.ensure_permissions!).to be(true)
      first_run_ids = Permission.where(name: described_class::PERMISSION_DEFINITIONS.keys).reorder(:name).pluck(:id)

      expect { described_class.ensure_permissions! }.not_to raise_error

      expect(Permission.where(name: described_class::PERMISSION_DEFINITIONS.keys).reorder(:name).pluck(:id)).to eq(first_run_ids)
    end
  end

  describe '.bootstrap!' do
    it 'ensures the three DomServis permissions exist, then creates the three overlay roles with each granted its matching permission', :aggregate_failures do
      Role.where(name: described_class.names).destroy_all
      Permission.where(name: described_class::PERMISSION_DEFINITIONS.keys).destroy_all
      expect(described_class.seeded?).to be(false)

      expect(described_class.bootstrap!(actor_id: 1)).to be(true)

      expect(described_class.seeded?).to be(true)
      expect(Permission.where(name: described_class::PERMISSION_DEFINITIONS.keys).count).to eq(3)

      expect(Role.find_by(name: 'Dom-Servis Admin')&.with_permission?('dom_servis.admin')).to be(true)
      expect(Role.find_by(name: 'Dom-Servis Dispatcher')&.with_permission?('dom_servis.dispatcher')).to be(true)
      expect(Role.find_by(name: 'Dom-Servis Master')&.with_permission?('dom_servis.master')).to be(true)

      # bootstrap! must not also grant a DomServis permission to the stock
      # Admin/Agent/Customer roles.
      expect(Role.find_by(name: 'Admin').with_permission?('dom_servis.admin')).to be(false)
      expect(Role.find_by(name: 'Agent').with_permission?('dom_servis.dispatcher')).to be(false)
      expect(Role.find_by(name: 'Agent').with_permission?('dom_servis.master')).to be(false)
      expect(Role.find_by(name: 'Customer').with_permission?('dom_servis.admin')).to be(false)
    end

    it 'is idempotent - running it twice in sequence does not raise, and leaves one row per permission/role', :aggregate_failures do
      Role.where(name: described_class.names).destroy_all
      Permission.where(name: described_class::PERMISSION_DEFINITIONS.keys).destroy_all

      expect(described_class.bootstrap!(actor_id: 1)).to be(true)

      expect { described_class.bootstrap!(actor_id: 1) }.not_to raise_error

      expect(Permission.where(name: described_class::PERMISSION_DEFINITIONS.keys).count).to eq(3)
      expect(Role.where(name: described_class.names).count).to eq(3)
    end
  end
end
