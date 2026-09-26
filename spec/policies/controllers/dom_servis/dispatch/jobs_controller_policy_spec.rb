# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

describe Controllers::DomServis::Dispatch::JobsControllerPolicy do
  subject { described_class.new(user, record) }

  let(:record) { DomServis::Dispatch::JobsController.new }

  before do
    DomServis::DispatchRoleCatalog.sync!(actor_id: 1)
  end

  def user_with_overlay_role(factory, role_name)
    create(factory).tap do |user|
      user.roles << Role.find_by!(name: role_name)
    end
  end

  context 'with a Dom-Servis dispatcher' do
    let(:user) { user_with_overlay_role(:agent, 'Dom-Servis Dispatcher') }

    it { is_expected.to permit_actions(:assign, :move_day, :change_priority) }
  end

  context 'with a Dom-Servis admin' do
    let(:user) { user_with_overlay_role(:admin, 'Dom-Servis Admin') }

    it { is_expected.to permit_actions(:assign, :move_day, :change_priority) }
  end

  context 'with a Dom-Servis master' do
    let(:user) { user_with_overlay_role(:agent, 'Dom-Servis Master') }

    it { is_expected.to forbid_actions(:assign, :move_day, :change_priority) }
    it { is_expected.to permit_actions(:take, :release, :update_status) }
  end

  context 'with a standard Zammad agent' do
    let(:user) { create(:agent) }

    it { is_expected.to forbid_actions(:assign, :move_day, :change_priority) }
  end

  context 'with a standard Zammad admin' do
    let(:user) { create(:admin) }

    it { is_expected.to forbid_actions(:assign, :move_day, :change_priority) }
  end
end
