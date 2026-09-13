class AddPrivacyPolicyUrlToDomServisRequestSources < ActiveRecord::Migration[7.2]
  def change
    add_column :dom_servis_request_sources, :privacy_policy_url, :string
  end
end
