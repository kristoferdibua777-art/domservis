<!-- Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/ -->

<script setup lang="ts">
import { computed } from 'vue'

import CommonInputSearch from '#shared/components/CommonInputSearch/CommonInputSearch.vue'
import { useSessionStore } from '#shared/stores/session.ts'

import CommonSectionMenu from '#mobile/components/CommonSectionMenu/CommonSectionMenu.vue'
import type { MenuItem } from '#mobile/components/CommonSectionMenu/index.ts'
import CommonTicketCreateLink from '#mobile/components/CommonTicketCreateLink/CommonTicketCreateLink.vue'
import { useTicketOverviews } from '#mobile/entities/ticket/composables/useTicketOverviews.ts'
import {
  domServisDispatchLabel,
  domServisDispatchMobilePath,
  hasDomServisDispatchAccess,
} from '#mobile/lib/domServisDispatch.ts'

const IS_DEV = import.meta.env.DEV

const session = useSessionStore()

const menu = computed<MenuItem[]>(() => {
  const items: MenuItem[] = []

  if (hasDomServisDispatchAccess(session)) {
    items.push({
      type: 'link',
      link: domServisDispatchMobilePath,
      label: 'Диспетчерская доска',
      information: domServisDispatchLabel,
      icon: { name: 'mobile-tasklist', size: 'base' },
      iconBg: 'bg-blue',
    })
  }

  items.push({
    type: 'link',
    link: '/tickets/view',
    label: __('Ticket overviews'),
    icon: { name: 'all-tickets', size: 'base' },
    iconBg: 'bg-pink',
    permission: ['ticket.agent', 'ticket.customer'],
  })

  if (IS_DEV) {
    items.push({
      type: 'link',
      link: '/playground',
      label: 'Playground',
      icon: { name: 'settings', size: 'small' as const },
      iconBg: 'bg-orange',
    })
  }

  return items
})

const overviews = useTicketOverviews()

const ticketOverview = computed<MenuItem[]>(() => {
  if (overviews.loading) return []

  return overviews.includedOverviews.map((overview) => {
    return {
      type: 'link',
      link: `/tickets/view/${overview.link}`,
      label: overview.name,
      information: overview.ticketCount,
    }
  })
})
</script>

<template>
  <div class="p-4">
    <CommonTicketCreateLink class="mt-1.5 mb-3" />
    <h1 class="mb-5 flex w-full items-center justify-center text-4xl font-bold">
      {{ $t('Home') }}
    </h1>
    <CommonLink :aria-label="$t('Search…')" link="/search">
      <CommonInputSearch aria-hidden="true" tabindex="-1" wrapper-class="mb-4" no-border />
    </CommonLink>
    <CommonSectionMenu
      :items="menu"
      :help="
        hasDomServisDispatchAccess(session)
          ? 'Основной рабочий экран мастера и диспетчера открывается через Дом-Сервис.'
          : undefined
      "
    />
    <CommonSectionMenu
      v-if="session.hasPermission(['ticket.agent', 'ticket.customer'])"
      :items="ticketOverview"
      :header-label="__('Ticket overview')"
      :action-label="__('Edit')"
      action-link="/favorite/ticket-overviews/edit"
    >
      <template v-if="overviews.loading" #before-items>
        <div class="flex w-full justify-center">
          <CommonIcon name="loading" animation="spin" />
        </div>
      </template>
    </CommonSectionMenu>
  </div>
</template>
