const user = (id, first, last, perms) => ({ id, firstname: first, lastname: last, email: `${first}@dom-servis.ru`, phone: '+7 911 000-00-00', active: true,
  organization: { name: 'СВИБ Дом Сервис' },
  displayName() { return `${first} ${last}` }, initials() { return first[0] + last[0] },
  permission(p) { return perms.includes(p) } })
const ROLE = new URLSearchParams(location.search).get('role') || 'master'
const USERS = { 5: user(5, 'Иван', 'Мастеров', ['dom_servis.master']), 6: user(6, 'Пётр', 'Слесарев', ['dom_servis.master']),
  1: user(1, 'Анна', 'Диспетчерова', ['dom_servis.dispatcher']) }
const CURRENT = ROLE === 'master' ? USERS[5] : USERS[1]
window.App = {
  Config: { get() { return null }, set() {} },
  Controller: function () {}, ControllerPermanent: function () {},
  User: { current: () => CURRENT, all: () => Object.values(USERS), exists: (id) => !!USERS[id], find: (id) => USERS[id], findNative: (id) => USERS[id] },
  Ajax: { token: () => '' }, Toast: { create() {} }, TaskManager: { execute() {} },
  MobileDetection: { desktop: () => false, desktopShellRequiredForHash: () => true },
  DomServisDispatchJob: { find() { return null }, select() { return [] } },
  view: (name) => (params) => window.JST[name](params),
}
