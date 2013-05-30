$(document).ready(function () {
  // ** global vars
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

  // ** functions to add/remove table row on harvester predicates, class "remove_table_row"
  $("table#harvester_predicates").delegate(".remove_table_row", "click", function(){
    $(this).closest("tr").remove();
    return false;
  });
  $("table#harvester_predicates").delegate(".add_table_row", "click", function(){
    var data = '<tr><td></td>' + 
       '<td><input type="text" class="harvester_predicate" /></td>' +
       '<td><select class="harvester_datatype"><option>uri</option><option>literal</option></select></td>' +
       '<td><input type="text" class="harvester_xpath" /></td>' +
       '<td><input type="text" class="harvester_regex_strip" /></td>' +
       '<td><button class="remove_table_row">delete row</button></td></tr>';
       
    $("table#harvester_predicates").append(data);
    return false;
  });

  // ** functions to add/remove table row on namespaces, class "remove_table_row"
  $("table#harvester_namespaces").delegate(".remove_table_row", "click", function(){
    $(this).closest("tr").remove();
    return false;
  });
  $("table#harvester_namespaces").delegate(".add_table_row", "click", function(){
    var data = '<tr><td></td>' + 
       '<td><input type="text" class="harvester_namespace_prefix" /></td>' +
       '<td><input type="text" class="harvester_namespace_url" /></td>' +
       '<td><button class="remove_table_row">delete row</button></td></tr>';
       
    $("table#harvester_namespaces").append(data);
    return false;
  });
    
  // ** create new harvester
  $('button#create_harvester').on('click', function() {
    var request = $.ajax({
      url: '/api/harvester',
      type: 'POST',
      cache: false,
      contentType: "application/json; charset=utf-8",
      data: JSON.stringify({ 
          name: $('input#create_harvester_name').val(),
          }),
      dataType: 'json'
    });

    request.done(function(data) {
      $('span#create_harvester_info').html("Created harvester OK!").show().fadeOut(3000);
      window.location = '/harvester/'+data.harvester["id"];
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
      $('span#create_harvester_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  });

  // ** edit harvester
  $('button#save_harvester').on('click', function() {
    
    // predicates hash
    var predicates={};
    $("#harvester_predicates tr:gt(0)").each(function() { 
      pred = $(this).find(".harvester_predicate").val();
      predicates[pred]={};
      predicates[pred]['datatype'] = $(this).find(".harvester_datatype option:selected").val();
      predicates[pred]['xpath'] = $(this).find(".harvester_xpath").val();
      predicates[pred]['regex_strip'] = $(this).find(".harvester_regex_strip").val();
    });

    // namespaces hash
    var namespaces={};
    $("#harvester_namespaces tr:gt(0)").each(function() { 
      key = $(this).find(".harvester_namespace_prefix").val();
      namespaces[key] = $(this).find(".harvester_namespace_url").val();
    });
    
    var request = $.ajax({
      url: '/api/harvester',
      type: 'PUT',
      contentType: "application/json; charset=utf-8",
      cache: false,
      data: JSON.stringify({
          id: $('#save_harvester_id').val(),
          protocol: $('#save_harvester_protocol option:selected').val(),
          name: $('#save_harvester_name').val(),
          description: $('#save_harvester_description').val(),
          url: { 
            prefix: $('#save_harvester_url_prefix').val(),
            suffix: $('#save_harvester_url_suffix').val()
          },
          limits: {
            max_limit: $('#save_harvester_max_limit').val(),
            batch_limit: $('#save_harvester_batch_limit').val(),
            retry_limit: $('#save_harvester_retry_limit').val(),
            delay: $('#save_harvester_delay').val()
          },
          local: {
            subject: $('#save_harvester_local_subject option:selected').val(),
            predicate: $('#save_harvester_local_predicate').val(),
            object: $('#save_harvester_local_object').val()
          },
          remote: {
            predicates: predicates,
            namespaces: namespaces
          }

          }),
      dataType: 'json'
    });
    
    request.done(function(data) {
      console.log("updated harvester: "+ $('input#save_harvester_id').val());
      //console.log(data);
      $('span#save_harvester_info').html("Saved harvester OK!").show().fadeOut(3000);
      //window.location.reload();
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
      $('span#save_harvester_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  });

  // clone harvester into new
  $('button#clone_harvester').on('click', function() {
    $.getJSON('/api/harvester', { id: $(this).closest('tr').attr("id") })
      .done(function(data) {
        json = data["harvester"];
        json.name = json.name + ' copy';
        console.log("cloned harvester: " + JSON.stringify(json));
        $.ajax({
          url: '/api/harvester', 
          type: 'POST',
          contentType: "application/json; charset=utf-8",
          data: JSON.stringify(json),
          dataType: 'json'
        })
        .done(function(response) { 
          console.log("Sample of data:", JSON.stringify(response).slice(0, 300));
          $('span#save_harvester_info').html("Cloned harvester OK!").show().fadeOut(3000);
          window.location.reload();
        })
        .fail(function(jqXHR, textStatus, errorThrown) {
          $('span#save_harvester_error').html(jqXHR.responseText).show().fadeOut(5000);
        });
      });
  });
          
  // ** delete harvester
  $('button#delete_harvester').on('click', function() {
    if (confirm('Are you sure? All info on Harvester Rule will be lost!')) {
      var request = $.ajax({
        url: '/api/harvester',
        type: 'DELETE',
        cache: false,
        data: { 
            id: $('input#save_harvester_id').val(),
            },
        dataType: 'json'
      });
  
      request.done(function(data) {
        $('span#save_harvester_info').html("Deleted harvester rule OK!").show().fadeOut(3000);
        window.location = '/harvester';
      });
  
      request.fail(function(jqXHR, textStatus, errorThrown) {
        $('span#save_harvester_error').html(jqXHR.responseText).show().fadeOut(5000);
      });
    }
  }); 

});
