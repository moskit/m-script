init = function() {
  hideToolbars();
  el = document.body;
  el.observe('click', hideAll);
  initToolbars();
  initSorters();
  initMenus();
}

initToolbars = function() {
  $$('div.file').each(function(value) { Event.observe(value, 'mouseover', showToolbar); });
  $$('div.file').each(function(value) { Event.observe(value, 'mouseout', hideToolbar); });
}

initSorters = function() {
  $$('form.sort_form').each(function(value) { Event.observe(value, 'submit', sortIt); });
}

initMenus = function() {

}

showMenu = function(theid,thetext,action) {
  if ($(theid).style.display == "none") {
    $(theid).innerHTML=thetext;
    Effect.SlideDown(theid, {duration: 0.3});
    Event.observe($(theid), "keypress", function(e) {
      var cKeyCode = e.keyCode || e.which;
      if (cKeyCode == Event.KEY_RETURN) {
        keyEvent(theid);
        e.stop();
      }
    });
	  
	  if (action == 'gettags') {
	    var the_path = $('path_' + theid).value;
      if (the_path) {
        var the_url = '/bin/gettags?path=' + escape(the_path);
        new Ajax.Request(the_url, {
          onComplete: function(response) {
//            var result_array = response.responseText.split('\n');  
            $('tags_' + theid).update(response.responseText);
//            $('tags_' + theid).update(result_array[1]);
          }
        });
      }
	  }
	}
//	if (!e) var e = window.event;
//  e.cancelBubble = true;
//  if (e.stopPropagation) e.stopPropagation();
}

showToolbar = function(event) {
  var divid = event.target;
  if (divid.hasClassName('file')) {
    tb = divid.childElements()[0];
    tb.style.visibility='visible';
  }

//  delayedHide = function(tb) { 
//    tb.style.visibility='hidden';
//  }
//  delayedHide.delay(5, tb);
}

hideToolbar = function(event) {
  var divid = event.target;
  var relTarg = event.relatedTarget || event.toElement;
///  alert(Element.select(divid, "*").length);
//  showVars($('showvars'),'=== From: ' + divid + '.' + divid.id + ' === To: ' + relTarg + '.' + relTarg.id);
  //  if (!relTarg.parentNode.hasClassName('file') && !relTarg.parentNode.parentNode.hasClassName('file')) {
  //	alert(relTarg);
////  showVars($('showvars'),divid.descendants().size());

  var relischild = false;

////  divid.descendants().each(function(value) { showVars($('showvars'),'Children: ' + value + '.' + value.id); if (value == relTarg) { showVars($('showvars'),'Is a child'); relischild = true; }})
  divid.descendants().each(function(value) { if (value == relTarg) { relischild = true; }})
    if (divid.hasClassName('file') && (!relischild)) {
      divid.childElements()[0].style.visibility='hidden';
////      showVars($('showvars'),'*** blip blip ***');
    }
//  $(theid).hide();
//  new Effect.Opacity($(theid), { from: 1, to: 0, delay: 1, transition: Effect.Transitions.linear });
//  return false;

}

hideAll = function(e) {
  var targ;
	if (!e) var e = this.event;
	if (e.target) targ = e.target;
	else if (e.srcElement) targ = e.srcElement;
//	if (targ.nodeType == 3) 
  targ = targ.parentNode.parentNode;
  $$('div.dhtmlmenu').each(function(value) { if (value.id != targ.id) value.hide(); });
}

hideToolbars = function() {
  $$('div.toolbar').each(function(value) { value.style.visibility='hidden'; });
}

showVars = function(result_div,newvar) {
  if (!newvar == '') {
//    result_div.appendChild(document.createTextNode(newvar));  
//    result_div.appendChild(document.createElement('br'));  

    var result_wrap, line_index, line;  

    result_wrap = document.createElement('div');  
    line = document.createTextNode(newvar);  
    result_wrap.appendChild(line);  
    result_div.appendChild(result_wrap);
    result_div.appendChild(line);
    result_div.appendChild(document.createElement('br'));  

    result_div.scrollTop = result_div.scrollHeight;
  }
}

// Thanks for the code below to: http://articles.sitepoint.com/article/take-command-ajax

printResult = function(result_string,theid) {
//  var result_div = document.getElementById('result_' + theid);  
  var result_array = result_string.split('\n');  
  $('result_' + theid).update(result_array[0]);
//  var new_tag = document.getElementById('tag').value;
//  result_div.appendChild(document.createTextNode(new_tag));  
//  result_div.appendChild(document.createElement('br'));  

//  var result_wrap, line_index, line;  

//  for (line_index in result_array) {  
//    result_wrap = document.createElement('pre');  
//    line = document.createTextNode(result_array[0]);  
//    result_wrap.appendChild(line);  
//    result_div.appendChild(result_wrap);
//    result_div.appendChild(line);
//    result_div.appendChild(document.createElement('br'));  
//  }  

//  result_div.scrollTop = result_div.scrollHeight;  
}

keyEvent = function(theid) {
//  alert(theid);
  var the_action = $('action_' + theid).value;
  var the_data = $('data_' + theid).value;
  var the_path = $('path_' + theid).value;
  if (the_data) {  
    var the_url = '/bin/action?action=' + escape(the_action) + '&path=' + escape(the_path) + '&userdata=' + the_data;  
//    alert(the_url);
    console.log("Query: " + the_url);
    new Ajax.Request(the_url, {
      method: 'get', onComplete: function(response) {
        // Note how we brace against null values
        //if ((response.getHeader('Server') || '').match(/Apache/)) {
        //  ++gApacheCount;
        // Remainder of the code
        printResult(response.responseText,theid);
        //}
        if (the_action == 'addtag') {
          var the_url = '/bin/gettags?path=' + escape(the_path);
          new Ajax.Request(the_url, {
            onComplete: function(response) {
              $('tags_' + theid).update(response.responseText);
            }
          });
	      }
      }
//      onFailure: function(response) { alert(response); }
    });
      
  }
  return false;
}

sortIt = function(event) {
//  alert(event.target.elements[0].name);
  var sort_action = event.target.elements[0].value;
  folder = document.URL.split("//")[1];
  folder = folder.split("/");
  realfolder='';
  for (i=1;i<folder.length-1;i++) {
    realfolder = realfolder + '/' + folder[i];
  }
//  realfolder = realfolder.gsub(/\.html$/, '');
  var the_url = '/bin/action?action=sortby' + '&path=' + realfolder + '&userdata=' + escape(sort_action);
  new Ajax.Request(the_url, {
    method: 'get', onComplete: function(response) {
      reloadContent(realfolder, sort_action);
    }
  });
  event.stop();
  return false;
}

reloadContent = function(realfolder, sort_action) {
  $$('div.file').each(function(value) { Event.stopObserving(value); });
  el = document.body;
  el.stopObserving;
  new Ajax.Updater({ success: 'folders' }, realfolder + '/folders.' + sort_action, { method: 'get', onComplete: function() { 
    hideToolbars();
    el = document.body;
    el.observe('click', hideAll);
    initToolbars();
    }
  });
  new Ajax.Updater({ success: 'files' }, realfolder + '/files.' + sort_action, { method: 'get', onComplete: function() { 
    hideToolbars();
    el = document.body;
    el.observe('click', hideAll);
    initToolbars();
    }
  });
}




