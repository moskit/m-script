RegExp.escape = function( text ){
  return text.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, "\\$&");
}

printShardingSizes = function(shard, sdb, coll){
  configDB = db.getSisterDB('config')

  var version = configDB.getCollection( "version" ).findOne();
  if ( version == null ){
    print( "printShardingSizes : not a shard db!" );
    return;
  }

  var raw = "";
  var output = function(s){
    raw += s + "\n";
  }
  var mydb = db.getSisterDB(sdb)
  
  if (mydb.partitioned){
    configDB.collections.find( { _id : new RegExp( "^" +                     RegExp.escape(sdb) + "\." + coll) } ).forEach(
    function(mycoll) {
      configDB.chunks.find( { "ns" : mycoll._id, "shard" : shard } ).sort( { min : 1 } ).forEach(
        function(chunk){
          var out = mydb.runCommand({dataSize: mycoll._id,
                                     keyPattern: mycoll.key, 
                                     min: chunk.min,
                                     max: chunk.max });
          delete out.millis;
          delete out.ok;
          output( "\t\t\t" + tojson( chunk.min ) + " -->> " + tojson( chunk.max ) +
                  " on : " + chunk.shard + " " + tojson( out ) );
        }
      );
    }
  }
  print( raw );
}

