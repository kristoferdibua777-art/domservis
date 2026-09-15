# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class AddOrganizationToDomServisDispatchJobs < ActiveRecord::Migration[7.2]
  class DispatchJob < ActiveRecord::Base
    self.table_name = 'dom_servis_dispatch_jobs'
  end

  class Organization < ActiveRecord::Base
    self.table_name = 'organizations'
  end

  class User < ActiveRecord::Base
    self.table_name = 'users'
  end

  def up
    add_reference :dom_servis_dispatch_jobs, :organization, foreign_key: true, type: :integer

    DispatchJob.reset_column_information
    private_order = find_or_create_private_order_organization

    return if !private_order

    # rubocop:disable Rails/SkipsModelValidations -- migration data
    # backfill: intentionally skips validations/callbacks for a one-time
    # bulk update of historical rows.
    DispatchJob.where(organization_id: nil).update_all(organization_id: private_order.id)
    # rubocop:enable Rails/SkipsModelValidations

  end

  def down
    remove_reference :dom_servis_dispatch_jobs, :organization, foreign_key: true
  end

  private

  def find_or_create_private_order_organization
    system_user = User.reorder(:id).first
    return nil if !system_user

    Organization.find_or_create_by!(name: 'Частный заказ') do |organization|
      organization.active = true if organization.has_attribute?(:active)
      organization.shared = false if organization.has_attribute?(:shared)
      organization.note = 'System organization for direct Dom-Servis retail jobs.' if organization.has_attribute?(:note)
      organization.created_by_id = system_user.id if organization.has_attribute?(:created_by_id)
      organization.updated_by_id = system_user.id if organization.has_attribute?(:updated_by_id)
    end
  end
end
