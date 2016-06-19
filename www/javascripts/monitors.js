window.onload = function() {
  el = document.body;
  el.observe('click', hideAll);
  fillTabs();
  initMonitors(updater);
}

var query = window.location.search.substring(1);
var vars = query.split("&");
var updater = vars[0];
if (!updater) var updater = 'dash';
var pu;
var updaterstopped = 1;
var hideblocked = 1;

initMonitors = function(updater) {
  var title = document.title;
  document.title = title + " - " + updater;
  hideblocked = 1;
  stopUpdater();
  startUpdater(updater,1);
  var updtab = updater.split('/')[0];
  var updview = updater.split('/')[1];
  setTimeout(function waitforTab() {
    if (document.body.contains($(updtab))) {
      $$('#tabs ul li').each(function(value) { if (value.hasClassName('active')) value.removeClassName('active');});
      $(updtab).addClassName('active');
    } else {
      setTimeout(waitforTab, 100);
    }
  }, 100);

  if (updview) {
    setTimeout(function waitforView() {
      if (document.body.contains($(updater))) {
        $$('#views ul li').each(function(value) { if (value.hasClassName('active')) value.removeClassName('active');});
        $(updater).addClassName('active');
      } else {
        setTimeout(waitforView, 100);
      }
    }, 100);
  } else {
    if ($('view0')) $('view0').addClassName('active');
  }
}

setUpdater = function(updater) {
  window.location.search = '?' + updater;
}

startUpdater = function(updater,preloader) {
  if (updaterstopped == 1) {
    if (preloader == 1) {
      new Ajax.Updater('content', '/bin/preloader.cgi?updater=' + updater, {
        method: 'get', onFailure: function() {
          new Ajax.Updater('content', '/preloaders/default.html', {
            method: 'get'
          });
        }
      });
    }
    pu = new Ajax.PeriodicalUpdater('content', '/bin/' + updater + '.cgi', {
      method: 'get', frequency: 100, decay: 1.5
    });
    updaterstopped = 0;
  }
}

stopUpdater = function() {
  if (updaterstopped == 0) {
    if (pu) { pu.stop(); pu = undefined; }
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
  cluster = $(theid).parentNode.parentNode.id;
  clusterA = cluster.split("|");
  if (clusterA[1]) {
    cluster = clusterA[0] + "/" + clusterA[1];
  }
  server = $(theid).parentNode.id
  serverA = server.split("|");
  if (serverA[1]) {
    if (serverA[2]) {
      server = serverA[2] + "/" + serverA[1];
    } else {
      server = serverA[1];
    }
  }
  theidA = theid.split("|");
  if (theidA[1]) {
    report = theidA[1];
  } else {
    report = theid;
  }
  if ($('data_' + theid).style.display == "none") {
    hideblocked = 1;
    stopUpdater(updater);
    if (server == 'localhost') {
      var the_url = '/bin/getdata.cgi?path=' + base + '/localhost/' + escape(report) + '.html';
    } else {

      var the_url = '/bin/getdata.cgi?path=' + base + '/' + cluster + '/' + server + '/' + escape(report) + '.html';
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
  cluster = $(theid).parentNode.parentNode.id;
  clusterA = cluster.split("|");
  if (clusterA[1]) {
    cluster = clusterA[0] + "/" + clusterA[1];
  }
  server = $(theid).parentNode.id;
  details = server + '_details';
  serverA = server.split("|");
  if (serverA[1]) {
    server = serverA[1];
  }
  if (server == '') { server = cluster };
  if (($(details).style.display == "none") || ($(details).style.display == "")) {
    hideblocked = 1;
    stopUpdater(updater);
    cursor_saved = $(theid).style.cursor
    cursor_style($(theid),'wait');
    waitingEffect($(theid),'start');
    var the_url = '/bin/showdetails.cgi?script=' + script + '&cluster=' + cluster + '&server=' + server;
    new Ajax.Request(the_url, {
      onSuccess: function(response) {
     // new Effect.SlideDown(server + '|' + cluster + '_details', {duration: 0.3});
        $(details).style.display = "table";
        $(details).update(response.responseText);
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
  if (updaterstopped == 1) startUpdater(updater,0);
  } else {
    hideblocked = 0;
  }
}

cursor_style = function(elem,type) {
  elem.style.cursor = type;
  document.documentElement.style.cursor = type;
}



