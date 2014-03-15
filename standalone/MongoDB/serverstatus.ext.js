var objStatus = db.serverStatus( { workingSet: 1 } )
if (objStatus.backgroundFlushing) {
  print('lastFlushMs=' + objStatus.backgroundFlushing.last_ms);
  print('avgFlushMs=' + objStatus.backgroundFlushing.average_ms);
}
if (objStatus.cursors) {
  print('totalOpen=' + objStatus.cursors.totalOpen);
}
if (objStatus.dur) {
  print('durCommits=' + objStatus.dur.commits);
  print('durTime=' + objStatus.dur.timeMs.dt);
  print('durWriteJ=' + objStatus.dur.timeMs.writeToJournal);
  print('durWriteD=' + objStatus.dur.timeMs.writeToDataFiles);
}
if (objStatus.indexCounters) {
  print('indexAccesses=' + objStatus.indexCounters.accesses);
  print('indexHits=' + objStatus.indexCounters.hits);
  print('indexMisses=' + objStatus.indexCounters.misses);
}
if (objStatus.opcountersRepl) {
  print('opcountersReplInsert=' + objStatus.opcountersRepl.insert);
  print('opcountersReplQuery=' + objStatus.opcountersRepl.query);
  print('opcountersReplUpdate=' + objStatus.opcountersRepl.update);
  print('opcountersReplDelete=' + objStatus.opcountersRepl.delete);
  print('opcountersReplGetmore=' + objStatus.opcountersRepl.getmore);
  print('opcountersReplCommand=' + objStatus.opcountersRepl.command);
}
if (objStatus.writeBacksQueued) {
  print('writeBackQueued=' + objStatus.writeBacksQueued);
}
if (objStatus.metrics.queryExecutor) {
  print('scanned=' + objStatus.metrics.queryExecutor.scanned);
}
if (objStatus.metrics.operation) {
  print('fastmod=' + objStatus.metrics.operation.fastmod);
  print('idhack=' + objStatus.metrics.operation.idhack);
  print('scanAndOrder=' + objStatus.metrics.operation.scanAndOrder);
}
if (objStatus.metrics.document) {
  print('documentDeleted=' + objStatus.metrics.document.deleted);
  print('documentInserted=' + objStatus.metrics.document.inserted);
  print('documentReturned=' + objStatus.metrics.document.returned);
  print('documentUpdated=' + objStatus.metrics.document.updated);
}
if (objStatus.metrics.record) {
  print('recordMoves=' + objStatus.metrics.record.moves);
}
if (objStatus.metrics.repl.apply) {
  print('replApplyBatchesNum=' + objStatus.metrics.repl.apply.batches.num);
  print('replApplyBatchesMs=' + objStatus.metrics.repl.apply.batches.totalMillis);
  print('replApplyOps=' + objStatus.metrics.repl.apply.ops);
}
if (objStatus.metrics.repl.network) {
  print('replNetworkBytes=' + objStatus.metrics.repl.network.bytes);
  print('replNetworkOps=' + objStatus.metrics.repl.network.ops);
}
if (objStatus.metrics.repl.oplog) {
  print('replOplogInsertNum=' + objStatus.metrics.repl.oplog.insert.num);
  print('replOplogInsertMs=' + objStatus.metrics.repl.oplog.insert.totalMillis);
  print('replOplogInsertBytes=' + objStatus.metrics.repl.oplog.insertBytes);
}
if (objStatus.workingSet) {
  print('pagesInMemory=' + objStatus.workingSet.pagesInMemory);
  print('computationTimeMicros=' + objStatus.workingSet.computationTimeMicros);
  print('overSeconds=' + objStatus.workingSet.overSeconds);
}

