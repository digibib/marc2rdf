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

  // ** VOCABULARY

  $("#change_vocabularies").delegate(".add_vocabulary", "click", function(){
    var data = '<tr><td></td>' + 
       '<td><input type="text" class="vocabulary_prefix" style="width:80px" /></td>' +
       '<td><input type="text" class="vocabulary_uri" style="width:320px" /></td>' +
       '<td><button class="save_vocabulary">save</button></td></tr>';
       
    $("#change_vocabularies").append(data);
    return false;
  });
      
  // save vocabulary
  $("#change_vocabularies").delegate('.save_vocabulary', 'click', function() {
    var row = $(this).closest('tr');
    var request = $.ajax({
      url: '/api/vocabularies',
      type: 'POST',
      contentType: "application/json; charset=utf-8",
      data: JSON.stringify({ 
        prefix: row.find('.vocabulary_prefix').val(),
        uri: row.find('.vocabulary_uri').val()
        }),
      cache: false,
      dataType: 'json'
    });
    
    request.done(function(data) {
      $('span#vocabularies_info').html("Added vocabulary OK!").show().fadeOut(3000);
      // toggle save/delete button
      row.find('button.save_vocabulary').removeClass('save_vocabulary').addClass('delete_vocabulary').text('delete');
    });
    request.fail(function(jqXHR, textStatus, errorThrown) {
      $('span#vocabularies_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
    return false;
  });

  // delete vocabulary
  $("#change_vocabularies").delegate('.delete_vocabulary', 'click', function() {
    var row = $(this).closest('tr');
    var request = $.ajax({
      url: '/api/vocabularies/' + row.find('.vocabulary_prefix').val(),
      type: 'DELETE',
      contentType: "application/json; charset=utf-8",
      cache: false,
      dataType: 'json'
    });
    
    request.done(function(data) {
      $('span#vocabularies_info').html("Deleted vocabulary OK!").show().fadeOut(3000);
      row.remove();
    });
    request.fail(function(jqXHR, textStatus, errorThrown) {
      $('span#vocabularies_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
    return false;
  });
});
