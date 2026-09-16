// Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

// `vi.mock` must sit at the top level of the module for Vitest to process it
// reliably - a call wrapped inside an exported function (the previous shape
// of this file) is only hoisted by an implementation detail Vitest already
// warns about, and is slated to become a hard error in a future version.
//
// Moving it here is safe without touching any consumer: every current call
// site across the repository (confirmed by a full-repository search) invokes
// `mockRouterHooks()` unconditionally, at the top level of its own spec file,
// immediately after the imports - never behind a condition, and never
// imported without being called. So the mock was already being installed,
// unconditionally, for exactly the same set of test files every time this
// module was imported; hoisting it here changes nothing about when or for
// which files it applies. `mockRouterHooks` is kept as a no-op export purely
// so none of those ~20 existing call sites need to change.
vi.mock('vue-router', async () => {
  const module = await vi.importActual<typeof import('vue-router')>('vue-router')

  return {
    ...module,
    onBeforeRouteUpdate: vi.fn(),
    onBeforeRouteLeave: vi.fn(),
  }
})

export const mockRouterHooks = () => undefined
