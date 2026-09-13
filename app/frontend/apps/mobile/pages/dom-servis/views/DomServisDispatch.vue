<!-- Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/ -->

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'

import {
  useNotifications,
  NotificationTypes,
} from '#shared/components/CommonNotifications/index.ts'
import { useSessionStore } from '#shared/stores/session.ts'

import CommonLoader from '#mobile/components/CommonLoader/CommonLoader.vue'
import { useHeader } from '#mobile/composables/useHeader.ts'
import {
  domServisDispatchDesktopPath,
  domServisDispatchLabel,
  domServisDispatchTitle,
} from '#mobile/lib/domServisDispatch.ts'

type DispatchStatus = 'pool' | 'taken' | 'in_progress' | 'done' | 'cancelled'
type DispatchFilterKey =
  | 'mine'
  | 'open'
  | 'all'
  | 'pool'
  | 'taken'
  | 'in_progress'
  | 'done'
  | 'cancelled'

interface DispatchJob {
  id: number
  job_code: string
  service_type: string
  address: string
  client_name: string
  client_phone: string
  visit_day: string
  visit_date: string
  visit_time: string
  priority: string
  status: DispatchStatus
  source: string
  assignee_id: number | null
  assignee?: string
  organization?: string
  description?: string | null
  comment?: string | null
  work_tags: string[]
  published_at?: string | null
  taken_at?: string | null
  created_at?: string | null
  updated_at?: string | null
}

interface DispatchTag {
  id: string
  name: string
  dispatch_count: number
}

interface DispatchPolicy {
  role_key?: 'master' | 'dispatcher' | 'admin'
  actions: Record<string, boolean>
  statuses: Record<string, boolean>
  fields: Record<string, { visible?: boolean; editable?: boolean }>
}

interface FilterOption {
  key: DispatchFilterKey
  label: string
  count: number
}

const session = useSessionStore()
const { notify } = useNotifications()

const loading = ref(true)
const refreshing = ref(false)
const savingJobId = ref<number | null>(null)
const jobs = ref<DispatchJob[]>([])
const tags = ref<DispatchTag[]>([])
const policy = ref<DispatchPolicy | null>(null)
const selectedFilter = ref<DispatchFilterKey>('open')
const selectedJobId = ref<number | null>(null)
const activeTagFilters = ref<string[]>([])

const csrfToken = () => {
  return document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content
}

const formatSchedule = (job: DispatchJob) => {
  const parts = [dayLabel(job.visit_day)]

  if (job.visit_date) parts.push(job.visit_date)
  if (job.visit_time) parts.push(job.visit_time)

  return parts.filter(Boolean).join(' • ')
}

const priorityLabel = (priority?: string) => {
  const map: Record<string, string> = {
    low: 'Низкий',
    medium: 'Средний',
    high: 'Высокий',
    critical: 'Критический',
  }

  return map[priority || ''] || priority || 'Не указан'
}

const statusLabel = (status?: DispatchStatus) => {
  const map: Record<string, string> = {
    pool: 'В пуле',
    taken: 'Назначена',
    in_progress: 'В работе',
    done: 'Готово',
    cancelled: 'Отменена',
  }

  return map[status || ''] || status || 'Не указан'
}

const dayLabel = (visitDay?: string) => {
  const map: Record<string, string> = {
    mon: 'Пн',
    tue: 'Вт',
    wed: 'Ср',
    thu: 'Чт',
    fri: 'Пт',
    sat: 'Сб',
    sun: 'Вс',
  }

  return map[visitDay || ''] || visitDay || 'День не указан'
}

const currentUserInternalId = computed(() => Number(session.user?.internalId || 0))
const currentUserEmail = computed(() => session.user?.email || '')
const roleLabel = computed(() => {
  const map: Record<string, string> = {
    master: 'Мастер',
    dispatcher: 'Диспетчер',
    admin: 'Владелец/администратор',
  }

  return map[policy.value?.role_key || ''] || 'Сотрудник'
})

