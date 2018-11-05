if (typeof window.$ == 'undefined' ) {
  var $ = window.jQuery
}

$(function() {
  $('[data-contact-form]').each(function(_, input) {
    var $form = $(input)

    function handleResponse(status, responseJSON) {
      if (responseJSON) {
        alert(responseJSON.message)
      } else {
        alert('Sorry, something went wrong.')
      }
      $('input:visible, textarea', $form).val('')
    }

    $form.on('ajax:success', function(event, data, status, xhr) {
      handleResponse(status, xhr.responseJSON)
    })

    $form.on('ajax:error', function(event, xhr, status) {
      handleResponse(status, xhr.responseJSON)
    })
  })
})
