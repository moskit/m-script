init = function() {
  el = document.body;
  el.observe('click', hideAll);
  fillTabs();
  initMonitors('dash');
  $$('div.details').each(function(value) { value.hide() });
}

var pu = null;

initMonitors = function(updater) {
  if (pu) { pu.stop(); }
  pu = new Ajax.PeriodicalUpdater('content', '/bin/' + updater + '.cgi', {
    method: 'get', frequency: 200, decay: 10
  });
  $$('#tabs ul li').each(function(value) { if (value.hasClassName('active')) value.removeClassName('active');});
  if ($(updater)) { $(updater).addClassName('active'); }
}


fillTabs = function() {
  var the_url = '/bin/filltabs.cgi';
  new Ajax.Request(the_url, {
    onSuccess: function(response) {
      $('tabs').update(response.responseText);
    }
  });
}

showURL = function(theid,url,scriptname) {
  if ($('data_' + theid).style.display == "none") {
    var the_url = '/bin/fetchurl.cgi?url=' + escape(url) + '&to=/' + scriptname + '/' + escape(theid) + '.html';
    new Ajax.Request(the_url, {
      onSuccess: function(response) {
        $('data_' + theid).update(response.responseText);
      },
      onComplete: function() {
        Effect.SlideDown('data_' + theid, {duration: 0.3});
      }
    });
  }
}

showData = function(theid,base) {
  server=$(theid).parentNode.id;
  cluster=$(server).parentNode.id;
  if ($('data_' + theid).style.display == "none") {
    if (cluster == 'content') {
      var the_url = '/bin/getdata.cgi?path=' + base + '/localhost/' + escape(theid) + '.html';
    } else {
      var the_url = '/bin/getdata.cgi?path=' + base + '/' + cluster + '/' + server + '/' + escape(theid) + '.html';
    }
    new Ajax.Request(the_url, {
      onSuccess: function(response) {
        $('data_' + theid).update(response.responseText);
      },
      onComplete: function() {
        Effect.SlideDown('data_' + theid, {duration: 0.3});
      }
    });
	}
}

showDetails = function(theid,script) {
  server=$(theid).parentNode.id;
  cluster=$(server).parentNode.id;
  if ($(server + '_details').style.display == "none") {
    var the_url = '/bin/showdetails.cgi?script=' + script + '&cluster=' + cluster + '&server=' + server;
    new Ajax.Request(the_url, {
      onSuccess: function(response) {
        $(server + '_details').update(response.responseText);
      },
      onComplete: function() {
        Effect.SlideDown(server + '_details', {duration: 0.3});
      }
    });
	}
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
  $$('div.details').each(function(value) { if (value.id != targ.id) value.hide(); });
}


