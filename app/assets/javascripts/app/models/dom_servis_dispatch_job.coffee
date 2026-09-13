class App.DomServisDispatchJob extends App.Model
  @configure 'DomServisDispatchJob', 'job_code', 'service_type', 'address', 'client_name', 'client_phone', 'visit_day', 'visit_date', 'visit_time', 'priority', 'status', 'source', 'request_source_id', 'request_source_label', 'request_source_partner_key', 'request_source_transport_kind', 'assignee_id', 'organization_id', 'description', 'comment', 'work_tags', 'published_at', 'taken_at', 'created_by_id', 'created_at', 'updated_by_id', 'updated_at'
  @extend Spine.Model.Ajax
  @url: @apiPath + '/dom_servis/dispatch/jobs'
  @configure_attributes = [
    { name: 'service_type', display: __('Service type'), tag: 'input', type: 'text', limit: 150, null: false }
    { name: 'address', display: __('Address'), tag: 'input', type: 'text', limit: 250, null: false }
    { name: 'client_name', display: __('Client name'), tag: 'input', type: 'text', limit: 150, null: true }
    { name: 'client_phone', display: __('Client phone'), tag: 'input', type: 'text', limit: 120, null: true }
    { name: 'visit_day', display: __('Visit weekday'), tag: 'select', null: false, translate: false, options: { mon: 'mon', tue: 'tue', wed: 'wed', thu: 'thu', fri: 'fri', sat: 'sat', sun: 'sun' }, default: 'mon' }
    { name: 'visit_date', display: __('Visit date'), tag: 'input', type: 'text', limit: 50, null: true }
    { name: 'visit_time', display: __('Visit time'), tag: 'input', type: 'text', limit: 50, null: true }
    { name: 'priority', display: __('Priority'), tag: 'select', null: false, translate: false, options: { low: 'low', medium: 'medium', high: 'high', critical: 'critical' }, default: 'medium' }
    { name: 'status', display: __('Status'), tag: 'select', null: false, translate: false, options: { pool: 'pool', taken: 'taken', in_progress: 'in_progress', done: 'done', cancelled: 'cancelled' }, default: 'pool' }
    { name: 'source', display: __('Source'), tag: 'select', null: false, translate: false, options: { manual: 'manual', form: 'form', email: 'email', webhook: 'webhook', ai: 'ai' }, default: 'manual' }
    { name: 'assignee_id', display: __('Assignee'), tag: 'select', multiple: false, null: true, relation: 'User' }
    { name: 'organization_id', display: __('Organization'), tag: 'select', multiple: false, null: true, relation: 'Organization' }
    { name: 'description', display: __('Description'), tag: 'textarea', rows: 5, limit: 5000, null: true }
    { name: 'comment', display: __('Comment'), tag: 'textarea', rows: 3, limit: 2000, null: true }
    { name: 'work_tags', display: __('Work tags'), tag: 'input', type: 'text', limit: 500, null: true }
    { name: 'published_at', display: __('Published'), tag: 'datetime', readonly: 1 }
    { name: 'taken_at', display: __('Taken'), tag: 'datetime', readonly: 1 }
    { name: 'created_by_id', display: __('Created by'), relation: 'User', readonly: 1 }
    { name: 'created_at', display: __('Created'), tag: 'datetime', readonly: 1 }
    { name: 'updated_by_id', display: __('Updated by'), relation: 'User', readonly: 1 }
    { name: 'updated_at', display: __('Updated'), tag: 'datetime', readonly: 1 }
  ]
  @configure_delete = true
  @configure_overview = [
    'job_code'
    'service_type'
    'address'
    'visit_day'
    'status'
    'priority'
    'assignee_id'
    'organization_id'
    'visit_date'
    'visit_time'
  ]

  uiUrl: =>
    "#manage/dom_servis_dispatch/id:#{@id}"
