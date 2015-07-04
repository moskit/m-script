db = db.getSiblingDB(cdb);
var objStatus = db[cns].stats();
print('coll_name=' + objStatus.ns);
print('coll_ok=' + objStatus.ok);
print('coll_count=' + objStatus.count);
print('coll_size=' + objStatus.size);
print('coll_storsize=' + objStatus.storageSize);
print('coll_indexsize=' + objStatus.totalIndexSize);
print('coll_sharded=' + objStatus.sharded);
print('coll_capped=' + objStatus.capped);
print('coll_chunks=' + objStatus.nchunks);
var indSizes = objStatus.indexSizes;
var n = 0;
for (var i in indSizes) {
  print('index_size[' + n + ']="' + i + ':' + indSizes[i] + '"');
  n++;
}
