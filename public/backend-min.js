$(document).ready(function(){if($(".quicksearch tbody tr").length>0){var c=$(".quicksearch"),b=c.data("quicksearch")=="no_focus"?"":"autoselect",e=c.data("label")?c.data("label"):"Set me with data-label";$(".quicksearch tbody tr").quicksearch({attached:".quicksearch",position:"before",labelText:e,inputText:"",inputClass:b,delay:300})}$(".ajax_confirm").click(function(){var i=confirm($(this).data("confirm_message"));return i});$(".ajax_hide_items").click(function(){$(".items").hide("slow")});$(".toggle_me").hide();$(".toggle_link").click(function(i){$(this).next(".toggle_me").toggle("slow");$(this).toggleClass("current").focus()});$(".ajax_filter_by_me").click(function(){var i=$(this).html().trim(),j=$(".quicksearch input");j.val(i);j.focus()});$(".autoselect").focus().select();$(".tablesorter").tablesorter();$("input[name=i_id]").attr("autocomplete","off");$("a.edit").focusin(function(){$(this).closest("tr").addClass("item_hover")}).focusout(function(){$(this).closest("tr").removeClass("item_hover")}).click(function(){$(this).closest("tr").removeClass("item_hover")});$(".ajax_item").click(function(){window.location.href=$(this).find("a").attr("href")});$(".flash.notice").parent().addClass("notice");$(".edit_bulk").click(function(k){k.preventDefault();k.stopPropagation();var j=$(this).closest("tr"),i="/admin/bulks/"+k.target.dataset.b_id;$.ajax({type:"GET",url:i,beforeSend:function(){j.html('<td colspan="6" class="loading"><img src="/media/loading.gif" alt="Cargando..." /></td>')},success:function(l){j.html(l);$("[autofocus]").focus().select()},error:function(){$("#ajax_panel").html('<p class="error"><strong>Oops!</strong> Proba denuevo.</p>')}})});$("form").on("keyup","select[name=b_status]",function(i){if(i.keyCode==13){$(this).closest("form").submit()}});$("input[type=tel].number.positive").on({focus:function(i){original=this.value},keyup:function(i){if(~this.value.indexOf("-")){this.value=this.value.replace(/[\-]/g,"")}if(!d(this.value)){this.value=original}}});$("form").on("keyup","#ajax_product_buy_cost",function(i){h()});$("#ajax_product_price").on({focus:function(i){original_price=document.getElementById("ajax_product_price").value},keyup:function(i){if(this.value.length>0&&this.value!=original_price){h();g()}}});function d(i){return parseFloat(i.replace(/[\,]/g,"."))==Number(i.replace(/[\,]/g,"."))}function a(i){return Number(i.replace(/[\,]/g,"."))}function h(){buy_cost=document.getElementById("ajax_product_buy_cost");parts_cost=document.getElementById("ajax_product_parts_cost");materials_cost=document.getElementById("ajax_product_materials_cost");sale_cost=document.getElementById("ajax_product_sale_cost");ideal_markup=document.getElementById("ajax_product_ideal_markup");real_markup=document.getElementById("ajax_product_real_markup");price=document.getElementById("ajax_product_price");var l=a(price.value)/(a(buy_cost.value)+a(parts_cost.value)+a(materials_cost.value));var k=Math.round(l*1000)/1000;real_markup.value=k;if(ideal_markup.value==""||ideal_markup.value==0||ideal_markup.value==Infinity||ideal_markup.value==NaN){ideal_markup.value=real_markup.value}var j=a(buy_cost.value)+a(parts_cost.value)+a(materials_cost.value);var i=Math.round(j*1000)/1000;sale_cost.value=i}function g(){exact_price=document.getElementById("ajax_product_exact_price");price=document.getElementById("ajax_product_price");exact_price.value=price.value}$(".ajax_void_item").click(function(n){n.preventDefault();n.stopPropagation();var k=confirm($(this).data("confirm_message"));if(k==false){return false}var m=$(".ajax_response");var i=$(this).closest("form").attr("action");var j=$(this).siblings("input[name=csrf]").attr("value");var l=$(this).siblings("input[name=i_id]").attr("value");$.ajax({type:"POST",url:i,data:{csrf:j},beforeSend:function(){m.html('<div class="loading"><img src="/media/loading.gif" alt="Cargando..." /></div>')},success:function(s){$(".flash").hide("slow");m.html(s);var r=$("td:contains("+l+")");r.parent("tr").hide("slow");var p=r.closest("table").find(".counter");var o=p.html().trim();var q=parseInt(o,10);p.html(o.replace(q,q-1));$("[autofocus]").focus().select()},error:function(){m.html('<p class="error"><strong>Oops!</strong> Proba denuevo.</p>')}})});function f(){$(".persist_area").each(function(){var j=$(this),l=j.offset(),k=$(window).scrollTop(),i=$(".floating_header",this);if((k>l.top)&&(k<l.top+j.height())){i.css({visibility:"visible"})}else{i.css({visibility:"hidden"})}})}$(function(){var i;$(".persist_area").each(function(){i=$(".persist_header",this);i.before(i.clone()).css("width",i.width()).addClass("floating_header")});$(window).scroll(f).trigger("scroll")})});