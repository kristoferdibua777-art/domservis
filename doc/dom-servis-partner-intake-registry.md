# Dom-Servis Partner Intake Registry

This note describes the working model for partner intake in Dom-Servis after the introduction of the registry-backed bridge.

## Source of truth

- `DispatchJob` is the operational source of truth.
- `Ticket` is the intake/backing/history projection.
- `Organization` is the partner/account record used for statistics and routing context.
- `DomServis::RequestSource` is the canonical partner intake registry.

## Partner onboarding flow

1. Create or reuse a Zammad `Organization` for the partner.
2. Create a `DomServis::RequestSource` in `#manage/dom_servis_request_sources`.
3. Set:
   - `partner_key`
   - `organization`
   - `transport_kind = zammad_form`
   - `status = active`
   - `allowed_domains` if the embed should be restricted
   - `privacy_policy_url` to the partner privacy policy page
4. Copy the generated `embed_url` or `embed_snippet`.
5. Place the snippet on the partner site.
6. The partner site must pass `request_source_token` only; it must not send `organization_id`.
7. If the embed is rendered in an iframe, forward the parent page origin as `request_source_origin` so allowed-domain
   checks can validate the real partner site.
8. The generated iframe already contains the consent text and the partner privacy-policy link.
9. The generated embed listens for resize messages from the iframe and updates the iframe height automatically, so
   partner modals do not need a second inner scrollbar.

## Client link (standalone page)

Every request source also exposes `client_form_url`
(`/assets/form/dom-servis-client-request.html?request_source_token=…`), shown in the admin card as
"Ссылка на форму для клиентов". It is a full page on our own domain for customers who open a link directly
(messenger, QR code, social profile) instead of an iframe on a partner site.

- The customer answers one question per screen: what needs doing, what happened and the equipment brand,
  address and preferred time, then name, phone and consent.
- The page uses the same `form_config` / `form_submit` channel and `request_source_token` as the embed, so the
  request becomes a `Ticket` plus a `DispatchJob` attributed to the source's partner organization.
- Unlike the embed, it fills `service_type`, `address`, `description` and `comment` with the customer's answers;
  "Срочно, сегодня" sets priority `high`, "Завтра" sets tomorrow's visit date, and visit time stays
  "Уточнить у клиента".
- For a source used only through this link, leave `allowed_domains` empty: the page reports our domain as its origin,
  so the source card offers the link only when no partner domains are set.

## Runtime flow

- Partner site submits a Zammad form.
- The iframe shows a step-by-step form: contacts (`name`, `phone`, optional address), the problem with an optional
  issue field (error code or description, sent in the ticket description), the equipment brand, then consent.
- The iframe fills dispatch placeholders such as `service_type`, `address`, and `visit_date` automatically before submit.
- A source can tune the form through its `settings`, which `form_config` returns as `request_source.settings`:
  `form_title` (ticket title), `service_type`, `address_placeholder` (address sent when none is asked),
  `issue_label`, `issue_placeholder` and `submit_button_text`. Without settings the form uses generic texts
  ("Уточнить у клиента" for service type and address). Any replacement of this form must keep honouring these keys.
- The iframe posts its height to the parent window as the layout changes.
- Zammad creates a `Ticket`.
- The Dom-Servis intake bridge resolves `request_source_token` to a registry record and, when present, validates
  `request_source_origin` against the allowed-domain list.
- The bridge promotes the ticket into a `DispatchJob`.
- The job stores `request_source_id`, `organization_id`, and the intake metadata needed for reporting.

## Legacy compatibility

- The old `dom_servis_form_intake_enabled` and `dom_servis_form_organization_id` settings remain as a fallback during migration.
- They should not be used for new partner onboarding.
- New partners should always be created through the registry.

## Non-native sources

Future sources such as webhook or AI intake should bind through the same registry record shape, even if they create
`DispatchJob` directly instead of going through the Zammad form transport.
