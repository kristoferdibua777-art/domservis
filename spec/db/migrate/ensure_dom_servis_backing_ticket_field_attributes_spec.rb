# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe EnsureDomServisBackingTicketFieldAttributes, type: :db_migration do
  let(:names) { DomServis::Dispatch::BackingTicket::Fields::DEFINITIONS.pluck(:name) }

  def attribute_count
    ObjectManager::Attribute.where(object_lookup_id: ObjectLookup.by_name('Ticket'), name: names).count
  end

  before do
    ObjectManager::Attribute.where(object_lookup_id: ObjectLookup.by_name('Ticket'), name: names).destroy_all
  end

  it 'adds the missing attributes on a set-up system' do
    expect { migrate }.to change { attribute_count }.from(0).to(names.size)
  end

  context 'when the system is not set up yet', system_init_done: false do
    it 'leaves the attributes to the seeds' do
      expect { migrate }.not_to change { attribute_count }.from(0)
    end
  end
end
