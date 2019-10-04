var server_list_s = "$SHARD_LIST_S";
var shard_id = "$SHARD_ID";
var shard_string = shard_id.concat('\/', server_list_s);
var result;
print("First try to add shard");
do {
    sleep(5000);
    result = sh.addShard(shard_string);
    if (result.ok == 0) {
        print("Failed to add shard and retry in 5 seconds");
    }
    // if (result.code == 23) {
    //     print("already initialized");
    //     break;
    // }
    printjson(result);
} while (result.ok != 1)
// printjson(result);