const isMine = (job: DispatchJob) => {
  if (currentUserInternalId.value && job.assignee_id === currentUserInternalId.value) return true
  if (currentUserEmail.value && job.assignee === currentUserEmail.value) return true
  return false
}

const matchesFilter = (job: DispatchJob) => {
  switch (selectedFilter.value) {
    case 'mine':
      return isMine(job)
    case 'open':
      return !['done', 'cancelled'].includes(job.status)
    case 'all':
      return true
    default:
      return job.status === selectedFilter.value
  }
}

const matchesTags = (job: DispatchJob) => {
  if (!activeTagFilters.value.length) return true
  return activeTagFilters.value.every((tagName) => job.work_tags?.includes(tagName))
}

const filteredJobs = computed(() => {
  return jobs.value.filter((job) => matchesFilter(job) && matchesTags(job))
})

const selectedJob = computed(() => {
  return jobs.value.find((job) => job.id === selectedJobId.value) || null
})

const stats = computed(() => {
  const mine = jobs.value.filter((job) => isMine(job)).length
  const inProgress = jobs.value.filter((job) => job.status === 'in_progress').length
  const pool = jobs.value.filter((job) => job.status === 'pool').length

  return [
    { label: 'Всего', value: jobs.value.length },
    { label: 'Мои', value: mine },
    { label: 'В работе', value: inProgress },
    { label: 'В пуле', value: pool },
  ]
})

const filterOptions = computed<FilterOption[]>(() => {
  const counts = {
    mine: jobs.value.filter((job) => isMine(job)).length,
    open: jobs.value.filter((job) => !['done', 'cancelled'].includes(job.status)).length,
    all: jobs.value.length,
    pool: jobs.value.filter((job) => job.status === 'pool').length,
    taken: jobs.value.filter((job) => job.status === 'taken').length,
    in_progress: jobs.value.filter((job) => job.status === 'in_progress').length,
    done: jobs.value.filter((job) => job.status === 'done').length,
    cancelled: jobs.value.filter((job) => job.status === 'cancelled').length,
  }

  const base: FilterOption[] =
    policy.value?.role_key === 'master'
      ? [
          { key: 'mine', label: 'Мои', count: counts.mine },
          { key: 'pool', label: 'Пул', count: counts.pool },
          { key: 'in_progress', label: 'В работе', count: counts.in_progress },
          { key: 'done', label: 'Готово', count: counts.done },
        ]
      : [
          { key: 'open', label: 'Открытые', count: counts.open },
          { key: 'mine', label: 'Мои', count: counts.mine },
          { key: 'pool', label: 'Пул', count: counts.pool },
          { key: 'in_progress', label: 'В работе', count: counts.in_progress },
          { key: 'done', label: 'Готово', count: counts.done },
          { key: 'cancelled', label: 'Отменено', count: counts.cancelled },
          { key: 'all', label: 'Все', count: counts.all },
        ]

  return base
})

const applyDefaultFilter = () => {
  if (policy.value?.role_key === 'master') {
    selectedFilter.value = 'mine'
  } else {
    selectedFilter.value = 'open'
  }
}

watch(
  () => policy.value?.role_key,
  (role, previousRole) => {
    if (!role || previousRole) return
    applyDefaultFilter()
  },
)

watch(
  filteredJobs,
  (list) => {
    if (!list.length) {
      selectedJobId.value = null
      return
    }

    if (!selectedJobId.value || !list.some((job) => job.id === selectedJobId.value)) {
      selectedJobId.value = list[0].id
    }
  },
  { immediate: true },
)

const apiRequest = async <T>(path: string, init: RequestInit = {}): Promise<T> => {
  const headers = new Headers(init.headers || {})

  if (init.method && init.method !== 'GET') {
    const token = csrfToken()
    if (token) headers.set('X-CSRF-Token', token)
  }

  const response = await fetch(path, {
    credentials: 'same-origin',
    ...init,
    headers,
  })

  if (!response.ok) {
    const text = await response.text()
    throw new Error(text || `HTTP ${response.status}`)
  }

  return response.json() as Promise<T>
}

