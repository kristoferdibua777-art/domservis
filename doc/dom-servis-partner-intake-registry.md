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
7. If the embed is rendered in an iframe, forward the parent page origin as `request_source_origin` so allowed-domain checks can validate the real partner site.
8. The generated iframe already contains the consent text and the partner privacy-policy link.
9. The generated embed listens for resize messages from the iframe and updates the iframe height automatically, so partner modals do not need a second inner scrollbar.

## Runtime flow

- Partner site submits a Zammad form.
- The iframe shows only `name`, `phone`, and consent to the customer.
- The iframe fills dispatch placeholders such as `service_type`, `address`, and `visit_date` automatically before submit.
- The iframe posts its height to the parent window as the layout changes.
- Zammad creates a `Ticket`.
- The Dom-Servis intake bridge resolves `request_source_token` to a registry record and, when present, validates `request_source_origin` against the allowed-domain list.
- The bridge promotes the ticket into a `DispatchJob`.
- The job stores `request_source_id`, `organization_id`, and the intake metadata needed for reporting.

## Legacy compatibility

- The old `dom_servis_form_intake_enabled` and `dom_servis_form_organization_id` settings remain as a fallback during migration.
- They should not be used for new partner onboarding.
- New partners should always be created through the registry.

## Non-native sources

Future sources such as webhook or AI intake should bind through the same registry record shape, even if they create `DispatchJob` directly instead of going through the Zammad form transport.
