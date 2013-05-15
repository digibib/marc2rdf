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

  // ** functions to add/remove table row, class "remove_table_row"
  $("table#harvester_predicates").delegate(".remove_table_row", "click", function(){
    $(this).closest("tr").remove();
    return false;
  });
  $("table#harvester_predicates").delegate(".add_table_row", "click", function(){
    var data = '<tr><td></td><td>' + 
       '<input type="text" class="harvester_predicates" /></td>' +
       '<td><button class="remove_table_row">-</button></td></tr>';
       
    $("table#harvester_predicates").append(data);
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
    // make harvester predicate table inputs into array
    var predicates_array = [];
    $("table#harvester_predicates input:text").each(function() { 
      var val=$(this).attr('value');
      predicates_array.push(val);
    });
    alert(predicates_array);

    var request = $.ajax({
      url: '/api/harvester',
      type: 'PUT',
      contentType: "application/json; charset=utf-8",
      cache: false,
      data: JSON.stringify({
          id: $('input#save_harvester_id').val(),
          protocol: $('select#save_harvester_protocol option:selected').val(),
          name: $('input#save_harvester_name').val(),
          description: $('input#save_harvester_description').val(),
          subject: $('select#save_harvester_subject option:selected').val(),
          predicates: predicates_array
          }),
      dataType: 'json'
    });
    
    request.done(function(data) {
      console.log("updated harvester: "+ $('input#save_harvester_id').val());
      console.log(data);
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
    if (confirm('Are you sure? All info on Harvester will be lost!')) {
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
        $('span#save_harvester_info').html("Deleted harvester OK!").show().fadeOut(3000);
        window.location = '/harvester';
      });
  
      request.fail(function(jqXHR, textStatus, errorThrown) {
        $('span#save_harvester_error').html(jqXHR.responseText).show().fadeOut(5000);
      });
    }
  }); 

});
