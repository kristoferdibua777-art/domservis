(function () {
  const q = new URLSearchParams(location.search)
  const pad = (n) => String(n).padStart(2, '0')
  const day = (offset) => { const d = new Date(); d.setDate(d.getDate() + offset); return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}` }
  const jobs = [
    { id: 101, ticket_id: 9001, ticket_number: '71001', status: 'pool', priority: 'critical', service_type: 'Ремонт стиральной машины', client_name: 'Екатерина Константиновна Длиннофамильная-Переславская', client_phone: '+7 (911) 123-45-67', address: 'Калининград, Ленинский проспект, д. 131, корп. 2, подъезд 4, кв. 287, домофон 287В', visit_date: day(0), visit_time: '09:00-11:30', description: 'Не сливает воду, ошибка E21, стучит барабан при отжиме. Клиент просит позвонить за час до приезда, в подъезде нет лифта.', comment: 'Код домофона 287В', work_tags: ['Стиральные машины', 'Срочно'], source: 'form', created_at: '2026-10-06T08:00:00Z' },
    { id: 102, ticket_id: 9002, ticket_number: '71002', status: 'taken', priority: 'high', assignee_id: 5, service_type: 'Холодильник', client_name: 'Олег', client_phone: '+79110000000', address: 'ул. Горького, 55', visit_date: day(0), visit_time: '14:00', description: 'Не морозит морозильная камера', work_tags: ['Холодильники'], source: 'manual', created_at: '2026-10-06T09:00:00Z' },
    { id: 103, status: 'in_progress', priority: 'medium', assignee_id: 5, service_type: 'Посудомоечная машина Bosch SMV4HVX31E/38', client_name: 'Мария', client_phone: '+79112223344', address: 'Зеленоградск, ул. Курортная, 12', visit_date: day(1), visit_time: 'после обеда', description: 'Течёт снизу', work_tags: [], source: 'partner', created_at: '2026-10-06T10:00:00Z' },
    { id: 104, status: 'pool', priority: 'low', service_type: 'Духовой шкаф', client_name: 'ТСЖ «Балтийская Ривьера»', client_phone: '+74012000000', address: 'Светлогорск, Калининградский пр-т, 79А', visit_date: day(2), visit_time: '', description: '', work_tags: [], source: 'manual', created_at: '2026-10-06T11:00:00Z' },
    { id: 105, status: 'done', priority: 'medium', assignee_id: 6, service_type: 'Варочная панель', client_name: 'Игорь', client_phone: '+79113334455', address: 'ул. Багратиона, 100', visit_date: day(-1), visit_time: '10:00', description: 'Не греет конфорка', work_tags: [], source: 'manual', created_at: '2026-10-05T10:00:00Z' },
  ]
  const role = q.get('role') || 'master'
  const perms = { master: ['dom_servis.master'], dispatcher: ['dom_servis.dispatcher'], admin: ['dom_servis.admin'] }[role]
  const el = $('.dom-servis-dispatch-board')
  const b = Object.create(App.DomServisDispatchBoard.prototype)
  Object.assign(b, {
    el, html: (h) => el.html(h), $: (s) => el.find(s), permissionCheck: (p) => perms.includes(p),
    preventDefaultAndStopPropagation: (e) => { if (e) { e.preventDefault(); e.stopPropagation() } },
    title() {}, navupdate() {}, ajax() {}, delay() {},
    statusFilter: 'open', dayFilter: 'all', viewMode: 'board', calendarDate: null, calendarJobs: {},
    effectivePolicy: null, policyRegistry: {}, availableTags: [{ name: 'Стиральные машины', dispatch_count: 3 }, { name: 'Холодильники', dispatch_count: 1 }, { name: 'Срочно', dispatch_count: 2 }],
    activeTagFilters: [], loading: false, errorMessage: null, createOpen: false, editOpen: false, editingJobId: null,
    editSaving: false, detailOpen: false, detailJobId: null, organizations: [{ id: 7, name: 'Управляющая компания «Дом»' }], organizationsLoaded: true,
    attachmentCollections: {}, attachmentLoading: {}, attachmentUploading: {}, eventCollections: {},
    createDraft: {}, createAttachmentFiles: [], createAttachmentUploading: false, createAttachmentKind: 'intake_attachment',
    mobileWorkspaceMenuOpen: false, pushSubscribing: false, pushTesting: false, pushEnabled: false,
  })
  b.vapidPublicKey = () => 'BKEY'
  b.mobileView = window.matchMedia('(max-width: 767px)').matches
  b.selectedWeekStart = b.startOfWeek(new Date())
  if (b.mobileView && role === 'master') b.statusFilter = 'mine'
  b.resetCreateDraft()
  b.jobs = b.sortJobs(jobs)
  const screen = q.get('screen') || 'board'
  if (screen === 'create') b.createOpen = true
  if (screen === 'detail') { b.detailOpen = true; b.detailJobId = 101; b.statusFilter = 'open'; b.eventCollections['101'] = [] }
  if (screen === 'menu') b.mobileWorkspaceMenuOpen = true
  if (screen === 'pool') b.statusFilter = 'pool'
  b.currentDetailJob = function () { return _.find(this.jobs, (j) => j.id === this.detailJobId) || null }
  try { b.render(); b.delegateEvents && 0; window.__ok = true } catch (e) { window.__err = e.stack; document.body.insertAdjacentHTML('afterbegin', `<pre id="err">${e.stack}</pre>`) }
  window.board = b
})()
