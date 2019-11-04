var obj = JSON.parse($response.body);
let url = $request.url;
var cons = "users/info";
if(url.indexOf(cons) != -1)
{
obj.data.VIPExpire= "29/01/9999 00:00:00";
obj.data.isVIP= true;
}
$done({body: JSON.stringify(obj)});
/*
Supported id */
FE3CDA93B3D1
