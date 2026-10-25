# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe 'DomServis::Dispatch::TagsController', authenticated_as: :dispatcher_user, type: :request do
  let(:dispatcher_user) do
    create(:agent).tap do |user|
      user.roles << Role.find_by!(name: 'Dom-Servis Dispatcher')
    end
  end

  before do
    DomServis::DispatchRoleCatalog.sync!(actor_id: 1)
    Tag::Item.lookup_by_name_and_create('Своя метка')
  end

  it 'lists the dictionary tags with their groups, then the other Zammad tags', :aggregate_failures do
    get '/api/v1/dom_servis/dispatch/tags', as: :json

    expect(response).to have_http_status(:ok)
    expect(json_response['groups'].pluck('key')).to eq(%w[direction work fault equipment brand area mark other])
    expect(json_response['tags'].first).to include('name' => 'Газовый котёл', 'group' => 'direction', 'dispatch_count' => 0)
    expect(json_response['tags'].find { |tag| tag['name'] == 'Baxi' }).to include('group' => 'brand')
    expect(json_response['tags'].find { |tag| tag['name'] == 'Своя метка' }).to include('group' => 'other')
    expect(json_response['tags'].pluck('name').index('Своя метка')).to be > json_response['tags'].pluck('name').index('Ждёт запчасть')
  end
end
