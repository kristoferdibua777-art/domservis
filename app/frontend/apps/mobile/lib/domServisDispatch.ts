// Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

import type { useSessionStore } from '#shared/stores/session.ts'

const dispatchPermissions = ['dom_servis.admin', 'dom_servis.dispatcher', 'dom_servis.master'] as const

export const domServisDispatchDesktopPath = '/#dom_servis/dispatch'
export const domServisDispatchMobilePath = '/dom-servis/dispatch'
export const domServisDispatchLabel = 'Дом-Сервис'
export const domServisDispatchTitle = 'Диспетчерская доска'

export const hasDomServisDispatchAccess = (
  session: ReturnType<typeof useSessionStore>,
): boolean => {
  return session.hasPermission([...dispatchPermissions])
}
