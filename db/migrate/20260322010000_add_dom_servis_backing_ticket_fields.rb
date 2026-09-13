# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class AddDomServisBackingTicketFields < ActiveRecord::Migration[7.2]
  FIELD_DEFINITIONS = [
    {
      name:      'dom_servis_job_code',
      display:   'Dom-Servis Job Code',
      data_type: 'input',
      column:    :string,
      options:   { type: 'text', maxlength: 120, null: true, translate: false },
      position:  1900,
    },
    {
      name:      'dom_servis_visit_day',
      display:   'Dom-Servis Visit Day',
      data_type: 'input',
      column:    :string,
      options:   { type: 'text', maxlength: 32, null: true, translate: false },
      position:  1910,
    },
    {
      name:      'dom_servis_visit_date',
      display:   'Dom-Servis Visit Date',
      data_type: 'input',
      column:    :string,
      options:   { type: 'text', maxlength: 64, null: true, translate: false },
      position:  1920,
    },
    {
      name:      'dom_servis_visit_time',
      display:   'Dom-Servis Visit Time',
      data_type: 'input',
      column:    :string,
      options:   { type: 'text', maxlength: 64, null: true, translate: false },
      position:  1930,
    },
    {
      name:      'dom_servis_service_type',
      display:   'Dom-Servis Service Type',
      data_type: 'input',
      column:    :string,
      options:   { type: 'text', maxlength: 200, null: true, translate: false },
      position:  1940,
    },
    {
      name:      'dom_servis_client_name',
      display:   'Dom-Servis Client Name',
      data_type: 'input',
      column:    :string,
      options:   { type: 'text', maxlength: 200, null: true, translate: false },
      position:  1950,
    },
    {
      name:      'dom_servis_client_phone',
      display:   'Dom-Servis Client Phone',
      data_type: 'input',
      column:    :string,
      options:   { type: 'text', maxlength: 120, null: true, translate: false },
      position:  1960,
    },
    {
      name:      'dom_servis_dispatch_status',
      display:   'Dom-Servis Dispatch Status',
      data_type: 'input',
      column:    :string,
      options:   { type: 'text', maxlength: 64, null: true, translate: false },
      position:  1970,
    },
    {
      name:      'dom_servis_dispatch_priority',
      display:   'Dom-Servis Dispatch Priority',
      data_type: 'input',
      column:    :string,
      options:   { type: 'text', maxlength: 64, null: true, translate: false },
      position:  1980,
    },
    {
      name:      'dom_servis_dispatch_source',
      display:   'Dom-Servis Dispatch Source',
      data_type: 'input',
      column:    :string,
      options:   { type: 'text', maxlength: 64, null: true, translate: false },
      position:  1990,
    },
    {
      name:      'dom_servis_address',
      display:   'Dom-Servis Address',
      data_type: 'textarea',
      column:    :text,
      options:   { default: '', rows: 3, maxlength: 2000, null: true, translate: false },
      position:  2000,
    },
    {
      name:      'dom_servis_work_tags',
      display:   'Dom-Servis Work Tags',
      data_type: 'textarea',
      column:    :text,
      options:   { default: '', rows: 2, maxlength: 1000, null: true, translate: false },
      position:  2010,
    },
    {
      name:      'dom_servis_description',
      display:   'Dom-Servis Description',
      data_type: 'textarea',
      column:    :text,
      options:   { default: '', rows: 6, maxlength: 8000, null: true, translate: false },
      position:  2020,
    },
    {
      name:      'dom_servis_comment',
      display:   'Dom-Servis Comment',
      data_type: 'textarea',
      column:    :text,
      options:   { default: '', rows: 4, maxlength: 4000, null: true, translate: false },
      position:  2030,
    },
    {
      name:      'dom_servis_assignee_name',
      display:   'Dom-Servis Assignee',
      data_type: 'input',
      column:    :string,
      options:   { type: 'text', maxlength: 200, null: true, translate: false },
      position:  2040,
    },
  ].freeze

  INDEX_COLUMNS = %i[
    dom_servis_job_code
    dom_servis_dispatch_status
    dom_servis_service_type
    dom_servis_visit_date
  ].freeze

  def up
    add_ticket_columns
    return if !Setting.exists?(name: 'system_init_done')

    create_object_manager_attributes
  end

  def down
    remove_object_manager_attributes
    remove_ticket_columns
  end

  private

  def add_ticket_columns
    FIELD_DEFINITIONS.each do |field|
      next if column_exists?(:tickets, field[:name])

      add_column :tickets, field[:name], field[:column]
    end

    Ticket.reset_column_information

    INDEX_COLUMNS.each do |column_name|
      next if !column_exists?(:tickets, column_name)
      next if index_exists?(:tickets, column_name)

      add_index :tickets, column_name
    end
  end

  def remove_ticket_columns
    INDEX_COLUMNS.each do |column_name|
      remove_index :tickets, column_name if index_exists?(:tickets, column_name)
    end

    FIELD_DEFINITIONS.reverse_each do |field|
      next if !column_exists?(:tickets, field[:name])

      remove_column :tickets, field[:name]
    end

    Ticket.reset_column_information
  end

  def create_object_manager_attributes
    UserInfo.current_user_id = 1

    FIELD_DEFINITIONS.each do |field|
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
  ensure
    UserInfo.current_user_id = nil
  end

  def remove_object_manager_attributes
    FIELD_DEFINITIONS.each do |field|
      attribute = ObjectManager::Attribute.get(object: 'Ticket', name: field[:name])
      next if attribute.blank?

      attribute.destroy!
    end
  end
end
