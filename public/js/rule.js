$(document).ready(function () {
  // ** global vars
  //$('change_rdfstore_settings_form').remotize({spinner: $('/img/ajax-loader.gif')});
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

  // ** create new rule
  $('button#create_rule').on('click', function() {
    var request = $.ajax({
      url: '/api/rules',
      type: 'POST',
      cache: false,
      contentType: "application/json; charset=utf-8",
      data: JSON.stringify({ 
          name: $('input#create_rule_name').val(),
          }),
      dataType: 'json'
    });

    request.done(function(data) {
      $('span#rule_info').html("Created rule OK!").show().fadeOut(3000);
      window.location = '/rules/'+data.rule["id"];
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
      $('span#rule_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  });

  // ** edit rule
  $('button#save_rule').on('click', function() {
    var request = $.ajax({
      url: '/api/rules',
      type: 'PUT',
      contentType: "application/json; charset=utf-8",
      cache: false,
      data: JSON.stringify({
          id: $('input#save_rule_id').val(),
          type: $('select#save_rule_type option:selected').val(),
          name: $('input#save_rule_name').val(),
          description: $('input#save_rule_description').val(),
          script: $('textarea#save_rule_script').val(),
          tag: $('input#save_rule_tag').val(),
          start_time: $('input#save_rule_start_time').val(),
          frequency: $('input#save_rule_frequency').val(),
          }),
      dataType: 'json'
    });
    
    request.done(function(data) {
      console.log("updated rule: "+ $('input#save_rule_id').val());
      console.log(data);
      $('span#save_rule_info').html("Saved rule OK!").show().fadeOut(3000);
      //window.location.reload();
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
      $('span#save_rule_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  });

  // clone rule into new
  $('button#clone_rule').on('click', function() {
    $.getJSON('/api/rules', { id: $('input#save_rule_id').val() })
      .done(function(data) {
        json = data["rules"][0];
        json.name = json.name + ' copy';
        console.log("cloned rule: " + JSON.stringify(json));
        $.ajax({
          url: '/api/rules', 
          type: 'POST',
          contentType: "application/json; charset=utf-8",
          data: JSON.stringify(json),
          dataType: 'json'
        })
        .done(function(response) { 
          console.log("Sample of data:", JSON.stringify(response).slice(0, 300));
          $('span#mapping_info').html("Cloned rule OK!").show().fadeOut(3000);
          window.location.reload();
        })
        .fail(function(jqXHR, textStatus, errorThrown) {
          $('span#mapping_error').html(jqXHR.responseText).show().fadeOut(5000);
        });
      });
  });
    
  // ** edit rule script
  $('button#save_rule_script').on('click', function() {
    var request = $.ajax({
      url: '/api/rules',
      type: 'PUT',
      contentType: "application/json; charset=utf-8",
      cache: false,
      data: JSON.stringify({
          id: $('input#save_rule_id').val(),
          script: $('textarea#rule_script').val(),
          }),
      dataType: 'json'
    });
    
    request.done(function(data) {
      console.log("updated rule script: "+ $('textarea#rule_script').val());
      console.log(data);
      $('span#save_rule_script_info').html("Saved script OK!").show().fadeOut(3000);
      //window.location.reload();
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
      $('span#save_rule_script_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  });
          
  // ** delete rule
  $('button#delete_rule').on('click', function() {
    var request = $.ajax({
      url: '/api/rules',
      type: 'DELETE',
      cache: false,
      data: { 
          id: $('input#save_rule_id').val(),
          },
      dataType: 'json'
    });

    request.done(function(data) {
      $('span#save_rule_info').html("Deleted rule OK!").show().fadeOut(3000);
      window.location = '/rules';
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
      $('span#save_rule_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  }); 
  
  // test-activate rule
  $('button#test_rule').on('click', function() {
    request = $.ajax({
      url: '/api/scheduler/start_rule',
      type: 'PUT',
      contentType: "application/json; charset=utf-8",
      data: JSON.stringify({ id: $('input#save_rule_id').val() }),
      cache: false,
      dataType: 'json'
    });
    
    request.done(function(data) {
      window.location = '/status';
    });
    request.fail(function(jqXHR, textStatus, errorThrown) {
      $('span#save_rule_script_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  });

});
