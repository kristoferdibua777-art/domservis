# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe DomServis::DispatchPolicy, type: :model do
  # Zammad's built-in 'Admin' role does not by itself carry
  # 'dom_servis.admin' - db/migrate/20260318214000_create_dom_servis_admin_permission.rb
  # grants that permission only to the dedicated 'Dom-Servis Admin' overlay
  # role, by design (DomServis admin access is opt-in, the same way
  # `master_user` below explicitly opts into 'Dom-Servis Master'). Without
  # assigning the overlay role here, DomServis::DispatchPolicy.role_key_for
  # falls through to its 'master' default for this user, and the
  # action_allowed?/status_allowed? expectations below - which assume the
  # 'admin' role matrix - would not match the role actually resolved.
  let(:admin) do
    create(:admin).tap do |user|
      admin_role = Role.find_by(name: 'Dom-Servis Admin')
      user.roles << admin_role if admin_role && !user.roles.exists?(admin_role.id)
    end
  end
  let(:master_user) do
    create(:agent).tap do |user|
      master_role = Role.find_by(name: 'Dom-Servis Master')
      user.roles << master_role if master_role && !user.roles.exists?(master_role.id)
    end
  end

  before do
    DomServis::DispatchRoleCatalog.sync!(actor_id: 1)
  end

  it 'keeps the deadline warning setting in the default policy' do
    policy = described_class.current

    expect(policy['settings']['deadline_warning_minutes']).to eq(120)
    expect(policy['statuses']['transferred_to_partner']['admin']).to be(true)
    expect(policy['actions']['change_assignee']['admin']).to be(true)
  end

  it 'keeps assignee editing disabled while exposing the operational assign action' do
    expect(described_class.editable_field?(admin, 'assignee_id')).to be(false)
    expect(described_class.action_allowed?(admin, 'change_assignee')).to be(true)
    expect(described_class.status_allowed?(admin, 'transferred_to_partner')).to be(true)
  end

  it 'keeps the master role away from manual assignee editing and partner transfer' do
    expect(described_class.editable_field?(master_user, 'assignee_id')).to be(false)
    expect(described_class.action_allowed?(master_user, 'change_assignee')).to be(false)
    expect(described_class.status_allowed?(master_user, 'transferred_to_partner')).to be(false)
  end
end
