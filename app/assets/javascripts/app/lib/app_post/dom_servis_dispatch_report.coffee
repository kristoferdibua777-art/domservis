# Master report calculator of the dispatch board (decision 2026-10-24). It
# shows the sums while the master fills the report; the server
# (DomServis::DispatchReport) calculates the same and its sums are the ones
# saved:
#
# - works and parts from the lines, the total is what the client pays;
# - the master gets his percent of the works plus the parts he bought;
# - the partner gets its percent of the works or of the total;
# - the company keeps the rest;
# - cash or a transfer to the master stays with him, so the settlement is
#   what the company still owes him (negative: what he hands over).
class App.DomServisDispatchReport
  @MASTER_PAYMENT_METHODS: ['cash', 'transfer_master']
  @NO_PAYMENT_METHODS: ['partner', 'unpaid']
  @EVIDENCE_KINDS: ['completion_act', 'diagnostic_photo']

  # Reads "1 500,50" as typed on a phone; anything else counts as 0.
  @number: (value) ->
    return value if _.isNumber(value) && !_.isNaN(value)

    text = "#{value ? ''}".replace(/[\s\u00A0]/g, '').replace(',', '.')
    parsed = parseFloat(text)
    if _.isNaN(parsed) then 0 else parsed

  @round: (value) ->
    Math.round(value * 100) / 100

  @lineAmount: (item) ->
    @round(@number(item?.quantity) * @number(item?.price))

  @sum: (items) ->
    @round(_.reduce(items, ((memo, item) => memo + @lineAmount(item)), 0))

  # rates: master_percent, partner_percent and partner_base as the server
  # sends them; a viewer without a share gets no rates and sees zeros there.
  @calculate: (draft, rates = {}) ->
    items = draft?.items || []
    works = @sum(_.filter(items, (item) -> item.kind isnt 'part'))
    parts = @sum(_.filter(items, (item) -> item.kind is 'part'))
    total = @round(works + parts)
    reimbursement = @sum(_.filter(items, (item) -> item.kind is 'part' && item.bought_by_master))
    masterPercent = @number(rates.master_percent)
    masterAmount = @round(works * masterPercent / 100)
    payout = @round(masterAmount + reimbursement)
    partnerPercent = @number(rates.partner_percent)
    partnerAmount = @round((if rates.partner_base is 'total' then total else works) * partnerPercent / 100)
    paid = @number(draft?.amount_paid)
    moneyAtMaster = if _.contains(@MASTER_PAYMENT_METHODS, draft?.payment_method) then paid else 0

    {
      works_total: works
      parts_total: parts
      total: total
      master_percent: masterPercent
      master_amount: masterAmount
      parts_reimbursement: reimbursement
      master_payout: payout
      partner_percent: partnerPercent
      partner_amount: partnerAmount
      company_amount: @round(total - partnerAmount - payout)
      money_at_master: moneyAtMaster
      master_settlement: @round(payout - moneyAtMaster)
    }

  # The same list as the server, for hints before saving.
  @missing: (draft, evidence) ->
    list = []
    items = draft?.items || []
    list.push('добавьте хотя бы одну работу или запчасть') if items.length < 1
    list.push('напишите, что сделано') if !"#{draft?.work_summary || ''}".trim()
    list.push('напишите рекомендации клиенту (если их нет — «нет»)') if !"#{draft?.recommendations || ''}".trim()
    list.push('укажите, как клиент заплатил') if !draft?.payment_method
    if draft?.payment_method && !_.contains(@NO_PAYMENT_METHODS, draft.payment_method) && @number(draft.amount_paid) <= 0
      list.push('укажите сумму, полученную от клиента')
    list.push('приложите фото результата или акт выполненных работ') if !evidence
    list

  @evidenceCount: (attachments) ->
    _.filter(attachments || [], (attachment) => _.contains(@EVIDENCE_KINDS, attachment.kind)).length

  # "1 500 ₽", "1 500,50 ₽"
  @money: (value) ->
    number = @round(@number(value))
    sign = if number < 0 then '−' else ''
    [whole, fraction] = Math.abs(number).toFixed(2).split('.')
    whole = whole.replace(/\B(?=(\d{3})+(?!\d))/g, ' ')
    text = if fraction is '00' then whole else "#{whole},#{fraction}"
    "#{sign}#{text} ₽"

  # A report line for the form: from a price list line or empty.
  @itemFromPrice: (priceItem) ->
    {
      price_item_id: priceItem.id
      kind: priceItem.kind
      name: priceItem.name
      quantity: 1
      unit: priceItem.unit || 'шт'
      list_price: priceItem.price
      price: priceItem.price
      bought_by_master: priceItem.kind is 'part'
    }

  @emptyItem: (kind) ->
    {
      price_item_id: null
      kind: kind
      name: ''
      quantity: 1
      unit: 'шт'
      list_price: null
      price: 0
      bought_by_master: kind is 'part'
    }

  # The price list for the "add" select: lines of the job's directions first,
  # then the general ones (no direction), then the rest.
  @priceGroups: (priceItems, jobTags) ->
    tags = jobTags || []
    own = _.filter(priceItems, (item) -> item.direction && _.contains(tags, item.direction))
    general = _.filter(priceItems, (item) -> !item.direction)
    rest = _.filter(priceItems, (item) -> item.direction && !_.contains(tags, item.direction))
    groups = []
    groups.push({ label: 'По этой заявке', items: own }) if own.length
    groups.push({ label: 'Общие', items: general }) if general.length
    _.each(_.groupBy(rest, 'direction'), (items, direction) -> groups.push({ label: direction, items: items }))
    groups
