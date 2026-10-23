# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe CreateDomServisWorkTags, type: :db_migration do
  it 'creates the dictionary tags once', :aggregate_failures do
    Tag::Item.lookup_by_name_and_create('Газовый котёл')

    expect { migrate }.to change(Tag::Item, :count).by(DomServis::WorkTagCatalog.names.size - 1)
    expect(Tag::Item.pluck(:name)).to include('Газовый котёл', 'Не греет', 'Baxi', 'Ждёт запчасть')
    expect { migrate }.not_to change(Tag::Item, :count)
  end
end
