var obj = JSON.parse($response.body);
let url = $request.url;
var cons = "users/info";
if(url.indexOf(cons) != -1)
{
obj.data.VIPExpire= "29/01/9999 00:00:00";
obj.data.isVIP= true;
}
$done({body: JSON.stringify(obj)});
var obj = JSON.parse($response.body);
let url = $request.url;
var cons = "users/info";
if(url.indexOf(cons) != -1)
{
obj.data.VIPExpire= "29/01/9999 00:00:00";
obj.data.isVIP= true;
}
$done({body: JSON.stringify(obj)});

/**
*@supported id 7C92DE22D519
*/

