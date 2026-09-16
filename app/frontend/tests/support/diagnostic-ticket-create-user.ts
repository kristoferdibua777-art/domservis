// Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

// TEMPORARY, NARROWLY-GATED diagnostic instrumentation for round-5
// investigation of the two `ticket-create-user.spec.ts` timeouts (both hang
// waiting for a 3rd FormUpdater call that never becomes observable after
// typing into the "Create new customer" flyout's Email field).
//
// This module is inert unless DOMSERVIS_DIAGNOSTIC_TICKET_CREATE_USER=1 is
// set in the environment - normal CI and local runs (including every other
// spec file) are completely unaffected, since:
//   - `diagnosticTicketCreateUserEnabled()` is checked before any work is
//     done at every call site;
//   - the only consumers of this module (`ticket-create-user.spec.ts` and
//     the GraphQL mock link in `tests/graphql/builders/mocks.ts`) additionally
//     gate their formUpdater-specific logging on the `formUpdater` operation
//     name, so even with the flag on, no other query/spec produces output.
//
// Intended to be removed once the round-5/6 root cause is demonstrated and
// fixed; not meant as permanent test infrastructure.
const enabled = process.env.DOMSERVIS_DIAGNOSTIC_TICKET_CREATE_USER === '1'

let sequence = 0

export const diagnosticTicketCreateUserEnabled = () => enabled

export const diagnosticTicketCreateUserLog = (label: string, data?: Record<string, unknown>) => {
  if (!enabled) return

  sequence += 1

  console.log(
    `[DOMSERVIS_DIAGNOSTIC_TICKET_CREATE_USER] #${sequence} ${new Date().toISOString()} ${label}${
      data ? ` ${JSON.stringify(data)}` : ''
    }`,
  )
}
