$(window).load(function() {
  $('[data-contact-form]').each((_, input) => {
    const $form = $(input);

    function handleResponse(status, responseJSON) {
      if (responseJSON) {
        alert(responseJSON.message);
      } else {
        alert('Sorry, something went wrong.');
      }
      $('input:visible, textarea', $form).val('');
    }

    $form.on('ajax:success', (event, data, status, xhr) => {
      handleResponse(status, xhr.responseJSON);
    });

    $form.on('ajax:error', (event, xhr, status) => {
      handleResponse(status, xhr.responseJSON);
    });
  });
})