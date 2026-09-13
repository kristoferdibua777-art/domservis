# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class AddDomServisFormIntakeSettings < ActiveRecord::Migration[7.2]
  def up
    Setting.create_if_not_exists(
      title:       __('Enable Dom-Servis intake bridge'),
      name:        'dom_servis_form_intake_enabled',
      area:        'Form::Base',
      description: __('Defines if web form tickets should be promoted to Dom-Servis dispatch jobs.'),
      options:     {
        form: [
          {
            display: '',
            null:    true,
            name:    'dom_servis_form_intake_enabled',
            tag:     'boolean',
            options: {
              true  => 'yes',
              false => 'no',
            },
          },
        ],
      },
      state:       false,
      preferences: {
        permission: ['admin.channel_formular'],
      },
      frontend:    false,
    )

    Setting.create_if_not_exists(
      title:       __('Dom-Servis partner organization'),
      name:        'dom_servis_form_organization_id',
      area:        'Form::Base',
      description: __('Defines which partner organization owns tickets promoted from the web form.'),
      options:     {
        form: [
          {
            display:  '',
            null:     true,
            name:     'dom_servis_form_organization_id',
            tag:      'tree_select',
            multiple: false,
            relation: 'Organization',
          },
        ],
      },
      state:       nil,
      preferences: {
        permission: ['admin.channel_formular'],
      },
      frontend:    false,
    )
  end

  def down
    Setting.where(name: %w[dom_servis_form_intake_enabled dom_servis_form_organization_id]).destroy_all
  end
end