const loadJobs = async () => {
  jobs.value = await apiRequest<DispatchJob[]>(
    '/api/v1/dom_servis/dispatch/jobs?expand=true&per_page=200&sort_by=created_at,id&order_by=DESC,DESC',
  )
}

const loadPolicy = async () => {
  policy.value = await apiRequest<DispatchPolicy>('/api/v1/dom_servis/dispatch/policy')
}

const loadTags = async () => {
  const payload = await apiRequest<{ tags: DispatchTag[] }>('/api/v1/dom_servis/dispatch/tags')
  tags.value = payload.tags || []
}

const loadBoard = async () => {
  try {
    await Promise.all([loadJobs(), loadPolicy(), loadTags()])
  } catch (error) {
    notify({
      id: 'dom-servis-mobile-load-error',
      message: __('The dispatch board could not be loaded.'),
      type: NotificationTypes.Error,
    })
  } finally {
    loading.value = false
    refreshing.value = false
  }
}

const refreshBoard = () => {
  if (refreshing.value) return
  refreshing.value = true
  loadBoard()
}

const updateJob = (payload: DispatchJob) => {
  const nextJobs = [...jobs.value]
  const index = nextJobs.findIndex((item) => item.id === payload.id)

  if (index >= 0) {
    nextJobs[index] = payload
  } else {
    nextJobs.unshift(payload)
  }

  jobs.value = nextJobs
}

const submitJobAction = async (
  job: DispatchJob,
  path: string,
  body?: Record<string, string>,
  successMessage?: string,
) => {
  savingJobId.value = job.id

  try {
    const payload = body ? new URLSearchParams(body) : undefined
    const updatedJob = await apiRequest<DispatchJob>(path, {
      method: 'POST',
      body: payload,
      headers: payload
        ? {
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          }
        : undefined,
    })

    updateJob(updatedJob)
    await loadTags()

    if (successMessage) {
      notify({
        id: `dom-servis-mobile-success-${job.id}-${path}`,
        message: successMessage,
        type: NotificationTypes.Success,
      })
    }
  } catch (error) {
    notify({
      id: `dom-servis-mobile-error-${job.id}-${path}`,
      message: __('The dispatch action could not be completed.'),
      type: NotificationTypes.Error,
    })
  } finally {
    savingJobId.value = null
  }
}

const takeJob = (job: DispatchJob) =>
  submitJobAction(job, `/api/v1/dom_servis/dispatch/jobs/${job.id}/take`, undefined, 'Заявка назначена.')

const releaseJob = (job: DispatchJob) =>
  submitJobAction(
    job,
    `/api/v1/dom_servis/dispatch/jobs/${job.id}/release`,
    undefined,
    'Заявка возвращена в пул.',
  )

const setJobStatus = (job: DispatchJob, status: DispatchStatus) =>
  submitJobAction(
    job,
    `/api/v1/dom_servis/dispatch/jobs/${job.id}/status`,
    { status },
    'Статус заявки обновлён.',
  )

const canTake = (job: DispatchJob) => {
  return Boolean(policy.value?.actions.take_job) && job.status === 'pool' && !job.assignee_id
}

const canRelease = (job: DispatchJob) => {
  return Boolean(policy.value?.actions.release_to_pool) && job.status !== 'pool' && (isMine(job) || policy.value?.role_key !== 'master')
}

const canStart = (job: DispatchJob) => {
  if (!policy.value?.actions.set_status_in_progress) return false
  if (['in_progress', 'done', 'cancelled'].includes(job.status)) return false
  return job.assignee_id ? isMine(job) || policy.value?.role_key !== 'master' : false
}

const canFinish = (job: DispatchJob) => {
  if (!policy.value?.actions.set_status_done) return false
  if (job.status === 'done') return false
  return job.assignee_id ? isMine(job) || policy.value?.role_key !== 'master' : false
}

