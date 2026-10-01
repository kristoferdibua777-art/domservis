# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe DomServis::Dispatch::BackingTicket::Fields do
  let(:names) { described_class::DEFINITIONS.pluck(:name) }

  def attribute(name)
    ObjectManager::Attribute.get(object: 'Ticket', name: name)
  end

  it 'covers every field the backing ticket mapper writes' do
    expect(names.map(&:to_sym)).to match_array(DomServis::Dispatch::BackingTicket::Mapper::CUSTOM_FIELDS)
  end

  it 'has the attributes on a fresh install (created by the seeds)' do
    expect(names.map { |name| attribute(name) }).to all(be_present)
  end

  it 'creates a missing attribute and keeps the existing ones', :aggregate_failures do
    attribute('dom_servis_comment').destroy!
    attribute('dom_servis_job_code').update!(position: 1901)

    described_class.ensure_object_manager_attributes!

    expect(attribute('dom_servis_comment')).to have_attributes(data_type: 'textarea', editable: false, active: true)
    expect(attribute('dom_servis_job_code').position).to eq(1901)
  end
end
