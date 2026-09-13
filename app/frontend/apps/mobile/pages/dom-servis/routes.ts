// Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

import {
  domServisDispatchDesktopPath,
  domServisDispatchTitle,
} from '#mobile/lib/domServisDispatch.ts'

import type { RouteRecordRaw } from 'vue-router'

const redirectToDesktopDispatch = () => {
  window.location.assign(domServisDispatchDesktopPath)
  return false
}

const route: RouteRecordRaw[] = [
  {
    path: '/dom-servis/dispatch',
    name: 'DomServisDispatch',
    props: true,
    component: () => import('./views/DomServisDispatch.vue'),
    beforeEnter: redirectToDesktopDispatch,
    meta: {
      title: domServisDispatchTitle,
      requiresAuth: true,
      requiredPermission: ['dom_servis.admin', 'dom_servis.dispatcher', 'dom_servis.master'],
      hasBottomNavigation: true,
      hasHeader: true,
      level: 1,
    },
  },
]

export default route
