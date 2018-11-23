u = up.util

up.compiler '.search', ($search) ->
  $input = $search.find('.search__input')
  $reset = $search.find('.search__reset')

  reset = ->
    $input.val('')
    $input.trigger('input')

  toggleReset = ->
    value = $input.val().trim()
    present = u.isPresent(value)
    $reset.toggle(present)

  $input.on 'input', toggleReset

  $reset.on 'click', reset

  toggleReset()

  