<script setup>
import { computed, reactive } from 'vue'
import {
  ChevronLeft,
  ChevronRight,
  Menu,
  SlidersHorizontal,
  X,
} from 'lucide-vue-next'
import jobsSeed from './data/jobs.json'

const currentUser = {
  name: 'Master1 Master2626',
  role: 'Мастер',
  organization: 'Дом-Сервис',
  initials: 'MM',
}

const semanticField = [
  { label: 'ПУЛ', tone: 'blue', top: '8%', left: '8%' },
  { label: 'МАСТЕР', tone: 'ghost', top: '12%', left: '74%' },
  { label: 'ПОДЪЕЗД', tone: 'ghost', top: '22%', left: '18%' },
  { label: 'ОБЪЕКТ', tone: 'ghost', top: '28%', left: '68%' },
  { label: 'ВЫЕЗД', tone: 'blue', top: '42%', left: '76%' },
  { label: 'СМЕНА', tone: 'ghost', top: '52%', left: '12%' },
  { label: 'ДОМОФОН', tone: 'violet', top: '63%', left: '66%' },
  { label: 'ШЛАГБАУМ', tone: 'ghost', top: '73%', left: '14%' },
  { label: 'ТЕГ', tone: 'blue', top: '84%', left: '78%' },
]

const today = new Date('2026-04-10T09:00:00')

function parseIsoDate(value) {
  return new Date(`${value}T00:00:00`)
}

function formatIso(date) {
  const year = date.getFullYear()
  const month = `${date.getMonth() + 1}`.padStart(2, '0')
  const day = `${date.getDate()}`.padStart(2, '0')
  return `${year}-${month}-${day}`
}

function startOfWeek(date) {
  const next = new Date(date)
  const day = next.getDay()
  const diff = day === 0 ? -6 : 1 - day
  next.setDate(next.getDate() + diff)
  next.setHours(0, 0, 0, 0)
  return next
}

function addDays(date, amount) {
  const next = new Date(date)
  next.setDate(next.getDate() + amount)
  return next
}

function sameIsoDate(a, b) {
  return formatIso(a) === formatIso(b)
}

function formatDayLabel(value) {
  return new Intl.DateTimeFormat('ru-RU', { weekday: 'short' })
    .format(parseIsoDate(value))
    .replace('.', '')
}

function formatWeekRange(startValue) {
  const start = parseIsoDate(startValue)
  const end = addDays(start, 6)
  const dayMonth = new Intl.DateTimeFormat('ru-RU', { day: '2-digit', month: '2-digit' })
  return `${dayMonth.format(start)} - ${dayMonth.format(end)}`
}

const state = reactive({
  jobs: jobsSeed.map((job) => ({ ...job })),
  workspace: 'pool',
  day: 'all',
  tag: 'all',
  selectedWeekStart: formatIso(startOfWeek(today)),
  filterPanelOpen: false,
  accountMenuOpen: false,
  selectedJobId: null,
})

const workspaceOptions = [
  { id: 'mine', label: 'Мои' },
  { id: 'pool', label: 'Пул' },
  { id: 'active', label: 'В работе' },
  { id: 'done', label: 'Готово' },
]

const allTags = computed(() => {
  const tags = new Set()
  state.jobs.forEach((job) => job.tags.forEach((tag) => tags.add(tag)))
  return ['all', ...Array.from(tags)]
})

function matchesWorkspace(job, workspaceId) {
  if (workspaceId === 'mine') return job.assigneeName === currentUser.name && job.status !== 'done'
  if (workspaceId === 'pool') return job.status === 'pool'
  if (workspaceId === 'active') return job.status === 'active'
  if (workspaceId === 'done') return job.status === 'done'
  return true
}

function matchesTag(job) {
  return state.tag === 'all' || job.tags.includes(state.tag)
}

function matchesWeek(job, weekStartValue) {
  const weekStart = parseIsoDate(weekStartValue)
  const jobDate = parseIsoDate(job.scheduledDate)
  const weekEnd = addDays(weekStart, 6)
  return jobDate >= weekStart && jobDate <= weekEnd
}

const workspaceCount = (workspaceId) =>
  state.jobs.filter((job) => matchesWorkspace(job, workspaceId)).length

