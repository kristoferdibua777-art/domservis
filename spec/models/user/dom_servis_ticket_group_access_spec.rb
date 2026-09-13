# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

RSpec.describe User do
  describe 'Dom-Servis ticket group access' do
    it 'assigns the standard Users ticket group to newly created internal users without group access' do
      users_group = Group.find_by(name: 'Users')

      admin = create(:admin)

      expect(users_group).to be_present
      expect(admin.group_ids_access('create')).to include(users_group.id)
      expect(admin.saved_group_ids_access_map[users_group.id]).to eq(['full'])
    end
  end
end
