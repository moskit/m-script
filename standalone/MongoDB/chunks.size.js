

RegExp.escape = function( text ){
    return text.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, "\\$&");
}


printShardingSizes = function(){
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
    output( "--- Sharding Status --- " );
    output( "  sharding version: " + tojson( configDB.getCollection( "version" ).findOne() ) );

    output( "  shards:" );
    var shards = {};
    configDB.shards.find().forEach(
        function(z){
            shards[z._id] = new Mongo(z.host);
            output( "      " + tojson(z) );
        }
    );

    var saveDB = db;
    output( "  databases:" );
    configDB.databases.find().sort( { name : 1 } ).forEach(
        function(db){
            output( "\t" + tojson(db,"",true) );

            if (db.partitioned){
                configDB.collections.find( { _id : new RegExp( "^" +
                    RegExp.escape(db._id) + "\." ) } ).
                    sort( { _id : 1 } ).forEach( function( coll ){
                        output("\t\t" + coll._id + " chunks:");
                        configDB.chunks.find( { "ns" : coll._id } ).sort( { min : 1 } ).forEach(
                            function(chunk){
                                var mydb = shards[chunk.shard].getDB(db._id)
                                var out = mydb.runCommand({dataSize: coll._id,
                                                           keyPattern: coll.key, 
                                                           min: chunk.min,
                                                           max: chunk.max });
                                delete out.millis;
                                delete out.ok;
                                output( "\t\t\t" + tojson( chunk.min ) + " -->> " + tojson( chunk.max ) +
                                        " on : " + chunk.shard + " " + tojson( out ) );

                            }
                        );
                    }
                )
            }
        }
    );

    print( raw );
}


