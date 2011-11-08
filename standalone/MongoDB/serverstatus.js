var objStatus = db.serverStatus()
print('status|' + objStatus.ok);
print('version|' + objStatus.version);
print('uptime|' + objStatus.uptime);
print('memRes|' + objStatus.mem.resident);
print('memVir|' + objStatus.mem.virtual);
print('memMapped|' + objStatus.mem.mapped);
print('memMappedWJournal|' + objStatus.mem.mappedWithJournal);
print('infoHeapUsage|' + objStatus.extra_info.heap_usage_bytes);

print('connCurrent|' + objStatus.connections.current);
print('connAvailable|' + objStatus.connections.available);
if (objStatus.network) {
  print('netIn|' + objStatus.network.bytesIn);
  print('netOut|' + objStatus.network.bytesOut);
  print('netReqn|' + objStatus.network.numRequests);
}
if (objStatus.opcounters) {
  print('opsTotalInsert|' + objStatus.opcounters.insert);
  print('opsTotalQuery|' + objStatus.opcounters.query);
  print('opsTotalUpdate|' + objStatus.opcounters.update);
  print('opsTotalDelete|' + objStatus.opcounters.delete);
  print('opsTotalGetmore|' + objStatus.opcounters.getmore);
  print('opsTotalCommand|' + objStatus.opcounters.command);
}
if (objStatus.ops) {
  print('opsShardedInsert|' + objStatus.ops.sharded.insert);
  print('opsShardedQuery|' + objStatus.ops.sharded.query);
  print('opsShardedUpdate|' + objStatus.ops.sharded.update);
  print('opsShardedDelete|' + objStatus.ops.sharded.delete);
  print('opsShardedGetmore|' + objStatus.ops.sharded.getmore);
  print('opsShardedCommand|' + objStatus.ops.sharded.command);
  print('opsNotShardedInsert|' + objStatus.ops.notSharded.insert);
  print('opsNotShardedQuery|' + objStatus.ops.notSharded.query);
  print('opsNotShardedUpdate|' + objStatus.ops.notSharded.update);
  print('opsNotShardedDelete|' + objStatus.ops.notSharded.delete);
  print('opsNotShardedGetmore|' + objStatus.ops.notSharded.getmore);
  print('opsNotShardedCommand|' + objStatus.ops.notSharded.command);
}
if (objStatus.globalLock) {
  print('lockRatio|' + objStatus.globalLock.ratio);
  print('lockQueueTotal|' + objStatus.globalLock.currentQueue.total);
  print('lockQueueReaders|' + objStatus.globalLock.currentQueue.readers);
  print('lockQueueWriters|' + objStatus.globalLock.currentQueue.writers);
}
if (objStatus.globalLock.activeClient) {
  print('lockClientsTotal|' + objStatus.globalLock.activeClients.total);
  print('lockClientsReaders|' + objStatus.globalLock.activeClients.readers);
  print('lockClientsWriters|' + objStatus.globalLock.activeClients.writers);
}

