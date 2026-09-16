// Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

import { flushPromises } from '@vue/test-utils'

import { renderComponent } from '#tests/support/components/index.ts'
import { mockGraphQLSubscription } from '#tests/support/mock-graphql-api.ts'
import { mockPermissions } from '#tests/support/mock-permissions.ts'

import { OnlineNotificationsCountDocument } from '#shared/entities/online-notification/graphql/subscriptions/onlineNotificationsCount.api.ts'
import { convertToGraphQLId } from '#shared/graphql/utils.ts'
import { useSessionStore } from '#shared/stores/session.ts'
import type { UserData } from '#shared/types/store.ts'

import { routes } from '#mobile/router/index.ts'

import LayoutBottomNavigation from '../LayoutBottomNavigation.vue'

import type { RouteRecordRaw } from 'vue-router'

// Use the real mobile route table (instead of the generic test router
// stub) so that CommonLink can resolve hrefs the same way it does in
// production: only a route that actually matches gets the router's
// `/mobile` history base applied. Without this, `/dom-servis/dispatch`
// falls through to the catch-all "Error" route, CommonLink treats it as
// unmatched, and the rendered href is the raw, unprefixed link target
// instead of the real `/mobile/dom-servis/dispatch` browser URL.
const mainRoutes = routes.find((route) => route.name === 'Main')?.children || []
const mobileTestRoutes: RouteRecordRaw[] = [
  {
    path: '/',
    name: 'Main',
    component: { template: '<div></div>' },
    children: mainRoutes,
  },
  {
    path: '/:pathMatch(.*)*',
    name: 'Error',
    component: { template: '<div></div>' },
  },
]

describe('bottom navigation in layout', () => {
  it('renders navigation', async () => {
    mockGraphQLSubscription(OnlineNotificationsCountDocument)
    const view = renderComponent(LayoutBottomNavigation, {
      store: true,
      router: true,
      routerRoutes: mobileTestRoutes,
    })
    const store = useSessionStore()

    store.user = {
      id: convertToGraphQLId('User', 100),
      firstname: 'User',
      lastname: 'Test',
    } as UserData

    await flushPromises()

    expect(view.getByIconName('home')).toBeInTheDocument()
    expect(view.getByIconName('home').closest('a')).toHaveClass('text-blue')

    expect(view.getByIconName('notification-subscribed')).toBeInTheDocument()
    expect(view.getByText('UT')).toBeInTheDocument()
  })

  it('rendering notifications counter', async () => {
    const subscription = mockGraphQLSubscription(OnlineNotificationsCountDocument)
    const view = renderComponent(LayoutBottomNavigation, {
      store: true,
      router: true,
      routerRoutes: mobileTestRoutes,
    })
    const store = useSessionStore()

    store.user = {
      id: convertToGraphQLId('User', 100),
      firstname: 'User',
      lastname: 'Test',
    } as UserData
    await flushPromises()

    expect(view.queryByRole('status', { name: 'Unread notifications' })).not.toBeInTheDocument()

    await subscription.next({
      data: {
        onlineNotificationsCount: {
          unseenCount: 1,
        },
      },
    })

    expect(view.getByRole('status', { name: 'Unread notifications' })).toHaveTextContent('1')
  })

  it('shows Dom-Servis tab for dispatch roles', async () => {
    mockPermissions(['dom_servis.master'])
    mockGraphQLSubscription(OnlineNotificationsCountDocument)

    const view = renderComponent(LayoutBottomNavigation, {
      store: true,
      router: true,
      routerRoutes: mobileTestRoutes,
    })
    const store = useSessionStore()

    store.user = {
      id: convertToGraphQLId('User', 100),
      firstname: 'User',
      lastname: 'Test',
      permissions: { names: ['dom_servis.master'] },
    } as UserData

    await flushPromises()

    const dispatchLink = view.getByLabelText('Дом-Сервис')

    expect(dispatchLink).toHaveAttribute('href', '/mobile/dom-servis/dispatch')
  })
})
