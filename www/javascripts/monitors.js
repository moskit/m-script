init = function() {
  el = document.body;
  el.observe('click', hideAll);
  initMonitors();
}

initMonitors = function() {
  new Ajax.PeriodicalUpdater('dash', '/bin/update_dash.cgi', {
    method: 'get', frequency: 200, decay: 10
  });
}

showData = function(theid) {
  server=$(theid).parentNode.id;
  cluster=$(server).parentNode.id;
  if ($('data_' + theid).style.display == "none") {
    if (cluster == 'localhost') {
    var the_url = '/bin/getdata?path=/servers/localhost/' + escape(theid) + '.html';
    } else {
    var the_url = '/bin/getdata?path=/servers/' + cluster + '/' + server + '/' + escape(theid) + '.html';
    }
    new Ajax.Request(the_url, {
      onComplete: function(response) {
        $('data_' + theid).update(response.responseText);
      }
    });
    Effect.SlideDown('data_' + theid, {duration: 0.3});
	}
}

updateMonitors = function() {
  
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

hideAll = function(e) {
  var targ;
	if (!e) var e = this.event;
	if (e.target) targ = e.target;
	else if (e.srcElement) targ = e.srcElement;
//	if (targ.nodeType == 3) 
  targ = targ.parentNode.parentNode;
  $$('div.dhtmlmenu').each(function(value) { if (value.id != targ.id) value.hide(); });
}


