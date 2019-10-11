var server_list_s = "$SERVER_LIST_S";
var server_list = server_list_s.split(",");
var cfg_id = "$CFG_ID";
var member_list = [];
for (i = 0; i < server_list.length; i++) {
    member_list.push({_id: i, host: server_list[i]});
}
var cfg = {
    _id: cfg_id,
    version: 1,
    members: member_list
}
print("First try to initiate");
var result;
do {
    sleep(5000);
    result = rs.initiate(cfg);
    if(result.ok==0) {
        print("Failed to initiate and retry in 5 seconds");
    }
    if(result.code==23){
        print("already initialized");
        break;
    }
    printjson(result);
} while (result.ok != 1)
// printjson(result);
