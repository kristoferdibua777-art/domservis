# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Lists the work tag dictionary (DomServis::WorkTagCatalog) in Manage > Tags
# of a set-up system. The board offers the dictionary tags anyway; a fresh
# install gets them in step 7.3 of install.md or with their first use.
class CreateDomServisWorkTags < ActiveRecord::Migration[7.2]
  def up
    return if !Setting.exists?(name: 'system_init_done')

    DomServis::WorkTagCatalog.sync!
  end
end
