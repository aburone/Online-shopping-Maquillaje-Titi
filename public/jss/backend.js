$(document).ready(function () {


  el = document.querySelectorAll('.ajax_hide_on_click');
  for ( var i = 0; i < el.length; i++ ) {
      el[i].addEventListener("click", function(){
        this.classList.add('hide');
      }, false);
  }

  // click to edit
  $('.ajax_click_to_edit_sku').editable('/admin/products/ajax_update', {
      indicator:'Actualizando...', tooltip:'Click para editar...', width:230,
      submitdata:{ 'function':"update_sku" }
  });


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


  $(".flash.notice").parent().addClass('flash_notice');
  $(".flash").hover(function() { $(this).addClass('bounceOutUp') });

  setTimeout(function(){
    $(".flash_notice").addClass('bounceOutUp');
  },5000)

  setTimeout(function(){
    $(".flash_warning").addClass('bounceOutUp');
  },10000)


  // vanilla js ajax
  var distributor_selector=document.querySelector("#ajax_add_distributor");
  distributor_selector.addEventListener('change', function(){
    var http = new XMLHttpRequest();
    var url = '/admin/products/' + this.dataset.p_id + '/ajax_add_distributor/' + this.value;
    var params = this.dataset.csrfKey + "=" + this.dataset.csrfToken;
    http.open("POST", url, true);
    http.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
    http.setRequestHeader("Content-length", params.length);
    http.setRequestHeader("Connection", "close");
    http.onreadystatechange = function() {//Call a function when the state changes.
        if(http.readyState == 4 && http.status == 200) {
          var product_distributors_list=document.querySelector("#ajax_product_distributors");
          product_distributors_list.innerHTML = http.responseText;
          distributor_selector.value="";
        }
    }
    http.send(params);
  }, false);



  // DOM manupulation demo
  function popupate_product_distributors_list(responseText) {
    var product_distributors_list=document.querySelector("#ajax_product_distributors");
    product_distributors_list.innerHTML = "";
    var json = JSON.parse(responseText);
    product_distributors_list.appendChild(createP("⚫ " + JSON.parse(json[i]).d_name));
  }
  function createP(text) {
    var p = document.createElement("p");
    p.appendChild( document.createTextNode(text) );
    return p;
  }



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

  $('input[type=tel].number.positive').on({'focus': function(e){
      original = this.value;
    }, 'keyup': function(e){
      if( ~this.value.indexOf('-') ) {
        this.value = this.value.replace(/[\-]/g,'');
      }
      if( !is_number(this.value) ) {
        this.value = original;
      }
    }
  });

  $('form').on('keyup','#ajax_product_buy_cost', function(e){
    update_markup_and_sale_cost();
  });

  $('#ajax_product_price').on({'focus': function(e){
      original_price = document.getElementById("ajax_product_price").value;
    },
    'keyup': function(e){
      if (this.value.length > 0 && this.value != original_price) {
        update_markup_and_sale_cost();
        update_exact_price();
      }
    }
  });


  function is_number(value) {
    return parseFloat(value.replace(/[\,]/g,'.')) == Number(value.replace(/[\,]/g,'.'));
  }

  function as_number(value) {
    return Number(value.replace(/[\,]/g,'.'));
  }

  function update_markup_and_sale_cost() {
    buy_cost = document.getElementById("ajax_product_buy_cost");
    parts_cost = document.getElementById("ajax_product_parts_cost");
    materials_cost = document.getElementById("ajax_product_materials_cost");
    sale_cost = document.getElementById("ajax_product_sale_cost");
    ideal_markup = document.getElementById("ajax_product_ideal_markup");
    real_markup = document.getElementById("ajax_product_real_markup");
    price = document.getElementById("ajax_product_price");

    var full_real_markup = as_number(price.value) / ( as_number(buy_cost.value) + as_number(parts_cost.value) + as_number(materials_cost.value));
    var round_real_markup = Math.round(full_real_markup*1000)/1000;
    real_markup.value = round_real_markup;
    if (ideal_markup.value == "" || ideal_markup.value == 0 || ideal_markup.value == Infinity || ideal_markup.value == NaN) {
      ideal_markup.value = real_markup.value;
    }
    var full_sale_cost = as_number(buy_cost.value) + as_number(parts_cost.value) + as_number(materials_cost.value);
    var round_sale_cost = Math.round(full_sale_cost*1000)/1000;
    sale_cost.value = round_sale_cost;
  }

  function update_exact_price() {
    exact_price = document.getElementById("ajax_product_exact_price");
    price = document.getElementById("ajax_product_price");
    exact_price.value = price.value;
  }

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

  function UpdateTableHeaders() {
    $(".persist_area").each(function() {
      var el             = $(this),
      offset         = el.offset(),
      scrollTop      = $(window).scrollTop();
      if ((scrollTop > offset.top) && (scrollTop < offset.top + el.height())) {
        $(".persist_header:not([class*='floating_header'])", el).addClass("floating_header");
      } else {
        $(".persist_header", el).removeClass("floating_header");
      };
    });
  }
  // DOM Ready
  $(function() {
     $(".persist_area").each(function() {
         floating_header = $(".persist_header", this);
         floating_header.css("width", $(this).width() );
     });
    $(window)
    .scroll(UpdateTableHeaders)
    .trigger("scroll");
  });

});
