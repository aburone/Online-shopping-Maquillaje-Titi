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
  $('input[name=i_id]').attr('autocomplete','off');


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
    var target = $(this).closest('tr'), url = "/admin/bulks/" + e.target.dataset.b_id;
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
  $('form').on('keyup','select[name=b_status]', function(e){
    if(e.keyCode == 13) {
      $(this).closest("form").submit();
    }
  }); 

  $('form').on('keyup','#ajax_product_buy_cost', function(e){
    update_real_markup_and_sale_cost();
  });


  $('#ajax_product_price').on({'focus': function(e){
      exact_price = document.getElementById("ajax_product_exact_price");
      original_exact_price = exact_price.value;
      original_price = this.value;
    },
    'keyup': function(e){
      update_real_markup_and_sale_cost();
      if(parseFloat(this.value.replace(/[\,]/g,'.')) != Number(this.value.replace(/[\,]/g,'.')) ) {
        this.value = original_price;
        exact_price.value = original_exact_price;
      } else {
        if( this.value.length > 0 && parseFloat(this.value.replace(/[\,]/g,'.')) == Number(this.value.replace(/[\,]/g,'.')) && original_price != this.value) {
          exact_price.value = this.value;
        }
      }
    }
  }); 

  function as_number(value) {
    return Number(value.replace(/[\,]/g,'.'));
  }

  function update_real_markup_and_sale_cost() {
    buy_cost = document.getElementById("ajax_product_buy_cost");
    parts_cost = document.getElementById("ajax_product_parts_cost");
    materials_cost = document.getElementById("ajax_product_materials_cost");
    sale_cost = document.getElementById("ajax_product_sale_cost");
    ideal_markup = document.getElementById("ajax_product_ideal_markup");
    real_markup = document.getElementById("ajax_product_real_markup");
    price = document.getElementById("ajax_product_price");

    real_markup.value = as_number(price.value) / ( as_number(buy_cost.value) + as_number(parts_cost.value) + as_number(materials_cost.value));
    if (ideal_markup.value == "" || ideal_markup.value == Infinity) {
      ideal_markup.value = real_markup.value;
    }
    sale_cost.value = as_number(buy_cost.value) + as_number(parts_cost.value) + as_number(materials_cost.value);
  }

  $('form').on('keyup','input[type=tel].number', function(e){
    this.value = this.value.replace(/[^0-9\.\,\-]/g,'');
    if(this.classList.contains("positive")) {
      this.value = this.value.replace(/[\-]/g,'');
    }
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
    $("#product_selector").val( $(this).find("td").html().trim() );
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
