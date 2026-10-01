# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# ObjectManager metadata of the Dom-Servis columns on tickets (the backing
# ticket projection, see Mapper::CUSTOM_FIELDS). The columns are added by
# db/migrate/20260322010000_add_dom_servis_backing_ticket_fields.rb, which
# skips the attribute records on a fresh install (no system_init_done yet);
# the seeds and db/migrate/20261001150000_ensure_dom_servis_backing_ticket_field_attributes.rb
# create them from these definitions.
class DomServis::Dispatch::BackingTicket::Fields
  DEFINITIONS = [
    { name: 'dom_servis_job_code', display: __('Dom-Servis Job Code'), data_type: 'input', position: 1900, options: { type: 'text', maxlength: 120, null: true, translate: false } },
    { name: 'dom_servis_visit_day', display: __('Dom-Servis Visit Day'), data_type: 'input', position: 1910, options: { type: 'text', maxlength: 32, null: true, translate: false } },
    { name: 'dom_servis_visit_date', display: __('Dom-Servis Visit Date'), data_type: 'input', position: 1920, options: { type: 'text', maxlength: 64, null: true, translate: false } },
    { name: 'dom_servis_visit_time', display: __('Dom-Servis Visit Time'), data_type: 'input', position: 1930, options: { type: 'text', maxlength: 64, null: true, translate: false } },
    { name: 'dom_servis_service_type', display: __('Dom-Servis Service Type'), data_type: 'input', position: 1940, options: { type: 'text', maxlength: 200, null: true, translate: false } },
    { name: 'dom_servis_client_name', display: __('Dom-Servis Client Name'), data_type: 'input', position: 1950, options: { type: 'text', maxlength: 200, null: true, translate: false } },
    { name: 'dom_servis_client_phone', display: __('Dom-Servis Client Phone'), data_type: 'input', position: 1960, options: { type: 'text', maxlength: 120, null: true, translate: false } },
    { name: 'dom_servis_dispatch_status', display: __('Dom-Servis Dispatch Status'), data_type: 'input', position: 1970, options: { type: 'text', maxlength: 64, null: true, translate: false } },
    { name: 'dom_servis_dispatch_priority', display: __('Dom-Servis Dispatch Priority'), data_type: 'input', position: 1980, options: { type: 'text', maxlength: 64, null: true, translate: false } },
    { name: 'dom_servis_dispatch_source', display: __('Dom-Servis Dispatch Source'), data_type: 'input', position: 1990, options: { type: 'text', maxlength: 64, null: true, translate: false } },
    { name: 'dom_servis_address', display: __('Dom-Servis Address'), data_type: 'textarea', position: 2000, options: { default: '', rows: 3, maxlength: 2000, null: true, translate: false } },
    { name: 'dom_servis_work_tags', display: __('Dom-Servis Work Tags'), data_type: 'textarea', position: 2010, options: { default: '', rows: 2, maxlength: 1000, null: true, translate: false } },
    { name: 'dom_servis_description', display: __('Dom-Servis Description'), data_type: 'textarea', position: 2020, options: { default: '', rows: 6, maxlength: 8000, null: true, translate: false } },
    { name: 'dom_servis_comment', display: __('Dom-Servis Comment'), data_type: 'textarea', position: 2030, options: { default: '', rows: 4, maxlength: 4000, null: true, translate: false } },
    { name: 'dom_servis_assignee_name', display: __('Dom-Servis Assignee'), data_type: 'input', position: 2040, options: { type: 'text', maxlength: 200, null: true, translate: false } },
  ].freeze

  # Creates the missing attribute records; existing ones stay as they are.
  def self.ensure_object_manager_attributes!
    UserInfo.with_user_id(1) do
      DEFINITIONS.each do |field|
        next if ObjectManager::Attribute.get(object: 'Ticket', name: field[:name]).present?

        ObjectManager::Attribute.add(
          force:         true,
          object:        'Ticket',
          name:          field[:name],
          display:       field[:display],
          data_type:     field[:data_type],
          data_option:   field[:options],
          editable:      false,
          active:        true,
          screens:       {
            create_middle: {},
            edit:          {},
            view:          {},
          },
          to_create:     false,
          to_migrate:    false,
          to_delete:     false,
          position:      field[:position],
          created_by_id: 1,
          updated_by_id: 1,
        )
      end
    end
  end
end
