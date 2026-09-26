// Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

import { visitView } from '#tests/support/components/visitView.ts'
import { mockPermissions } from '#tests/support/mock-permissions.ts'
import { mockTicketOverviews } from '#tests/support/mocks/ticket-overviews.ts'

describe('testing home section menu', () => {
  beforeEach(() => {
    mockTicketOverviews()
  })

  it('not show ticket overview section menu item without permission', async () => {
    const view = await visitView('/')

    expect(
      view.queryByRole('link', {
        name: 'Ticket overviews',
      }),
    ).not.toBeInTheDocument()
  })

  it('show ticket overview section menu item', async () => {
    mockPermissions(['ticket.agent'])

    const view = await visitView('/')

    const ticketOverviewLink = view.getByRole('link', {
      name: 'Ticket overviews',
    })

    expect(ticketOverviewLink).toHaveAttribute('href', '/mobile/tickets/view')
  })

  it('shows Dom-Servis entry for dispatch roles', async () => {
    mockPermissions(['dom_servis.master'])

    const view = await visitView('/')

    // The menu item intentionally renders an `information` subtitle
    // ("Дом-Сервис") next to the label, via CommonSectionMenuLink - see
    // Home.vue. That subtitle is plain visible text inside the same link,
    // so per the standard accessible name algorithm it is included in the
    // link's accessible name, not just its visible label.
    const dispatchLink = view.getByRole('link', {
      name: 'Диспетчерская доска Дом-Сервис',
    })

    expect(dispatchLink).toHaveAttribute('href', '/mobile/dom-servis/dispatch')
  })
})
