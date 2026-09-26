# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class AddPrivacyPolicyUrlToDomServisRequestSources < ActiveRecord::Migration[7.2]
  def change
    # rubocop:disable Zammad/ExistsResetColumnInformation -- this migration
    # never instantiates or queries the DomServisRequestSource model; it
    # only adds a column via raw DDL, so there is no cached column state
    # in this file that needs resetting.
    add_column :dom_servis_request_sources, :privacy_policy_url, :string
    # rubocop:enable Zammad/ExistsResetColumnInformation
  end
end
