# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class DomServis::Dispatch::ClientResolver
  MIN_PHONE_DIGITS = 10
  MAX_PHONE_DIGITS = 15

  def self.normalize_phone(value)
    raw_phone = value.to_s.strip.delete(' ()-')
    return if !raw_phone.match?(%r{\A(?:\+|00)?[1-9][0-9]*\z})

    international_prefix = raw_phone.start_with?('+', '00')
    digits = raw_phone.delete_prefix('+').delete_prefix('00')
    digits = "7#{digits}" if digits.length == 10 && !international_prefix
    digits = "7#{digits[1..]}" if digits.length == 11 && digits.start_with?('8') && !international_prefix
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
      # Names the users, so the dispatcher knows which records to fix.
      users = matches.map { |user| "#{user.fullname} (##{user.id})" }.join(', ')
      raise Exceptions::UnprocessableEntity,
            "#{__('More than one user has this normalized phone. Select or correct the client before creating the dispatch job.')} #{users}"
    end

    customer = matches.first || create_customer!(normalized_phone)
    ensure_customer_role!(customer)
    customer
  end

  private

  # Normalization only changes the leading digits, so a match always ends with
  # the same ten digits. The database narrows the users down to those; the
  # exact normalization then runs on these few instead of every user with a
  # phone.
  def matching_users(normalized_phone)
    tail = normalized_phone.delete_prefix('+').last(10)

    User
      .where(
        "RIGHT(REGEXP_REPLACE(COALESCE(users.phone, ''), '[^0-9]', '', 'g'), 10) = :tail OR " \
        "RIGHT(REGEXP_REPLACE(COALESCE(users.mobile, ''), '[^0-9]', '', 'g'), 10) = :tail",
        tail: tail,
      )
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
    @customer_role ||= begin
      Role.find_by(name: 'Customer') || raise(Exceptions::UnprocessableEntity, __('Customer role is not configured.'))
    end
  end

  def normalized_name
    parts = name.to_s.squish.split(' ', 2)
    [parts.first.presence || __('Customer'), parts.second]
  end
end
