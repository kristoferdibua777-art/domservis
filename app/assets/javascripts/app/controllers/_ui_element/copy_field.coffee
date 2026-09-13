class App.UiElement.copy_field
  @render: (attribute) ->
    $(App.view('generic/copy_field')(attribute: attribute))