const canCancel = (job: DispatchJob) => {
  return Boolean(policy.value?.actions.cancel_job) && job.status !== 'cancelled'
}

const canReopen = (job: DispatchJob) => {
  return Boolean(policy.value?.actions.reopen_job) && ['done', 'cancelled'].includes(job.status)
}

const activeTagCount = computed(() => activeTagFilters.value.length)

const toggleTagFilter = (tagName: string) => {
  if (activeTagFilters.value.includes(tagName)) {
    activeTagFilters.value = activeTagFilters.value.filter((item) => item !== tagName)
    return
  }

  activeTagFilters.value = [...activeTagFilters.value, tagName]
}

const clearTagFilters = () => {
  activeTagFilters.value = []
}

useHeader({
  title: domServisDispatchLabel,
  backUrl: '/',
  backAvoidHomeButton: true,
  actionTitle: __('Refresh'),
  onAction: refreshBoard,
})

onMounted(() => {
  loadBoard()
})
</script>

<template>
  <div class="flex h-full flex-col bg-black">
    <div class="border-b border-white/10 px-4 pt-3 pb-4">
      <div class="flex items-start justify-between gap-4">
        <div>
          <div class="text-xs font-semibold tracking-[0.22em] text-blue uppercase">
            {{ domServisDispatchLabel }}
          </div>
          <h1 class="mt-2 text-2xl font-bold text-white">
            {{ domServisDispatchTitle }}
          </h1>
          <p class="mt-2 text-sm leading-6 text-gray-100">
            {{ roleLabel }} работает в Дом-Сервис через мобильный интерфейс Zammad.
          </p>
        </div>
        <CommonLink :link="domServisDispatchDesktopPath" external class="text-sm font-medium text-blue">
          Расширенный режим
        </CommonLink>
      </div>

      <div class="mt-4 grid grid-cols-2 gap-3">
        <div
          v-for="card in stats"
          :key="card.label"
          class="rounded-2xl border border-white/10 bg-gray-500 px-3 py-3"
        >
          <div class="text-[11px] font-semibold tracking-[0.18em] text-gray-100 uppercase">
            {{ card.label }}
          </div>
          <div class="mt-2 text-3xl font-bold text-white">
            {{ card.value }}
          </div>
        </div>
      </div>
    </div>

    <CommonLoader v-if="loading" class="flex-1" loading />

    <template v-else>
      <div class="border-b border-white/10 px-4 py-3">
        <div class="flex gap-2 overflow-x-auto pb-1">
          <button
            v-for="filter in filterOptions"
            :key="filter.key"
            type="button"
            class="shrink-0 rounded-full border px-4 py-2 text-sm font-semibold transition"
            :class="
              selectedFilter === filter.key
                ? 'border-blue bg-blue text-black'
                : 'border-white/10 bg-gray-500 text-white'
            "
            @click="selectedFilter = filter.key"
          >
            {{ filter.label }} · {{ filter.count }}
          </button>
        </div>

        <div v-if="tags.length" class="mt-3">
          <div class="mb-2 flex items-center justify-between text-xs font-semibold tracking-[0.18em] text-gray-100 uppercase">
            <span>Теги</span>
            <button
              v-if="activeTagCount"
              type="button"
              class="text-blue"
              @click="clearTagFilters"
            >
              Сбросить
            </button>
          </div>
          <div class="flex gap-2 overflow-x-auto pb-1">
            <button
              v-for="tag in tags"
              :key="tag.id"
              type="button"
              class="shrink-0 rounded-full border px-3 py-1.5 text-sm"
              :class="
                activeTagFilters.includes(tag.name)
                  ? 'border-blue bg-blue/15 text-blue'
                  : 'border-white/10 bg-gray-500 text-white'
              "
              @click="toggleTagFilter(tag.name)"
            >
              {{ tag.name }}
            </button>
          </div>
        </div>
      </div>

      <div class="flex min-h-0 flex-1 flex-col">
        <div class="flex-1 overflow-y-auto px-4 py-4">
          <div v-if="!filteredJobs.length" class="rounded-2xl border border-white/10 bg-gray-500 px-4 py-5 text-sm text-gray-100">
            По текущим фильтрам заявок не найдено. Смените фильтр или обновите экран.
          </div>

          <div v-else class="space-y-3">
            <button
              v-for="job in filteredJobs"
              :key="job.id"
              type="button"
              class="w-full rounded-2xl border p-4 text-left transition"
              :class="
                selectedJobId === job.id
                  ? 'border-blue bg-blue/10'
                  : 'border-white/10 bg-gray-500'
              "
              @click="selectedJobId = job.id"
            >
              <div class="flex items-start justify-between gap-3">
                <div>
                  <div class="text-xs font-semibold tracking-[0.18em] text-gray-100 uppercase">
                    {{ job.job_code }}
                  </div>
                  <div class="mt-1 text-lg font-bold text-white">
                    {{ job.service_type }}
                  </div>
                </div>
                <div class="rounded-full border border-white/10 px-3 py-1 text-xs font-semibold text-blue">
                  {{ statusLabel(job.status) }}
                </div>
              </div>
              <div class="mt-3 text-sm leading-6 text-gray-100">
                {{ job.address }}
              </div>
              <div class="mt-2 text-sm text-gray-100">
                {{ formatSchedule(job) }}
              </div>
              <div class="mt-2 flex flex-wrap gap-2 text-xs text-gray-100">
                <span v-if="job.assignee" class="rounded-full bg-black/35 px-2.5 py-1">
                  {{ isMine(job) ? 'Моя заявка' : `Исполнитель: ${job.assignee}` }}
                </span>
                <span class="rounded-full bg-black/35 px-2.5 py-1">
                  {{ priorityLabel(job.priority) }}
                </span>
                <span
                  v-for="tag in job.work_tags"
                  :key="`${job.id}-${tag}`"
                  class="rounded-full bg-black/35 px-2.5 py-1"
                >
                  {{ tag }}
                </span>
              </div>
            </button>
          </div>
        </div>

        <div
          v-if="selectedJob"
          class="border-t border-white/10 bg-black px-4 pt-4 pb-[calc(var(--safe-bottom,0)+5rem)]"
        >
          <div class="rounded-[28px] border border-white/10 bg-gray-500 p-4">
            <div class="flex items-start justify-between gap-3">
              <div>
                <div class="text-xs font-semibold tracking-[0.18em] text-gray-100 uppercase">
                  {{ selectedJob.job_code }}
                </div>
                <div class="mt-1 text-xl font-bold text-white">
                  {{ selectedJob.service_type }}
                </div>
              </div>
              <button type="button" class="text-sm font-medium text-blue" @click="selectedJobId = null">
                Закрыть
              </button>
            </div>

            <dl class="mt-4 space-y-3 text-sm">
              <div>
                <dt class="text-xs font-semibold tracking-[0.18em] text-gray-100 uppercase">Адрес</dt>
                <dd class="mt-1 text-white">{{ selectedJob.address }}</dd>
              </div>
              <div v-if="selectedJob.client_name || selectedJob.client_phone">
                <dt class="text-xs font-semibold tracking-[0.18em] text-gray-100 uppercase">Клиент</dt>
                <dd class="mt-1 text-white">
                  {{ selectedJob.client_name || 'Не указан' }}
                  <span v-if="selectedJob.client_phone"> · {{ selectedJob.client_phone }}</span>
                </dd>
              </div>
              <div>
                <dt class="text-xs font-semibold tracking-[0.18em] text-gray-100 uppercase">График</dt>
                <dd class="mt-1 text-white">{{ formatSchedule(selectedJob) }}</dd>
              </div>
              <div>
                <dt class="text-xs font-semibold tracking-[0.18em] text-gray-100 uppercase">Статус</dt>
                <dd class="mt-1 text-white">{{ statusLabel(selectedJob.status) }}</dd>
              </div>
              <div>
                <dt class="text-xs font-semibold tracking-[0.18em] text-gray-100 uppercase">Приоритет</dt>
                <dd class="mt-1 text-white">{{ priorityLabel(selectedJob.priority) }}</dd>
              </div>
              <div v-if="selectedJob.assignee || selectedJob.organization">
                <dt class="text-xs font-semibold tracking-[0.18em] text-gray-100 uppercase">Назначение</dt>
                <dd class="mt-1 text-white">
                  {{ selectedJob.assignee || 'Исполнитель не назначен' }}
                  <span v-if="selectedJob.organization"> · {{ selectedJob.organization }}</span>
                </dd>
              </div>
              <div v-if="selectedJob.work_tags?.length">
                <dt class="text-xs font-semibold tracking-[0.18em] text-gray-100 uppercase">Теги</dt>
                <dd class="mt-2 flex flex-wrap gap-2">
                  <span
                    v-for="tag in selectedJob.work_tags"
                    :key="`${selectedJob.id}-detail-${tag}`"
                    class="rounded-full bg-black/35 px-2.5 py-1 text-xs text-white"
                  >
                    {{ tag }}
                  </span>
                </dd>
              </div>
              <div v-if="selectedJob.comment">
                <dt class="text-xs font-semibold tracking-[0.18em] text-gray-100 uppercase">Комментарий</dt>
                <dd class="mt-1 whitespace-pre-line text-white">{{ selectedJob.comment }}</dd>
              </div>
              <div v-if="selectedJob.description">
                <dt class="text-xs font-semibold tracking-[0.18em] text-gray-100 uppercase">Описание</dt>
                <dd class="mt-1 whitespace-pre-line text-white">{{ selectedJob.description }}</dd>
              </div>
            </dl>

            <div class="mt-5 grid grid-cols-2 gap-2">
              <button
                v-if="canTake(selectedJob)"
                type="button"
                class="rounded-2xl bg-blue px-4 py-3 text-sm font-semibold text-black disabled:opacity-60"
                :disabled="savingJobId === selectedJob.id"
                @click="takeJob(selectedJob)"
              >
                Взять
              </button>
              <button
                v-if="canRelease(selectedJob)"
                type="button"
                class="rounded-2xl border border-white/10 bg-black/35 px-4 py-3 text-sm font-semibold text-white disabled:opacity-60"
                :disabled="savingJobId === selectedJob.id"
                @click="releaseJob(selectedJob)"
              >
                В пул
              </button>
              <button
                v-if="canStart(selectedJob)"
                type="button"
                class="rounded-2xl bg-green px-4 py-3 text-sm font-semibold text-black disabled:opacity-60"
                :disabled="savingJobId === selectedJob.id"
                @click="setJobStatus(selectedJob, 'in_progress')"
              >
                В работу
              </button>
              <button
                v-if="canFinish(selectedJob)"
                type="button"
                class="rounded-2xl bg-yellow px-4 py-3 text-sm font-semibold text-black disabled:opacity-60"
                :disabled="savingJobId === selectedJob.id"
                @click="setJobStatus(selectedJob, 'done')"
              >
                Готово
              </button>
              <button
                v-if="canCancel(selectedJob)"
                type="button"
                class="rounded-2xl border border-red-bright/40 bg-red-bright/15 px-4 py-3 text-sm font-semibold text-red-bright disabled:opacity-60"
                :disabled="savingJobId === selectedJob.id"
                @click="setJobStatus(selectedJob, 'cancelled')"
              >
                Отменить
              </button>
              <button
                v-if="canReopen(selectedJob)"
                type="button"
                class="rounded-2xl border border-white/10 bg-black/35 px-4 py-3 text-sm font-semibold text-white disabled:opacity-60"
                :disabled="savingJobId === selectedJob.id"
                @click="setJobStatus(selectedJob, selectedJob.assignee_id ? 'taken' : 'pool')"
              >
                Вернуть
              </button>
            </div>
          </div>
        </div>
      </div>
    </template>
  </div>
</template>
