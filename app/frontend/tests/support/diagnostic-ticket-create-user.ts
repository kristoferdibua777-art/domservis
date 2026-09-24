// Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

import { getNode, type FormKitNode } from '@formkit/core'
import { onTestFinished } from 'vitest'

// TEMPORARY, NARROWLY-GATED diagnostic instrumentation for round-5
// investigation of the two `ticket-create-user.spec.ts` timeouts (both hang
// waiting for a 3rd FormUpdater call that never becomes observable after
// typing into the "Create new customer" flyout's Email field).
//
// Round 8: the full-suite hang now sits after the 3rd FormUpdater call and
// before any userAdd request, so the flyout form state around the "Create"
// click is logged as well (see diagnosticFlyoutFormState below).
//
// This module is inert unless DOMSERVIS_DIAGNOSTIC_TICKET_CREATE_USER=1 is
// set in the environment - normal CI and local runs (including every other
// spec file) are completely unaffected, since:
//   - `diagnosticTicketCreateUserEnabled()` is checked before any work is
//     done at every call site;
//   - the only consumers of this module (`ticket-create-user.spec.ts` and
//     the GraphQL mock link in `tests/graphql/builders/mocks.ts`) additionally
//     gate their logging on the `formUpdater` and `userAdd` operation names,
//     so even with the flag on, no other query/spec produces output.
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

const messageKeys = (node: FormKitNode, onlyBlocking: boolean) =>
  Object.keys(node.store).filter((key) => {
    const message = node.store[key]
    return Boolean(message) && (!onlyBlocking || message.blocking)
  })

// Snapshot of the form the given submit button belongs to (via its `form`
// attribute): what can keep FormKit from submitting it.
const diagnosticFlyoutFormState = (submitButton: HTMLButtonElement) => {
  const formId = submitButton.getAttribute('form')
  const node = formId ? getNode(formId) : undefined

  if (!node) return { formId, node: 'missing' }

  const blocking = messageKeys(node, true)

  node.walk((child) => {
    messageKeys(child, true).forEach((key) => blocking.push(`${child.name}:${key}`))
  })

  return {
    formId,
    buttonDisabled: submitButton.disabled,
    formMessages: messageKeys(node, false),
    blocking,
    blockingCount: node.ledger.value('blocking'),
    disabled: Boolean(node.context?.disabled),
    valid: node.context?.state.valid,
    settled: node.context?.state.settled,
    submitted: node.context?.state.submitted,
    formUpdaterProcessing: Boolean(node.context?.state.formUpdaterProcessing),
  }
}

export const diagnosticLogFlyoutForm = (label: string, submitButton: HTMLButtonElement) => {
  if (!enabled) return

  diagnosticTicketCreateUserLog(label, diagnosticFlyoutFormState(submitButton))
}

// Logs the form state every few seconds until stopped, so a hang shows what
// the form was waiting for. Also stopped when the test finishes or times out.
export const diagnosticWatchFlyoutForm = (label: string, submitButton: HTMLButtonElement) => {
  if (!enabled) return () => {}

  const timer = setInterval(() => diagnosticLogFlyoutForm(label, submitButton), 3000)
  const stop = () => clearInterval(timer)

  onTestFinished(stop)

  return stop
}
