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
    
  // ** SETTINGS 
  // ** create new library with some reasonable defaults */
  $('button#create_library').on('click', function() {
    var request = $.ajax({
      url: '/api/library',
      type: 'POST',
      cache: false,
      contentType: "application/json; charset=utf-8",
      data: JSON.stringify({ 
          name: $('input#create_library_name').val(),
          oai: { 
              url: "",
              preserve_on_update: [ "FOAF.depiction" ],
              timeout: 60,
              format: "marcxchange",
              follow_redirects: false,
              parser: "rexml"
              },
          rules: []
          }),
      dataType: 'json'
    });

    request.done(function(data) {
      $('span#library_info').html("Saved library OK!").show().fadeOut(3000);
      //load newly created library
      window.location = '/libraries/'+data.library["id"];
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
      $('span#library_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  });

  // clone library into new
  $('button#clone_library').on('click', function() {
    $.getJSON('/api/library', { id: $(this).closest('tr').attr("id") })
      .done(function(data) {
        json = data["library"];
        json.name = json.name + ' copy';
        console.log("cloned rule: " + JSON.stringify(json));
        $.ajax({
          url: '/api/library', 
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
    
  // ** edit library
  $('button#save_library').on('click', function() {
    var request = $.ajax({
      url: '/api/library',
      type: 'PUT',
      contentType: "application/json; charset=utf-8",
      cache: false,
      data: JSON.stringify({ 
            id: id,
            name: $('input#save_library_name').val(),
            config: {
              resource: {
                base: $('input#save_resource_base').val(),
                prefix: $('input#save_resource_prefix').val(),
                identifier_tag: $('input#save_identifier_tag').val(),
                type: $('input#save_resource_type').val(),
                default_prefix: $('input#save_default_prefix').val(),
                default_graph: $('input#save_default_graph').val(),
                },
              },
            }),
      dataType: 'json'
    });
    
    request.done(function(data) {
      console.log("updated library: "+id);
      $('span#library_info').html("Saved library OK!").show().fadeOut(3000);
      //window.location.reload();
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
      $('span#library_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  });
        
  // ** delete library
  $('button#delete_library').on('click', function() {
    if (confirm('Are you sure? All info on Library will be lost!')) {
      var request = $.ajax({
        url: '/api/library',
        type: 'DELETE',
        cache: false,
        data: { 
            id: id
            },
        dataType: 'json'
      });
  
      request.done(function(data) {
        $('span#library_info').html("Deleted library OK!").show().fadeOut(3000);
        window.location = '/reset';
      });
  
      request.fail(function(jqXHR, textStatus, errorThrown) {
        $('span#library_error').html(jqXHR.responseText).show().fadeOut(5000);
      });
    }
  }); 
  // ** end SETTINGS
  
  // ** OAI
  // ** functions to add/remove table row, class "remove_table_row"
  $("table#oai_preserve").delegate(".remove_table_row", "click", function(){
    $(this).closest("tr").remove();
    return false;
  });
  $("table#oai_preserve").delegate(".add_table_row", "click", function(){
    var data = '<tr><td></td><td>' + 
       '<input type="text" class="preserve_on_update" /></td>' +
       '<td><button class="remove_table_row">-</button></td></tr>';
       
    $("table#oai_preserve").append(data);
    return false;
  });

  // ** validate oai repository
  $('button#oai_settings_validate').on('click', function() {
    $.get('/api/oai/validate', { id: id })
      .done(function(data) {
        $('input#oai_id').val(data.id);
        $('span#oai_info').html(JSON.stringify(data)).show().fadeOut(5000);
      })
      .fail(function() { $('span#oai_error').html("Failed to validate, check URL!").show().fadeOut(5000); });
    
  });
  
  // ** save oai settings
  $('button#oai_settings_save').on('click', function() {
  
    // make preserve table inputs into array
    var preserve_array = [];
    $("table#oai_preserve input:text").each(function() { 
      var val=$(this).attr('value');
      preserve_array.push(val);
    });
    //alert(preserve_array);
    
    var request = $.ajax({
      url: '/api/library',
      type: 'PUT',
      cache: false,
      contentType: "application/json; charset=utf-8",
      data: JSON.stringify({
          id: id,
          oai: {
            url: $('input#oai_url').val(),
            id: $('input#oai_id').val(),
            follow_redirects: $('select#oai_follow_redirects option:selected').val(),
            parser: $('select#oai_parser option:selected').val(),
            timeout: $('input#oai_timeout').val(),
            format: $('select#oai_format option:selected').val(),
            preserve_on_update: preserve_array,
            schedule: $('input#oai_schedule').val()
            }
          }),
      dataType: 'json'
    });

    request.success(function(data) {
      $('span#oai_info').html("Saved oai settings !").show().fadeOut(3000);
      window.location.reload();
    });

    request.error(function(jqXHR, textStatus, errorThrown) {
      $('span#oai_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  });
  // ** end OAI
  
  // ** MAPPING
  // ** test mapping
  $('button#test_mapping').on('click', function(e) {
    var request = $.ajax({
      url: '/api/conversion/test',
      type: 'PUT',
      cache: false,
      contentType: "application/json; charset=utf-8",
      data: JSON.stringify({ 
        id: id,
        mapping: $(this).closest('tr').attr("id"),
        }),
      dataType: 'json'
    });
    $(this).addClass('loading');
    request.success(function ( data ) {
      $('button#test_mapping').removeClass('loading');
      if( console && console.log ) {
        console.log("Sample of data:", JSON.stringify(data).slice(0, 300));
      }
      var result = JSON.stringify(data, null, "  ").replace(/\</gi,"&lt;")
      $("#mapping_test").html('<br/><pre>' + result + '</pre>');
    });
    request.error(function(jqXHR, textStatus, errorThrown) {
      $('button#test_mapping').removeClass('loading');
      $('span#mapping_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  });
  
  // select mapping
  $('button#select_mapping').on('click', function() {
    var btn = $(this);
    var request = $.ajax({
      url: '/api/library',
      type: 'PUT',
      cache: false,
      contentType: "application/json; charset=utf-8",
      data: JSON.stringify({ 
        id: id,
        mapping: $(this).closest('tr').attr("id"),
        }),
      dataType: 'json'
    });

    request.success(function ( data ) {
       $('span#mapping_info').html("Changed mapping !").show().fadeOut(3000);
       // deactivate button for chosen mapping
       $('button#select_mapping').removeAttr('disabled');
       btn.attr('disabled', true);
    });
    request.error(function(jqXHR, textStatus, errorThrown) {
      $('span#mapping_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  });
  // ** end MAPPING
  
  // ** CONVERSION
  // oai getrecord test
  $('button#oai_getrecord_test').on('click', function() {
    var request = $.ajax({
      url: '/api/oai/getrecord',
      type: 'PUT',
      cache: false,
      contentType: "application/json; charset=utf-8",
      data: JSON.stringify({ 
        id: id,
        record: $('span#oai_id').val() + $('input#oai_getrecord').val(),
        }),
      dataType: 'json'
    });

    request.success(function ( data ) {
      if( console && console.log ) {
        console.log("Sample of data:", JSON.stringify(data).slice(0, 300));
      }
      var result = JSON.stringify(data, null, "  ").replace(/\</gi,"&lt;")
      $("#converted_content").html('<br/><pre>' + result + '</pre>');
    });
    request.error(function(jqXHR, textStatus, errorThrown) {
      $('span#conversion_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  });
  
  // ** test save conversion
  $('button#oai_saverecord_test').on('click', function() {
    filename = $('input#oai_saverecord_filename').val();
    var request = $.ajax({
      url: '/api/oai/getrecord',
      type: 'PUT',
      cache: false,
      contentType: "application/json; charset=utf-8",
      data: JSON.stringify({ 
        id: id,
        record: $('input#oai_getrecord').val(),
        filename: filename,
        }),
      dataType: 'json'
    });

    request.success(function ( data ) {
      if( console && console.log ) {
        console.log("Sample of data:", JSON.stringify(data).slice(0, 300));
      }
      var result = JSON.stringify(data, null, "  ").replace(/\</gi,"&lt;")
      $("#converted_content").html('<br/><pre>' + result + '</pre>');
      // and download file
      window.location="/convert/"+filename;
    });
    request.error(function(jqXHR, textStatus, errorThrown) {
      $('span#conversion_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  });      

  // ** test save all!
  $('button#save_convert_all_test').on('click', function() {
    var request = $.ajax({
      url: '/api/oai/saveall',
      type: 'PUT',
      cache: false,
      contentType: "application/json; charset=utf-8",
      data: JSON.stringify({ 
        id: id,
        }),
      dataType: 'json'
    });

    request.success(function ( data ) {
      if( console && console.log ) {
        console.log("Sample of data:", JSON.stringify(data).slice(0, 300));
      }
      var result = JSON.stringify(data, null, "  ").replace(/\</gi,"&lt;")
      $("#converted_content").html('<br/><pre>' + result + '</pre>');
    });
    request.error(function(jqXHR, textStatus, errorThrown) {
      $('span#conversion_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  });
  
  // ** test save all!
  $('button#oai_harvest_test').on('click', function() {
    $('input#oai_harvest_from').is('empty')  ? from  = $('input#oai_harvest_from').val()  : from  = null;
    $('input#oai_harvest_until').is('empty') ? until = $('input#oai_harvest_until').val() : until = null;
    var request = $.ajax({
      url: '/api/oai/harvest',
      type: 'PUT',
      cache: false,
      contentType: "application/json; charset=utf-8",
      data: JSON.stringify({ 
        id: id,
        from: from,
        until: until,
        write_records: $('input#write_records').is(':checked'),
        sparql_update: $('input#sparql_update').is(':checked')
        }),
      dataType: 'json'
    });

    request.success(function ( data ) {
      $('span#conversion_info').html("OAI harvesting started!").show().fadeOut(3000);
      window.location = '/status';
    });
    request.error(function(jqXHR, textStatus, errorThrown) {
      $('span#conversion_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  });
  
  // test upload and convert only first 20
  $("#uploadtest").live("click", function() {
    var file_data = $("#filename").prop("files")[0]; // Getting the properties of file from file field
    var form_data = new FormData();                 // Creating object of FormData class
    form_data.append("file", file_data)              // Appending parameter named file with properties of file_field to form_data
    form_data.append("id", id)                       // Adding extra parameters to form_data
    var request = $.ajax({
      url: "/api/conversion/uploadtest",
      dataType: 'json',
      cache: false,
      contentType: false,
      processData: false,
      data: form_data,
      type: 'POST'
    })
    $(this).addClass('loading');
    request.done(function(data) {
      $("#uploadtest").removeClass('loading');
      $('span#conversion_info').html("Uploaded OK!").show().fadeOut(3000);
      
      if( console && console.log ) {
        console.log("Sample of data:", JSON.stringify(data).slice(0, 300));
      }
      var result = JSON.stringify(data, null, "  ").replace(/\</gi,"&lt;");
      $("#converted_content").html('<br/><pre><h3>First few records of converted data:</h3>' + result + '</pre>');
    });
    request.fail(function(jqXHR, textStatus, errorThrown) {
      $("#uploadtest").removeClass('loading');
      $('span#conversion_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  })
  
  // upload and convert
  $("#upload").live("click", function() {
    var file_data = $("#filename").prop("files")[0]; // Getting the properties of file from file field
    var form_data = new FormData();                 // Creating object of FormData class
    form_data.append("file", file_data)              // Appending parameter named file with properties of file_field to form_data
    form_data.append("id", id)                       // Adding extra parameters to form_data
    var request = $.ajax({
      url: "/api/conversion/upload",
      dataType: 'json',
      cache: false,
      contentType: false,
      processData: false,
      data: form_data,
      type: 'POST'
    })
    $(this).addClass('loading');
    request.done(function(data) {
      $("#upload").removeClass('loading');
      $('span#conversion_info').html("Uploaded OK!").show().fadeOut(3000);
      
      if( console && console.log ) {
        console.log("Sample of data:", JSON.stringify(data).slice(0, 300));
      }
      var result = JSON.stringify(data, null, "  ").replace(/\</gi,"&lt;");
      $("#converted_content").html('<br/><pre><h3>Sample of converted data:</h3>' + result + '</pre>');
      // and download file
      window.location="/convert/"+data.filename;
    });
    request.fail(function(jqXHR, textStatus, errorThrown) {
      $("#upload").removeClass('loading');
      $('span#conversion_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  })
  // ** end CONVERSION
  
  // ** LOCAL RULES
  // run rule once
  $('button#run_rule_now').on('click', function() {
    var request = $.ajax({
      url: '/api/scheduler/run_rule',
      type: 'PUT',
      contentType: "application/json; charset=utf-8",
      data: JSON.stringify({ 
        id: $(this).closest('tr').attr("id"),
        library: id
        }),
      cache: false,
      dataType: 'json'
    });
    
    request.done(function(data) {
      $('span#rule_info').html("Activated Rule OK!").show().fadeOut(3000);
      window.location = '/status';
    });
    request.fail(function(jqXHR, textStatus, errorThrown) {
      $('span#rule_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  });
  
  // schedule rule
  $('button#schedule_rule').on('click', function() {
    var request = $.ajax({
      url: '/api/scheduler/schedule_rule',
      type: 'PUT',
      contentType: "application/json; charset=utf-8",
      data: JSON.stringify({ 
        id: $(this).closest('tr').attr("id"),
        library: id
        }),
      cache: false,
      dataType: 'json'
    });
    
    request.done(function(data) {
      $('span#rule_info').html("Scheduled Rule OK!").show().fadeOut(3000);
      window.location = '/status';
    });
    request.fail(function(jqXHR, textStatus, errorThrown) {
      $('span#rule_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  });
  
});
