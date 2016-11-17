u = up.util

up.compiler '.search', ($search) ->
  $input = $search.find('.search__input')
  $reset = $search.find('.search__reset')

  reset = ->
    $input.val('')
    $input.trigger('input')

  toggleReset = ->
    value = u.trim($input.val())
    present = u.isPresent(value)
    $reset.toggle(present)

  $input.on 'input', toggleReset

  $reset.on 'click', reset

  toggleReset()

  