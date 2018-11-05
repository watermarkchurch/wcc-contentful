if (typeof window.$ == 'undefined' ) {
  var $ = window.jQuery
}

$(function() {
  $('[data-contact-form]').each(function(_, input) {
    var $form = $(input)

    function handleResponse(event, status, xhr) {
      // Handle backwards compat for [rails/jquery]-ujs ajax callbacks
      var json
      if (event.detail) {
        json = JSON.parse(event.detail[2].response)
        status = event.detail[1]
      } else {
        json = xhr.responseJSON
      }

      if (status == 'OK') {
        $form.append($('span').text(json.message))
        $('input:visible, textarea', $form).val('')
      } else {
        alert('Sorry, something went wrong.')
      }
    }

    $form.on('ajax:success', function(event, data, status, xhr) {
      handleResponse(event, status, xhr)
    })

    $form.on('ajax:error', function(event, xhr, status) {
      handleResponse(event, status, xhr)
    })
  })
})
