var objStatus = db.serverStatus()
if (objStatus.wiredTiger) {
  printjson(objStatus.wiredTiger);
}
