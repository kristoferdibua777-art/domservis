// Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

import { within } from '@testing-library/vue'

import FormUpdaterUser from '#tests/graphql/factories/types/FormUpdaterUser.ts'
import { diagnosticTicketCreateUserLog } from '#tests/support/diagnostic-ticket-create-user.ts'
import { mockPermissions } from '#tests/support/mock-permissions.ts'

import {
  mockFormUpdaterQuery,
  waitForFormUpdaterQueryCalls,
} from '#shared/components/Form/graphql/queries/formUpdater.mocks.ts'
import { mockObjectManagerFrontendAttributesQuery } from '#shared/entities/object-attributes/graphql/queries/objectManagerFrontendAttributes.mocks.ts'
import { waitForUserAddMutationCalls } from '#shared/entities/user/graphql/mutations/add.mocks.ts'
import { convertToGraphQLId } from '#shared/graphql/utils.ts'

import { handleMockFormUpdaterQuery, visitCreateView } from '../support/ticket-create-helpers.ts'

describe('ticket create view - user create action', () => {
  beforeEach(() => {
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

    expect(await waitForFormUpdaterQueryCalls()).toHaveLength(2) // ticket create + user edit

    const emailField = await within(flyout).findByLabelText('Email')

    diagnosticTicketCreateUserLog('test:before-email-typing')

    await view.events.type(emailField, 'foo@customer.com')

    diagnosticTicketCreateUserLog('test:after-email-typing')

    diagnosticTicketCreateUserLog('test:before-waitForFormUpdaterQueryCalls-length-3')

    const callsAfterEmail = await waitForFormUpdaterQueryCalls()

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

    expect(await waitForFormUpdaterQueryCalls()).toHaveLength(2) // ticket create + user edit

    const emailField = await within(flyout).findByLabelText('Email')

    diagnosticTicketCreateUserLog('test:before-email-typing')

    await view.events.type(emailField, 'foo@customer.com')

    diagnosticTicketCreateUserLog('test:after-email-typing')

    diagnosticTicketCreateUserLog('test:before-waitForFormUpdaterQueryCalls-length-3')

    const callsAfterEmail = await waitForFormUpdaterQueryCalls()

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

    const callsAfterRoleToggle = await waitForFormUpdaterQueryCalls()

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
