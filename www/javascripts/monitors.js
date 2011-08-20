init = function() {
  initMonitors();
}

initMonitors = function() {

}

showData = function(theid,thetext,action) {
  if ($(theid).style.display == "none") {
    $(theid).innerHTML=thetext;
    Effect.SlideDown(theid, {duration: 0.3});
	}
}


