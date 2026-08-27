use admin

try{
    db.createRole(
       {
         role: "interalUseOnlyOplogRestore",
         privileges: [
           { resource: { anyResource: true }, actions: [ "anyAction" ] }
         ],
         roles: []
       }
    )
   
    db.createUser({
      user: "root",
      pwd: "ADMIN_PASSWORD",
      roles: [
        {role: "root", db: "admin"},"__system","interalUseOnlyOplogRestore","backup"
      ]
    })
} catch (err){
    ;
}

use config 
db.runCommand({startSession:1});