const currentWeekJobs = computed(() =>
  state.jobs.filter(
    (job) => matchesWorkspace(job, state.workspace) && matchesTag(job) && matchesWeek(job, state.selectedWeekStart),
  ),
)

const filteredJobs = computed(() =>
  currentWeekJobs.value.filter((job) => {
    if (state.day === 'all') return true
    return job.scheduledDate === state.day
  }),
)

const selectedJob = computed(() => state.jobs.find((job) => job.id === state.selectedJobId) || null)

const weekDays = computed(() => {
  const weekStart = parseIsoDate(state.selectedWeekStart)
  const items = []

  for (let index = 0; index < 7; index += 1) {
    const date = addDays(weekStart, index)
    const iso = formatIso(date)
    const count = currentWeekJobs.value.filter((job) => job.scheduledDate === iso).length
    items.push({
      id: iso,
      shortLabel: formatDayLabel(iso),
      dateNumber: iso.slice(8, 10),
      count,
      hasLoad: count > 0,
      active: state.day === iso,
      isToday: sameIsoDate(date, today),
    })
  }

  return items
})

const boardSummary = computed(() => {
  const active = workspaceCount('active')
  const pool = workspaceCount('pool')
  return `${active} в работе • ${pool} в пуле`
})

const queueTitle = computed(() => {
  const map = {
    mine: 'Мои заявки',
    pool: 'Заявки из пула',
    active: 'Заявки в работе',
    done: 'Завершённые заявки',
  }
  return map[state.workspace]
})

const activeTagLabel = computed(() => (state.tag === 'all' ? 'Все теги' : state.tag))

const masterStats = computed(() => ({
  active: state.jobs.filter((job) => job.status === 'active' && job.assigneeName === currentUser.name).length,
  mine: state.jobs.filter((job) => job.assigneeName === currentUser.name && job.status !== 'done').length,
  done: state.jobs.filter((job) => job.status === 'done' && job.assigneeName === currentUser.name).length,
}))

function setWorkspace(workspaceId) {
  state.workspace = workspaceId
  state.selectedJobId = null
}

function openJob(jobId) {
  state.selectedJobId = jobId
}

function closeDrawer() {
  state.selectedJobId = null
}

function shiftWeek(offset) {
  const next = addDays(parseIsoDate(state.selectedWeekStart), offset * 7)
  state.selectedWeekStart = formatIso(next)
  if (state.day !== 'all' && !weekDays.value.some((item) => item.id === state.day)) {
    state.day = 'all'
  }
}

function resetWeek() {
  state.selectedWeekStart = formatIso(startOfWeek(today))
  if (state.day !== 'all' && !weekDays.value.some((item) => item.id === state.day)) {
    state.day = 'all'
  }
}

function applyAction(job, action) {
  if (action === 'take') {
    job.status = 'mine'
    job.statusLabel = 'Моя'
    job.assigneeName = currentUser.name
    job.actions = ['start', 'release']
    state.workspace = 'mine'
  }

  if (action === 'start') {
    job.status = 'active'
    job.statusLabel = 'В работе'
    job.actions = ['done', 'release']
    state.workspace = 'active'
  }

  if (action === 'done') {
    job.status = 'done'
    job.statusLabel = 'Готово'
    job.actions = []
    state.workspace = 'done'
  }

  if (action === 'release') {
    job.status = 'pool'
    job.statusLabel = 'В пуле'
    job.assigneeName = null
    job.actions = ['take']
    state.workspace = 'pool'
  }

  state.selectedJobId = job.id
}

function actionLabel(action) {
  return {
    take: 'Взять',
    start: 'В работу',
    done: 'Готово',
    release: 'В пул',
  }[action]
}

setWorkspace(state.workspace)
</script>

