# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# 20260322010000_add_dom_servis_backing_ticket_fields added the Dom-Servis
# ticket columns everywhere but their ObjectManager attributes only on a
# system that was already set up, so a fresh install never had them (step 7.3
# of install.md added them by hand). The seeds create them now; this adds the
# missing ones on systems installed before that. Existing ones are kept.
class EnsureDomServisBackingTicketFieldAttributes < ActiveRecord::Migration[7.2]
  def up
    return if !Setting.exists?(name: 'system_init_done')

    DomServis::Dispatch::BackingTicket::Fields.ensure_object_manager_attributes!
  end
end
