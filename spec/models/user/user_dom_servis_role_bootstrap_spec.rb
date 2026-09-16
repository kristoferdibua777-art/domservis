# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

RSpec.describe User do
  describe 'Dom-Servis role bootstrap' do
    # Round 6a: creating a core Zammad Admin/Agent user used to silently
    # trigger User#bootstrap_dom_servis_roles (an after_commit callback),
    # which auto-granted the 'Dom-Servis Admin' overlay role to whichever
    # admin-permission user happened to be created first after the
    # Dom-Servis role catalog was reset (e.g. by RSpec's transactional
    # fixtures rolling back a previous example's catalog sync). That
    # callback has been removed - see spec/models/dom_servis/dispatch_policy_spec.rb
    # and spec/requests/dom_servis/dispatch/jobs_controller_spec.rb for the
    # documented, by-design explicit-assignment pattern this restores.
    it 'does not add the Dom-Servis Admin overlay role to an ordinary Admin user' do
      admin = create(:admin)

      expect(admin.role?('Dom-Servis Admin')).to be(false)
    end

    it 'does not add the Dom-Servis Admin overlay role to an ordinary Agent user' do
      agent = create(:agent)

      expect(agent.role?('Dom-Servis Admin')).to be(false)
    end

    it 'still allows the overlay role to be explicitly assigned' do
      DomServis::DispatchRoleCatalog.sync!(actor_id: 1)

      admin = create(:admin)
      admin.roles << Role.find_by(name: 'Dom-Servis Admin')

      expect(admin.role?('Dom-Servis Admin')).to be(true)
    end
  end
end
