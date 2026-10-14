# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Adds the setting with the GigaChat key and options of the pasted text
# reading on the dispatch board. Fresh installs get it from the seeds.
class AddDomServisAIIntakeSetting < ActiveRecord::Migration[7.2]
  def up
    return if !Setting.exists?(name: 'system_init_done')

    Setting.create_if_not_exists(
      title:       'ИИ-разбор текста заявок (GigaChat)',
      name:        'dom_servis_ai_intake_config',
      area:        'DomServis::AI',
      description: 'Ключ авторизации и параметры GigaChat для разбора текста заявок на доске диспетчера. Ключ хранится только на сервере.',
      options:     {},
      state:       {},
      preferences: {
        prio:       3660,
        permission: ['dom_servis.admin'],
      },
      frontend:    false
    )
  end
end
