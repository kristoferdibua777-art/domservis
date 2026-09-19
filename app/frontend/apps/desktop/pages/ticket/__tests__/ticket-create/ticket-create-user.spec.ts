// Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

import { within } from '@testing-library/vue'

import FormUpdaterUser from '#tests/graphql/factories/types/FormUpdaterUser.ts'
import { cleanup } from '#tests/support/components/renderComponent.ts'
import { diagnosticTicketCreateUserLog } from '#tests/support/diagnostic-ticket-create-user.ts'
import { mockPermissions } from '#tests/support/mock-permissions.ts'
import { waitUntil } from '#tests/support/vitest-wrapper.ts'

import { destroyComponent } from '#shared/components/DynamicInitializer/manage.ts'
import {
  mockFormUpdaterQuery,
  waitForFormUpdaterQueryCalls,
} from '#shared/components/Form/graphql/queries/formUpdater.mocks.ts'
import { mockObjectManagerFrontendAttributesQuery } from '#shared/entities/object-attributes/graphql/queries/objectManagerFrontendAttributes.mocks.ts'
import { waitForUserAddMutationCalls } from '#shared/entities/user/graphql/mutations/add.mocks.ts'
import { convertToGraphQLId } from '#shared/graphql/utils.ts'

import { getOpenedFlyouts } from '#desktop/components/CommonFlyout/useFlyout.ts'

import { handleMockFormUpdaterQuery, visitCreateView } from '../support/ticket-create-helpers.ts'

const waitForFormUpdaterQueryCallCount = (expectedCount: number) =>
  waitUntil(async () => {
    const calls = await waitForFormUpdaterQueryCalls()
    return calls.length >= expectedCount ? calls : false
  })

