#!/bin/bash
echo "Pragma: no-cache"
echo "Expires: 0"
echo "Content-Cache: no-cache"
echo "Content-type: text/html"
echo ""

scriptname=${0%.cgi}
scriptname=${scriptname##*/}

echo "<div id=\"views\">"
  echo "<ul id=\"viewsnav\">"
  # view0 is a special ID indicating updaterlevel = 0 in monitors.js
  # that is, clicking it is the same as clicking the corresponding upper tab
  # other buttons IDs become CGI scripts names (with .cgi extension)
    echo "<li class=\"viewsbutton\" id=\"view0\" onClick=\"initMonitors('MongoDB', 0)\">Servers</li>"
    echo "<li class=\"viewsbutton active\" id=\"sharding\" onClick=\"initMonitors('sharding', 1)\">Sharding</li>"
    echo "<li class=\"viewsbutton\" id=\"collections\" onClick=\"initMonitors('collections', 1)\">Collections</li>"
  echo "</ul>"
echo "</div>"


