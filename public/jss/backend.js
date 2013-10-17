$(document).ready(function () {

  if( $(".quicksearch tbody tr").length > 0 ) {
    var qs = $(".quicksearch"), inputClass = qs.data('quicksearch')=="no_focus" ? "" : "autoselect", labelText = qs.data('label') ? qs.data('label') : "Set me with data-label";

    $(".quicksearch tbody tr").quicksearch({
      attached:".quicksearch",
      position:"before",
      labelText: labelText,
      inputText:'',
      inputClass: inputClass,
      delay:300
    });
  }

  $('.ajax_confirm').click(function(){
    var answer = confirm( $(this).data('confirm_message') );
    return answer
  });  

  $('.ajax_hide_items').click(function(){
    $('.items').hide("slow");
  });  


  $(".toggle_me").hide();
  $(".toggle_link").click(function(e) {
    $(this).next(".toggle_me").toggle('slow');
    $(this).toggleClass("current").focus();
  });


  $(".ajax_filter_by_me").click(function() {
    var search_term = $(this).html().trim(), field = $(".quicksearch input");
    field.val(search_term);
    field.focus();
  });


  $(".autoselect").focus().select();
  $(".tablesorter").tablesorter();

  $("a.edit").focusin(function() {
    $(this).closest("tr").addClass('item_hover')
  }).focusout(function() {
    $(this).closest("tr").removeClass('item_hover')
  }).click(function(){
    $(this).closest("tr").removeClass('item_hover')
  });
  $(".ajax_item").click(function() {
    window.location.href = $(this).find("a").attr("href");
  });

  $(".flash.notice").parent().addClass('notice');

  $('.edit_bulk').click(function(e) {
    e.preventDefault();
    e.stopPropagation();
    var target = $(this).closest('tr'), url = "/admin/bulks/" + e.target.dataset.id;
    $.ajax({
      type: 'GET',
      url: url,
      // data: { postVar1: 'theValue1', postVar2: 'theValue2' },
      beforeSend:function(){
        target.html('<td colspan="6" class="loading"><img src="/media/loading.gif" alt="Cargando..." /></td>');
      },
      success:function(data){
        target.html(data);
        $("[autofocus]").focus().select();
      },
      error:function(){
        $('#ajax_panel').html('<p class="error"><strong>Oops!</strong> Proba denuevo.</p>');
      }
    });
  });

  $("#ajax_label_selector").bind("keypress", function (e) {
    if (e.keyCode === 13) {
      return move_focus_and_toggle_if_necesary();
    }
  });
  function move_focus_and_toggle_if_necesary() {
    var input = $('#ajax_label_selector').val();
    if (input !== '') {
      $("#prod_list_selector").toggle('slow');
      $("#finish_packaging").toggle('slow');
      $("#ajax_selected_label").val(input.trim());
      $("#product_selector").focus();
    }
    return false;
  }
  $(".ajax_product_selector").click(function() {
    $("#product_selector").val( $(this).find(".ajax_p_id").html().trim() );
    $("#product_selector").closest("form").submit();
  });


  $('.ajax_void_item').click(function(e) {
    e.preventDefault();
    e.stopPropagation();
    var answer = confirm( $(this).data('confirm_message') );
    if( answer == false ) {
      return false;
    }
    var target = $(".ajax_response");
    var url = $(this).closest('form').attr("action");
    var csrf = $(this).siblings("input[name=csrf]").attr("value");
    var i_id = $(this).siblings("input[name=i_id]").attr("value");

    $.ajax({
      type: 'POST',
      url: url,
      data: { csrf: csrf },
      beforeSend:function(){
        target.html('<div class="loading"><img src="/media/loading.gif" alt="Cargando..." /></div>');
      },
      success:function(data){
        $(".flash").hide("slow");
        target.html(data);

        var base = $("td:contains("+i_id+")")
        base.parent("tr").hide("slow");
        var counter = base.closest("table").find(".counter");
        var counter_text = counter.html().trim();
        var counter_num = parseInt(counter_text, 10);
        counter.html( counter_text.replace(counter_num, counter_num-1) );
        $("[autofocus]").focus().select();
      },
      error:function(){
        target.html('<p class="error"><strong>Oops!</strong> Proba denuevo.</p>');
      }
    });
  });

});
