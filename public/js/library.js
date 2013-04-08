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
    
  // ** Library Settings 
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
              url: $('input#create_library_oai_url').val(),
              preserve_on_update: [ "FOAF.depiction" ],
              timeout: 60,
              format: "marcxchange",
              follow_redirects: false,
              parser: "rexml"
              },
          }),
      dataType: 'json'
    });

    request.done(function(data) {
      $('span#library_info').html("Saved library OK!").show().fadeOut(3000);
      window.location.reload();
    });

    request.fail(function(jqXHR, textStatus, errorThrown) {
      $('span#library_error').html(jqXHR.responseText).show().fadeOut(5000);
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
            //oai: { url: $('input#save_library_oai_url').val() },
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
  // ** end LIBRARY settings
  
  // ** OAI settings
  // ** functions to add/remove table row, class "remove_table_row"
  $("table#preserve").delegate(".remove_table_row", "click", function(){
    $(this).closest("tr").remove();
    return false;
  });
  $("table#preserve").delegate(".add_table_row", "click", function(){
    var data = '<tr><td></td><td>' + 
       '<input type="text" class="preserve_on_update" /></td>' +
       '<td><button class="remove_table_row">-</button></td></tr>';
       
    $("table#preserve").append(data);
    return false;
  });

  // ** save oai settings
  $('button#oai_settings_save').on('click', function() {
  
    // make preserve table inputs into array
    var preserve_array = [];
    $("table#preserve input:text").each(function() { 
      var val=$(this).attr('value');
      preserve_array.push(val);
    });
    //alert(preserve_array);
    
    request = $.ajax({
      url: '/api/library',
      type: 'PUT',
      cache: false,
      contentType: "application/json; charset=utf-8",
      data: JSON.stringify({
          id: id,
          oai: {
            url: $('input#url').val(),
            follow_redirects: $('select#follow_redirects option:selected').val(),
            parser: $('select#parser option:selected').val(),
            //parser: $('input#parser').val(),
            timeout: $('input#timeout').val(),
            format: $('select#format option:selected').val(),
            preserve_on_update: preserve_array
          }}),
      dataType: 'json'
    });

    request.success(function(data) {
      $('span#oai_info').html("Saved oai settings !").show().fadeOut(3000);
    });

    request.error(function(jqXHR, textStatus, errorThrown) {
      $('span#oai_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  });
  // ** end OAI settings
  
  // ** MAPPING
  // ** test mapping
  $('button#test_mapping').ajaxSend( function() {
      $(this).addClass('loading');
  });
  $('button#test_mapping').ajaxComplete( function(){
      $(this).removeClass('loading');
  });
  $('button#test_mapping').on('click', function(e) {
    request = $.ajax({
      url: '/api/conversion/test',
      type: 'PUT',
      cache: false,
      contentType: "application/json; charset=utf-8",
      //beforeSend: function(){ $("#loaderDiv").show(); },
      data: JSON.stringify({ 
        id: id,
        mapping: $(this).closest('tr').attr("id"),
        }),
      dataType: 'json'
    });

    request.success(function ( data ) {
      //$("#loaderDiv").hide();
      if( console && console.log ) {
        console.log("Sample of data:", JSON.stringify(data).slice(0, 300));
      }
      var result = JSON.stringify(data, null, "  ").replace(/\</gi,"&lt;")
      $("#mapping_test").html('<br/><pre>' + result + '</pre>');
    });
    request.error(function(jqXHR, textStatus, errorThrown) {
      $('span#mapping_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  });
  
  $('button#select_mapping').on('click', function() {
    var btn = $(this);
    request = $.ajax({
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
       // deactivate button
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
    request = $.ajax({
      url: '/api/oai/getrecord',
      type: 'PUT',
      cache: false,
      contentType: "application/json; charset=utf-8",
      data: JSON.stringify({ 
        id: id,
        record: $('input#oai_getrecord').val(),
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
    request = $.ajax({
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
      window.location="/convert/"+id+"/"+filename;
    });
    request.error(function(jqXHR, textStatus, errorThrown) {
      $('span#conversion_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  });      

  // ** test save all!
  $('button#save_convert_all_test').on('click', function() {
    request = $.ajax({
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
      $('span#oai_error').html(jqXHR.responseText).show().fadeOut(5000);
    });
  });
});
