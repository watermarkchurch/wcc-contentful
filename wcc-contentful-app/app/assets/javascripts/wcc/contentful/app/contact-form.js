if (typeof window.$ == 'undefined' ) {
  var $ = window.jQuery
}

$(function() {
  function warningAlert(message) {
    var div = $('<div>')
      .addClass('alert alert-danger alert-dismissible fade show')
      .text(message)

    return div.append(
      '<button type="button" class="close" data-dismiss="alert" aria-label="Close">' +
        '<span aria-hidden="true">&times;</span>' +
      '</button>'
    )
  }

  function handleResponse($form, event, status, xhr) {
    // Handle backwards compat for [rails/jquery]-ujs ajax callbacks
    var json
    try {
      if (event.detail) {
        json = JSON.parse(event.detail[2].response)
        status = event.detail[1]
      } else {
        json = xhr.responseJSON
      }
    } catch(ex) {
      status = 'error'
      json = {}
    }

    if (status == 'OK' || status == 'success') {
      $form.append(
        $('<span>').text(json.message).delay(2000).fadeOut(2000, function() { $(this).remove() })
      )
      $('input:visible, textarea', $form).val('')
      $('.alert', $form).remove()
      if (typeof window.grecaptcha != 'undefined') {
        window.grecaptcha.reset()
      }
    } else if (json.message) {
      $form.append(warningAlert(json.message))
    } else {
      $form.append(warningAlert('Sorry, something went wrong.'))
    }
  }

  $('[data-contact-form]').each(function(_, input) {
    var $form = $(input)

    $form.on('ajax:success', function(event, data, status, xhr) {
      try {
        handleResponse($form, event, status, xhr)
      } catch(ex) {
        alert('Sorry, something went wrong.')
        throw ex
      }
    })

    $form.on('ajax:error', function(event, xhr, status) {
      try {
        handleResponse($form, event, status, xhr)
      } catch(ex) {
        alert('Sorry, something went wrong.')
        throw ex
      }
    })
  })
})
