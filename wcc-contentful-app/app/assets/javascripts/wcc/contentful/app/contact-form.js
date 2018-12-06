if (typeof window.$ == 'undefined' ) {
  var $ = window.jQuery
}

$(function() {
  console.log('window loaded')
  function handleResponse($form, event, status, xhr) {
    console.log('in the handleResponse function')
    // Handle backwards compat for [rails/jquery]-ujs ajax callbacks
    var json
    if (event.detail) {
      console.log('the event detail')
      console.log(event.detail)
      json = JSON.parse(event.detail[2].response)
      status = event.detail[1]
      console.log('and the json')
      console.log(json)
    } else {
      json = xhr.responseJSON
      console.log('NO event detail')
      console.log(json)
    }

    console.log('the status is:')
    console.log(status)

    if (status == 'OK') {
      $form.append(
        $('<span>').text(json.message).delay(2000).fadeOut(2000, function() { $(this).remove() })
      )
      $('input:visible, textarea', $form).val('')
    } else {
      alert('Sorry, something went wrong.')
    }
  }

  $('[data-contact-form]').each(function(_, input) {
    console.log('data-contact-form.each')
    var $form = $(input)

    $form.on('ajax:success', function(event, data, status, xhr) {
      console.log('ajax:success')
      handleResponse($form, event, status, xhr)
    })

    $form.on('ajax:error', function(event, xhr, status) {
      console.log('ajax:error')
      handleResponse($form, event, status, xhr)
    })
  })
})
