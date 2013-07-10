$(document).ready(function () {
  // ** global vars
  var session_key = $('#active_session_key').html();
  $(document).ajaxSend(function(e, xhr, settings) {
    xhr.setRequestHeader('SECRET_SESSION_KEY', session_key);
  });
  var id = $('#active_library_id').html();

  // ** options tabs handling **
  $('.pane').hide();
  $('.pane:first').addClass('active').show();
  
  $('.tabs li').on('click', function() {
    $('.tabs li.active').removeClass('active');
    $(this).addClass('active');
    var idx = $(this).index();
    $('.pane').hide();
    $('.pane:eq('+idx+')').show();
  });
  
  // create new mapping
  $('button#create_mapping').on('click', function() {
    var request = $.ajax({
      url: '/api/mappings',
      type: 'POST',
      cache: false,
      contentType: "application/json; charset=utf-8",
      data: JSON.stringify({ 
          name: $('input#create_mapping_name').val(),
          description: $('input#create_mapping_description').val(),
          mapping: {
            "tags": { }
          }
          }),
      dataType: 'json'
    });

    request.done(function(data) {
      $('span#mapping_info').html("Saved mapping OK!").show().fadeOut(3000);
      window.location.reload();
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
      $('span#mapping_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  });
  
  // ** save mapping
  $('button#save_mapping').on('click', function() {
    var map_id = $('input#save_mapping_id').val();
    var request = $.ajax({
      url: '/api/mappings',
      type: 'PUT',
      contentType: "application/json; charset=utf-8",
      cache: false,
      data: JSON.stringify({
          id: map_id,
          name: $('input#save_mapping_name').val(),
          description: $('input#save_mapping_description').val(),
          mapping: editor.get()
          }),
      dataType: 'json'
    });
    
    request.done(function(data) {
      console.log("updated mapping: " + map_id);
      if( console && console.log ) {
        console.log("Sample of data:", JSON.stringify(data).slice(0, 300));
      }
      $('span#mapping_info').html("Saved mapping OK!").show().fadeOut(3000);
      //window.location.reload();
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
      $('span#mapping_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  });

  // clone mapping into new
  $('button#clone_mapping').on('click', function() {
    $.getJSON('/api/mappings', { id: $(this).closest('tr').attr("id") })
      .done(function(data) {
        json = data["mapping"];
        json.name = json.name + ' copy';
        console.log("cloned mapping: " + JSON.stringify(json));
        $.ajax({
          url: '/api/mappings', 
          type: 'POST',
          contentType: "application/json; charset=utf-8",
          data: JSON.stringify(json),
          dataType: 'json'
        })
        .done(function(response) { 
          console.log("Sample of data:", JSON.stringify(response).slice(0, 300));
          $('span#mapping_info').html("Cloned mapping OK!").show().fadeOut(3000);
          window.location.reload();
        })
        .fail(function(jqXHR, textStatus, errorThrown) {
          $('span#mapping_error').html(jqXHR.responseText).show().fadeOut(5000);
        });
      });
  });

  // ** delete mapping
  $('button#delete_mapping').on('click', function() {
    if (confirm('Are you sure? All info on Mapping will be lost!')) {
      var request = $.ajax({
        url: '/api/mappings',
        type: 'DELETE',
        cache: false,
        data: { 
            id: $('input#save_mapping_id').val(),
            },
        dataType: 'json'
      });

      request.done(function(data) {
        $('span#mapping_info').html("Deleted mapping OK!").show().fadeOut(3000);
        window.location.reload();
      });

      request.fail(function(jqXHR, textStatus, errorThrown) {
        $('span#mapping_error').html(jqXHR.responseText).show().fadeOut(5000);
      });
    }
  }); 
           
});
