var objStatus = db.serverStatus()
if (objStatus.ok == 1) {
  print('version=' + objStatus.version);
  print('uptime=' + objStatus.uptime);
  print('memRes=' + objStatus.mem.resident);
  print('memVir=' + objStatus.mem.virtual);
  print('memMapped=' + objStatus.mem.mapped);
  print('memMappedWJournal=' + objStatus.mem.mappedWithJournal);
  print('infoHeapUsage=' + objStatus.extra_info.heap_usage_bytes);

  print('connCurrent=' + objStatus.connections.current);
  print('connAvailable=' + objStatus.connections.available);
  if (objStatus.network) {
    print('netIn=' + objStatus.network.bytesIn);
    print('netOut=' + objStatus.network.bytesOut);
    print('netReqn=' + objStatus.network.numRequests);
  }
  if (objStatus.opcounters) {
    print('opcountersInsert=' + objStatus.opcounters.insert);
    print('opcountersQuery=' + objStatus.opcounters.query);
    print('opcountersUpdate=' + objStatus.opcounters.update);
    print('opcountersDelete=' + objStatus.opcounters.delete);
    print('opcountersGetmore=' + objStatus.opcounters.getmore);
    print('opcountersCommand=' + objStatus.opcounters.command);
  }
}

