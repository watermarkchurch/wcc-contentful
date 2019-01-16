if (typeof window.$ == 'undefined' ) {
  var $ = window.jQuery
}

$(function() {
  function warningAlert(message) {
    return '<div class="alert alert-warning alert-dismissible fade show">' +
      message +
      '<button type="button" class="close" data-dismiss="alert" aria-label="Close">' +
        '<span aria-hidden="true">&times;</span>' +
      '</button>' +
    '</div>'
  }

  function handleResponse($form, event, status, xhr) {
    // Handle backwards compat for [rails/jquery]-ujs ajax callbacks
    var json
    if (event.detail) {
      json = JSON.parse(event.detail[2].response)
      status = event.detail[1]
    } else {
      json = xhr.responseJSON
    }

    if (status == 'OK' || status == 'success') {
      $form.append(
        $('<span>').text(json.message).delay(2000).fadeOut(2000, function() { $(this).remove() })
      )
      $('input:visible, textarea', $form).val('')
    } else if (json.message) {
      $form.append(warningAlert(json.message))
    } else {
      alert('Sorry, something went wrong.')
    }
  }

  $('[data-contact-form]').each(function(_, input) {
    var $form = $(input)

    $form.on('ajax:success', function(event, data, status, xhr) {
      handleResponse($form, event, status, xhr)
    })

    $form.on('ajax:error', function(event, xhr, status) {
      handleResponse($form, event, status, xhr)
    })
  })
})
