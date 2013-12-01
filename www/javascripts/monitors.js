init = function() {
  el = document.body;
  el.observe('click', hideAll);
  fillTabs();
  initMonitors('dash', 0);
}

var pu = null;
var updater = null;
var updaterstopped = 1;
var updaterlevel = 0;
var hideblocked = 1;

initMonitors = function(upd,updlevel) {
  hideblocked = 1;
  stopUpdater();
  document.documentElement.style.cursor = 'wait';
  updater = upd;
  startUpdater(updater);
  if (updlevel == 0) {
    $$('#tabs ul li').each(function(value) { if (value.hasClassName('active')) value.removeClassName('active');});
    if ($('view0')) { $('view0').addClassName('active'); }
  } else {
    $$('#views ul li').each(function(value) { if (value.hasClassName('active')) value.removeClassName('active');});
  }
  if ($(updater)) { $(updater).addClassName('active'); }
  document.documentElement.style.cursor = '';
}

startUpdater = function(updater) {
  if (updaterstopped == 1) {
    if (!updater) updater = window.updater;
    //showVars($('messages'), updater + ' stopped');
    pu = new Ajax.PeriodicalUpdater('content', '/bin/' + updater + '.cgi', {
      method: 'get', frequency: 200, decay: 10
    });
    updaterstopped = 0;
    //showVars($('messages'), updater + ' started');
  }
}

stopUpdater = function() {
  if (updaterstopped == 0) {
    if (pu) { pu.stop(); pu = undefined; }
    //showVars($('messages'), updater + ' stopped');
    updaterstopped = 1;
  }
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

    //result_div.scrollTop = result_div.scrollHeight;
  }
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
    hideblocked = 1;
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
  clusterA=cluster.split("|");
  if (clusterA[1]) {
    cluster=clusterA[1] + "/" + clusterA[0];
  }
  server=$(theid).parentNode.id
  serverA=server.split("|");
  if (serverA[1]) {
    server=serverA[1];
  }
  if ($('data_' + theid).style.display == "none") {
    hideblocked = 1;
    stopUpdater(updater);
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
  if (server == '') { server = cluster };
  if (($(server + '_details').style.display == "none") || ($(server + '_details').style.display == "")) {
    hideblocked = 1;
    stopUpdater(updater);
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
  hideblocked = 1;
  stopUpdater(updater);
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
  if (hideblocked == 0) {
    var targ;
    if (!e) var e = this.event;
    if (e.target) targ = e.target;
    else if (e.srcElement) targ = e.srcElement;
//  if (targ.nodeType == 3) 
    targ = targ.parentNode.parentNode;
    $$('div.dhtmlmenu').each(function(value) { if (value.id != targ.id) value.hide(); });
    $$('div.details').each(function(value) { if (value.id != targ.id) value.hide(); });
  if (updaterstopped == 1) startUpdater();
  } else {
    hideblocked = 0;
  }
}

cursor_style = function(elem,type) {
  elem.style.cursor = type;
  document.documentElement.style.cursor = type;
}



