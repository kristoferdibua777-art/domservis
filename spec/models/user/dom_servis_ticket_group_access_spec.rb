# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

RSpec.describe User do
  describe 'Dom-Servis ticket group access' do
    it 'does not grant the standard Users ticket group to ordinary internal users automatically' do
      users_group = Group.find_by(name: 'Users')

      admin = create(:admin)

      expect(users_group).to be_present
      expect(admin.group_ids_access('create')).not_to include(users_group.id)
      expect(admin.saved_group_ids_access_map).not_to have_key(users_group.id)
    end
  end
end
