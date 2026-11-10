# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class DomServis::Dispatch::BoardPartner
  # Server-side configuration: DOM_SERVIS_BOARD_PARTNER_<user ID>=<source key>:<organization ID>.
  # The board organization can differ from the organization used by the source's public form.
  def self.for(user)
    configuration = ENV["DOM_SERVIS_BOARD_PARTNER_#{user.id}"].presence
    return if configuration.blank?

    source_key, organization_id = configuration.split(':', 2)
    source = DomServis::RequestSource.find_by(partner_key: source_key, status: 'active')
    organization = Organization.find_by(id: Integer(organization_id, 10, exception: false), active: true)

    if source.blank? || organization.blank?
      raise Exceptions::UnprocessableEntity, __('The dispatch partner configuration is invalid. Contact your administrator.')
    end

    new(source:, organization:)
  end

  def initialize(source:, organization:)
    @source = source
    @organization = organization
  end

  attr_reader :source, :organization
end
