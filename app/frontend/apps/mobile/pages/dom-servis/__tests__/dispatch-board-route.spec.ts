// Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

import routes from '../routes.ts'

describe('Dom-Servis dispatch board route', () => {
  it('opens the board in its installable shell, where Web Push can be enabled', () => {
    const assign = vi.fn()

    Object.defineProperty(window, 'location', {
      value: {
        ...window.location,
        assign,
      },
    })

    const [route] = routes
    const guard = route.beforeEnter as unknown as () => boolean

    expect(guard()).toBe(false)
    expect(assign).toHaveBeenCalledWith('/dispatch/#dom_servis/dispatch')
  })
})
