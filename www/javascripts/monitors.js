init = function() {
  el = document.body;
  el.observe('click', hideAll);
  fillTabs();
  initMonitors('dash');
}

var pu = null;

initMonitors = function(updater) {
  document.documentElement.style.cursor = 'wait';
  if (pu) { pu.stop(); }
  pu = new Ajax.PeriodicalUpdater('content', '/bin/' + updater + '.cgi', {
    method: 'get', frequency: 200, decay: 10
  });
  $$('#tabs ul li').each(function(value) { if (value.hasClassName('active')) value.removeClassName('active');});
  if ($(updater)) { $(updater).addClassName('active'); }
  document.documentElement.style.cursor = '';
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
  cluster=$(theid).parentNode.parentNode.id;
  server=$(theid).parentNode.id;
  if ($('data_' + theid).style.display == "none") {
    if (cluster == 'localhost') {
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
  cluster=$(theid).parentNode.parentNode.id;
  server=$(theid).parentNode.id;
  if (($(server + '_details').style.display == "none") || ($(server + '_details').style.display == "")) {
    cursor_saved = $(theid).style.cursor
    cursor_style($(theid),'wait');
    waitingEffect($(theid),'start');
    var the_url = '/bin/showdetails.cgi?script=' + script + '&cluster=' + cluster + '&server=' + server;
    new Ajax.Request(the_url, {
      onSuccess: function(response) {
     // new Effect.SlideDown(server + '_details', {duration: 0.3});
        $(server + '_details').style.display = "table";
        $(server + '_details').update(response.responseText);
        cursor_style($(theid),cursor_saved);
        waitingEffect($(theid),'stop');
      }
    });
  }
}

waitingEffect = function(theid,action) {
  element = $(theid);
  if (action == 'start') {
    var options    = { },
    oldOpacity = element.getInlineOpacity(),
    transition = Effect.Transitions.linear,
    reverser   = function(pos){
      return 1 - transition((-Math.cos((pos*50*2)*Math.PI)/2) + .5);
    };

    waitingE = new Effect.Opacity(element,
      Object.extend(Object.extend({  duration: 20, from: 0,
        afterFinishInternal: function(effect) { effect.element.setStyle({opacity: oldOpacity}); }
      }, options), {transition: reverser}));
        Object.extend(window.waitingE,{ duration: 0 });
  }
  if (action == 'stop') {
    waitingE.cancel();             
    element.setStyle({opacity: 1.0});
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

cursor_style = function(elem,type) {
  elem.style.cursor = type;
  document.documentElement.style.cursor = type;
}


