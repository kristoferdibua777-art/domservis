// Dom-Servis master directions and areas on the board: pool jobs that fit
// the master get a mark.

function skillsBoard(profile) {
  const board = Object.create(App.DomServisDispatchBoard.prototype)
  Object.assign(board, {
    masterProfile: profile,
    availableTags: [
      { name: 'Газовый котёл', group: 'direction' },
      { name: 'Сантехника', group: 'direction' },
      { name: 'Гурьевск', group: 'area' },
      { name: 'Калининград', group: 'area' },
      { name: 'Засор', group: 'fault' },
    ],
  })
  return board
}

QUnit.test('a pool job fits the master by direction and area', assert => {
  const board = skillsBoard({ directions: ['Сантехника'], areas: ['Калининград'] })

  assert.true(board.jobFitsMaster({ work_tags: ['Сантехника', 'Засор', 'Калининград'] }))
  assert.true(board.jobFitsMaster({ work_tags: ['Сантехника'] }), 'a job without an area fits any area')
  assert.false(board.jobFitsMaster({ work_tags: ['Газовый котёл', 'Калининград'] }), 'another direction')
  assert.false(board.jobFitsMaster({ work_tags: ['Сантехника', 'Гурьевск'] }), 'another area')
})

QUnit.test('a master without directions and areas gets no marks', assert => {
  assert.false(skillsBoard({ directions: [], areas: [] }).jobFitsMaster({ work_tags: ['Сантехника'] }))
  assert.false(skillsBoard(null).jobFitsMaster({ work_tags: ['Сантехника'] }))
})
