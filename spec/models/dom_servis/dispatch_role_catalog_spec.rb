# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe DomServis::DispatchRoleCatalog do
  describe '.sync!' do
    it 'creates the three overlay roles with their matching permissions granted, and reports itself seeded' do
      expect(described_class.seeded?).to be(false)

      expect(described_class.sync!(actor_id: 1)).to be(true)

      expect(described_class.seeded?).to be(true)

      expect(Role.find_by(name: 'Dom-Servis Admin')&.with_permission?('dom_servis.admin')).to be(true)
      expect(Role.find_by(name: 'Dom-Servis Dispatcher')&.with_permission?('dom_servis.dispatcher')).to be(true)
      expect(Role.find_by(name: 'Dom-Servis Master')&.with_permission?('dom_servis.master')).to be(true)
    end

    it 'does nothing and returns false without an actor id, and does not raise' do
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
    # user id 1. This proves that path works the way db/seeds.rb runs it.
    it 'seeds the catalog when db/seeds/roles.rb runs' do
      expect(described_class.seeded?).to be(false)

      load Rails.root.join('db/seeds/roles.rb')

      expect(described_class.seeded?).to be(true)
    end
  end
end