describe('ticket create view - user create action', () => {
  beforeEach(async () => {
    // Full-suite workers keep rendered wrappers because VTL auto-cleanup is disabled.
    // Remove wrappers left by earlier files before exercising this stateful flyout flow.
    cleanup()

    // The global test flyout host is intentionally mounted once per worker.
    // Ensure stale overlays from earlier files cannot leak into this suite.
    await destroyComponent('flyout')
    getOpenedFlyouts().clear()

    // Main form
    handleMockFormUpdaterQuery()
  })

  it('does not allow agent to toggle customer role when creating user', async () => {
    diagnosticTicketCreateUserLog('test:start', {
      test: 'does not allow agent to toggle customer role when creating user',
    })

    mockPermissions(['ticket.agent'])

    const view = await visitCreateView()

    diagnosticTicketCreateUserLog('test:main-form-rendered')

    mockObjectManagerFrontendAttributesQuery({
      objectManagerFrontendAttributes: {
        attributes: [],
        screens: [
          {
            name: 'create',
            attributes: [
              'firstname',
              'lastname',
              'email',
              'web',
              'phone',
              'mobile',
              'fax',
              'organization_id',
              'organization_ids',
              'address',
              'password',
              'vip',
              'note',
              'role_ids',
              'group_ids',
            ],
          },
        ],
      },
    })

    mockFormUpdaterQuery({
      formUpdater: {
        ...FormUpdaterUser(),
        fields: {
          ...FormUpdaterUser().fields,
          role_ids: {
            ...FormUpdaterUser().fields!.role_ids,
            show: false,
            hidden: true,
          },
        },
      },
    })

    await view.events.click(await view.findByLabelText('Create new customer'))

    const flyout = await view.findByRole('complementary', { name: 'Create new customer' })

    diagnosticTicketCreateUserLog('test:flyout-opened')

    expect(await waitForFormUpdaterQueryCallCount(2)).toHaveLength(2) // ticket create + user edit

    const emailField = await within(flyout).findByLabelText('Email')

    diagnosticTicketCreateUserLog('test:before-email-typing')

    await view.events.type(emailField, 'foo@customer.com')

    diagnosticTicketCreateUserLog('test:after-email-typing')

    diagnosticTicketCreateUserLog('test:before-waitForFormUpdaterQueryCalls-length-3')

    const callsAfterEmail = await waitForFormUpdaterQueryCallCount(3)

    diagnosticTicketCreateUserLog('test:after-waitForFormUpdaterQueryCalls-length-3', {
      observedLength: callsAfterEmail.length,
    })

    expect(callsAfterEmail).toHaveLength(3) // ticket create + user edit x2

    const customerSwitch = within(flyout).queryByRole('switch', {
      name: 'CustomerPeople who create Tickets ask for help.',
    })

    expect(customerSwitch).not.toBeInTheDocument()

    await view.events.click(within(flyout).getByRole('button', { name: 'Create' }))

    const calls = await waitForUserAddMutationCalls()

    // Agent should create users without explicitly setting roleIds (defaults will apply on backend)
    expect(calls[0].variables.input).toMatchObject({
      email: 'foo@customer.com',
    })

    expect(calls[0].variables.input.roleIds).toBeUndefined()
  })

  it('allows admin to create user and toggle customer role', async () => {
    diagnosticTicketCreateUserLog('test:start', {
      test: 'allows admin to create user and toggle customer role',
    })

    mockPermissions(['admin.user', 'ticket.agent'])

    const view = await visitCreateView()

    diagnosticTicketCreateUserLog('test:main-form-rendered')

    mockObjectManagerFrontendAttributesQuery({
      objectManagerFrontendAttributes: {
        attributes: [],
        screens: [
          {
            name: 'create',
            attributes: [
              'firstname',
              'lastname',
              'email',
              'web',
              'phone',
              'mobile',
              'fax',
              'organization_id',
              'organization_ids',
              'address',
              'password',
              'vip',
              'note',
              'role_ids',
              'group_ids',
            ],
          },
        ],
      },
    })

    mockFormUpdaterQuery({
      formUpdater: FormUpdaterUser(),
    })

    await view.events.click(await view.findByLabelText('Create new customer'))

    const flyout = await view.findByRole('complementary', { name: 'Create new customer' })

    diagnosticTicketCreateUserLog('test:flyout-opened')

    expect(await waitForFormUpdaterQueryCallCount(2)).toHaveLength(2) // ticket create + user edit

    const emailField = await within(flyout).findByLabelText('Email')

    diagnosticTicketCreateUserLog('test:before-email-typing')

    await view.events.type(emailField, 'foo@customer.com')

    diagnosticTicketCreateUserLog('test:after-email-typing')

    diagnosticTicketCreateUserLog('test:before-waitForFormUpdaterQueryCalls-length-3')

    const callsAfterEmail = await waitForFormUpdaterQueryCallCount(3)

    diagnosticTicketCreateUserLog('test:after-waitForFormUpdaterQueryCalls-length-3', {
      observedLength: callsAfterEmail.length,
    })

    expect(callsAfterEmail).toHaveLength(3) // ticket create + user edit x2

    const customerSwitch = within(flyout).getByRole('switch', {
      name: 'CustomerPeople who create Tickets ask for help.',
    })

    expect(customerSwitch).toBeEnabled()

    diagnosticTicketCreateUserLog('test:before-customer-switch-click')

    await view.events.click(customerSwitch)

    diagnosticTicketCreateUserLog('test:after-customer-switch-click')

    diagnosticTicketCreateUserLog('test:before-waitForFormUpdaterQueryCalls-length-4')

    const callsAfterRoleToggle = await waitForFormUpdaterQueryCallCount(4)

    diagnosticTicketCreateUserLog('test:after-waitForFormUpdaterQueryCalls-length-4', {
      observedLength: callsAfterRoleToggle.length,
    })

    expect(callsAfterRoleToggle).toHaveLength(4) // ticket create + user edit x3

    await view.events.click(within(flyout).getByRole('button', { name: 'Create' }))

    const calls = await waitForUserAddMutationCalls()

    expect(calls[0].variables.input).toMatchObject({
      email: 'foo@customer.com',
      roleIds: [convertToGraphQLId('Role', 3)],
    })
  })
})