<template>
  <div class="sandbox-page">
    <div class="sandbox-phone-frame">
      <main class="dom-servis-dispatch-board">
        <div class="dom-servis-dispatch-board__atmosphere" aria-hidden="true">
          <div class="dom-servis-dispatch-board__glow dom-servis-dispatch-board__glow--violet"></div>
          <div class="dom-servis-dispatch-board__glow dom-servis-dispatch-board__glow--amber"></div>
          <div class="dom-servis-dispatch-board__glow dom-servis-dispatch-board__glow--emerald"></div>
          <div class="dom-servis-dispatch-board__gridline"></div>
          <div class="dom-servis-dispatch-board__semantic-field">
            <span
              v-for="item in semanticField"
              :key="`${item.label}-${item.top}-${item.left}`"
              class="dom-servis-dispatch-board__semantic-token"
              :class="`is-${item.tone}`"
              :style="{ top: item.top, left: item.left }"
            >
              {{ item.label }}
            </span>
          </div>
        </div>

        <section class="dom-servis-dispatch-board__shell is-mobile">
          <header class="dom-servis-dispatch-board__mobile-topbar">
            <div class="dom-servis-dispatch-board__mobile-brand">
              <div class="dom-servis-dispatch-board__eyebrow">Дом-Сервис</div>
              <strong>Dispatch</strong>
              <span class="dom-servis-dispatch-board__brand-note">Выездная доска мастера</span>
            </div>

            <div class="dom-servis-dispatch-board__mobile-topbar-actions">
              <div class="dom-servis-dispatch-board__mobile-role">
                <span class="dom-servis-dispatch-board__presence-dot"></span>
                {{ currentUser.role }}
              </div>
              <button class="dom-servis-dispatch-icon-button" @click="state.accountMenuOpen = true">
                <Menu :size="19" :stroke-width="2.1" />
              </button>
            </div>
          </header>

          <section class="dom-servis-dispatch-board__mobile-stage">
            <svg class="dom-servis-dispatch-board__panel-ornament dom-servis-dispatch-board__panel-ornament--stage" viewBox="0 0 360 180" aria-hidden="true">
              <circle cx="300" cy="26" r="74"></circle>
              <path d="M32 132C84 92 126 80 180 80S276 94 330 132"></path>
              <path d="M18 148H134"></path>
              <path d="M226 32H342"></path>
            </svg>
            <div class="dom-servis-dispatch-board__mobile-stage-copy">
              <div class="dom-servis-dispatch-board__mobile-stage-eyebrow">Рабочий режим</div>
              <h1>{{ queueTitle }}</h1>
              <p>{{ boardSummary }}</p>
            </div>

            <div class="dom-servis-dispatch-board__mobile-segments">
              <button
                v-for="item in workspaceOptions"
                :key="item.id"
                class="dom-servis-dispatch-segment"
                :class="{ 'is-active': state.workspace === item.id }"
                @click="setWorkspace(item.id)"
              >
                <span class="dom-servis-dispatch-segment__label">{{ item.label }}</span>
                <strong>{{ workspaceCount(item.id) }}</strong>
              </button>
            </div>
          </section>

          <section class="dom-servis-dispatch-board__week-panel">
            <svg class="dom-servis-dispatch-board__panel-ornament dom-servis-dispatch-board__panel-ornament--week" viewBox="0 0 360 220" aria-hidden="true">
              <circle cx="252" cy="114" r="84"></circle>
              <circle cx="252" cy="114" r="112"></circle>
              <path d="M12 34H184"></path>
              <path d="M210 188H344"></path>
              <path d="M48 80C120 62 198 62 312 92"></path>
            </svg>
            <div class="dom-servis-dispatch-board__week-head">
              <div>
                <div class="dom-servis-dispatch-board__mobile-queue-label">Неделя</div>
                <strong>{{ formatWeekRange(state.selectedWeekStart) }}</strong>
              </div>

              <div class="dom-servis-dispatch-board__week-actions">
                <button class="dom-servis-dispatch-week-button" @click="shiftWeek(-1)">
                  <ChevronLeft :size="18" :stroke-width="2.25" />
                </button>
                <button class="dom-servis-dispatch-week-button dom-servis-dispatch-week-button--wide" @click="resetWeek">
                  Текущая
                </button>
                <button class="dom-servis-dispatch-week-button" @click="shiftWeek(1)">
                  <ChevronRight :size="18" :stroke-width="2.25" />
                </button>
              </div>
            </div>

            <div class="dom-servis-dispatch-board__day-grid">
              <button
                class="dom-servis-dispatch-day-card"
                :class="{ 'is-active': state.day === 'all' }"
                @click="state.day = 'all'"
              >
                <span class="dom-servis-dispatch-day-card__label">Все</span>
                <strong class="dom-servis-dispatch-day-card__count">{{ currentWeekJobs.length }}</strong>
              </button>

              <button
                v-for="item in weekDays"
                :key="item.id"
                class="dom-servis-dispatch-day-card"
                :class="{ 'is-active': item.active, 'is-today': item.isToday, 'has-load': item.hasLoad }"
                @click="state.day = item.id"
              >
                <span class="dom-servis-dispatch-day-card__label">{{ item.shortLabel }}</span>
                <strong class="dom-servis-dispatch-day-card__count">{{ item.count }}</strong>
                <em class="dom-servis-dispatch-day-card__date">{{ item.dateNumber }}</em>
              </button>
            </div>

            <div class="dom-servis-dispatch-board__toolbar">
              <button class="dom-servis-dispatch-chip dom-servis-dispatch-chip--primary" @click="state.filterPanelOpen = true">
                <SlidersHorizontal :size="15" :stroke-width="2.25" />
                Фильтры
              </button>
              <div class="dom-servis-dispatch-chip dom-servis-dispatch-chip--quiet">{{ activeTagLabel }}</div>
            </div>
          </section>

          <section class="dom-servis-dispatch-board__list">
            <article
              v-for="job in filteredJobs"
              :key="job.id"
              class="dom-servis-dispatch-card"
              :class="[`dom-servis-dispatch-card--${job.status}`, { 'is-selected': selectedJob?.id === job.id }]"
              @click="openJob(job.id)"
            >
              <div class="dom-servis-dispatch-card__row dom-servis-dispatch-card__row--top">
                <div class="dom-servis-dispatch-card__schedule">{{ job.scheduleLabel }}</div>
                <span class="dom-servis-dispatch-card__status" :class="`dom-servis-dispatch-card__status--${job.status}`">
                  {{ job.statusLabel }}
                </span>
              </div>

              <div class="dom-servis-dispatch-card__address">{{ job.address }}</div>
              <div class="dom-servis-dispatch-card__service">{{ job.serviceType }}</div>

              <div class="dom-servis-dispatch-card__meta">
                <span>{{ job.clientName }}</span>
                <span>{{ job.clientPhone }}</span>
              </div>

              <div class="dom-servis-dispatch-card__footer">
                <div class="dom-servis-dispatch-card__footer-left">
                  <span class="dom-servis-dispatch-card__priority" :class="`dom-servis-dispatch-card__priority--${job.priority}`">
                    {{ job.priorityLabel }}
                  </span>
                  <span class="dom-servis-dispatch-card__code">{{ job.jobCode }}</span>
                </div>

                <button
                  v-if="job.actions[0]"
                  class="dom-servis-dispatch-card__action"
                  :class="`dom-servis-dispatch-card__action--${job.actions[0]}`"
                  @click.stop="applyAction(job, job.actions[0])"
                >
                  {{ actionLabel(job.actions[0]) }}
                </button>
              </div>
            </article>

            <div v-if="filteredJobs.length === 0" class="dom-servis-dispatch-board__empty">
              <strong>По текущему срезу заявок нет.</strong>
              <span>Смени неделю, день или фильтр.</span>
            </div>
          </section>
        </section>

        <div v-if="state.filterPanelOpen" class="dom-servis-overlay" @click.self="state.filterPanelOpen = false">
          <section class="dom-servis-sheet">
            <div class="dom-servis-sheet__head">
              <strong>Фильтры мастера</strong>
              <button class="dom-servis-dispatch-icon-button" @click="state.filterPanelOpen = false">
                <X :size="18" :stroke-width="2.2" />
              </button>
            </div>

            <div class="dom-servis-sheet__group">
              <div class="dom-servis-sheet__label">Неделя</div>
              <div class="dom-servis-sheet__chips">
                <button class="dom-servis-dispatch-chip" @click="shiftWeek(-1)">Предыдущая</button>
                <button class="dom-servis-dispatch-chip" @click="resetWeek">Текущая</button>
                <button class="dom-servis-dispatch-chip" @click="shiftWeek(1)">Следующая</button>
              </div>
            </div>

            <div class="dom-servis-sheet__group">
              <div class="dom-servis-sheet__label">Теги</div>
              <div class="dom-servis-sheet__chips">
                <button
                  v-for="item in allTags"
                  :key="item"
                  class="dom-servis-dispatch-chip"
                  :class="{ 'is-active': state.tag === item }"
                  @click="state.tag = item"
                >
                  {{ item === 'all' ? 'Все теги' : item }}
                </button>
              </div>
            </div>
          </section>
        </div>

        <div v-if="state.accountMenuOpen" class="dom-servis-overlay" @click.self="state.accountMenuOpen = false">
          <section class="dom-servis-sheet dom-servis-sheet--menu">
            <div class="dom-servis-sheet__profile">
              <div class="dom-servis-dispatch-board__user-avatar">{{ currentUser.initials }}</div>
              <div>
                <strong>{{ currentUser.name }}</strong>
                <span>{{ currentUser.organization }}</span>
              </div>
            </div>

            <div class="dom-servis-sheet__stats">
              <div class="dom-servis-sheet__stats-item">
                <span>Мои активные</span>
                <strong>{{ masterStats.mine }}</strong>
              </div>
              <div class="dom-servis-sheet__stats-item">
                <span>В работе</span>
                <strong>{{ masterStats.active }}</strong>
              </div>
              <div class="dom-servis-sheet__stats-item">
                <span>Готово</span>
                <strong>{{ masterStats.done }}</strong>
              </div>
            </div>

            <button class="dom-servis-menu-button">Профиль</button>
            <button class="dom-servis-menu-button">Главная Zammad</button>
            <button class="dom-servis-menu-button dom-servis-menu-button--danger">Выход</button>
          </section>
        </div>

        <div v-if="selectedJob" class="dom-servis-overlay dom-servis-overlay--drawer" @click.self="closeDrawer">
          <aside class="dom-servis-drawer">
            <div class="dom-servis-drawer__head">
              <div>
                <div class="dom-servis-dispatch-board__eyebrow">Заявка {{ selectedJob.jobCode }}</div>
                <h2>{{ selectedJob.address }}</h2>
                <p>{{ selectedJob.serviceType }}</p>
              </div>
              <button class="dom-servis-dispatch-icon-button" @click="closeDrawer">
                <X :size="18" :stroke-width="2.2" />
              </button>
            </div>

            <div class="dom-servis-drawer__meta">
              <div>
                <span>Когда</span>
                <strong>{{ selectedJob.scheduleLabel }}</strong>
              </div>
              <div>
                <span>Клиент</span>
                <strong>{{ selectedJob.clientName }}</strong>
              </div>
              <div>
                <span>Телефон</span>
                <strong>{{ selectedJob.clientPhone }}</strong>
              </div>
              <div>
                <span>Организация</span>
                <strong>{{ selectedJob.organizationName }}</strong>
              </div>
            </div>

            <div class="dom-servis-drawer__section">
              <span class="dom-servis-drawer__label">Комментарий</span>
              <p>{{ selectedJob.comment }}</p>
            </div>

            <div class="dom-servis-drawer__section">
              <span class="dom-servis-drawer__label">Описание</span>
              <p>{{ selectedJob.description }}</p>
            </div>

            <div class="dom-servis-drawer__section">
              <span class="dom-servis-drawer__label">Теги</span>
              <div class="dom-servis-sheet__chips">
                <span v-for="tag in selectedJob.tags" :key="tag" class="dom-servis-dispatch-chip">
                  {{ tag }}
                </span>
              </div>
            </div>

            <div v-if="selectedJob.actions.length" class="dom-servis-drawer__actions">
              <button
                v-for="action in selectedJob.actions"
                :key="action"
                class="dom-servis-dispatch-card__action"
                :class="`dom-servis-dispatch-card__action--${action}`"
                @click="applyAction(selectedJob, action)"
              >
                {{ actionLabel(action) }}
              </button>
            </div>
          </aside>
        </div>
      </main>
    </div>
  </div>
</template>
