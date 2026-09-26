# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class DomServis::Dispatch::ClientResolver
  MIN_PHONE_DIGITS = 10
  MAX_PHONE_DIGITS = 15

  def self.normalize_phone(value)
    raw_phone = value.to_s.strip
    international_prefix = raw_phone.start_with?('+', '00')
    digits = raw_phone.gsub(/\D/, '')
    return if digits.blank?

    digits = digits.delete_prefix('00')
    digits = "7#{digits}" if digits.length == 10 && !international_prefix
    digits = "7#{digits[1..]}" if digits.length == 11 && digits.start_with?('8')
    return if !digits.length.between?(MIN_PHONE_DIGITS, MAX_PHONE_DIGITS)

    "+#{digits}"
  end

  def initialize(name:, phone:, operator: nil)
    @name = name
    @phone = phone
    @operator = operator
  end

  attr_reader :name, :phone, :operator

  def resolve!
    normalized_phone = self.class.normalize_phone(phone)
    raise Exceptions::UnprocessableEntity, __('A valid client phone is required.') if normalized_phone.blank?

    matches = matching_users(normalized_phone)
    if matches.many?
      raise Exceptions::UnprocessableEntity,
            __('More than one user has this normalized phone. Select or correct the client before creating the dispatch job.')
    end

    customer = matches.first || create_customer!(normalized_phone)
    ensure_customer_role!(customer)
    customer
  end

  private

  def matching_users(normalized_phone)
    User
      .where.not(phone: [nil, ''])
      .or(User.where.not(mobile: [nil, '']))
      .reorder(:id)
      .select do |user|
        [user.phone, user.mobile]
          .filter_map { |value| self.class.normalize_phone(value) }
          .include?(normalized_phone)
      end
  end

  def create_customer!(normalized_phone)
    firstname, lastname = normalized_name
    role = customer_role

    User.create!(
      firstname:,
      lastname:,
      phone:         normalized_phone,
      password:      '',
      active:        true,
      role_ids:      [role.id],
      created_by_id: operator&.id,
      updated_by_id: operator&.id,
    )
  end

  def ensure_customer_role!(user)
    role = customer_role
    return user if user.roles.exists?(role.id)

    user.roles << role
    user
  end

  def customer_role
    @customer_role ||= Role.find_by(name: 'Customer') ||
      raise(Exceptions::UnprocessableEntity, __('Customer role is not configured.'))
  end

  def normalized_name
    parts = name.to_s.squish.split(' ', 2)
    [parts.first.presence || __('Customer'), parts.second]
  end
end
