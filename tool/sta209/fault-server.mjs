import http from 'node:http';
// Loopback only, no Firebase credentials, no request bodies/headers logged.
let mode='500';
http.createServer((req,res)=>{
 res.setHeader('Access-Control-Allow-Origin','*');res.setHeader('Access-Control-Allow-Headers','authorization,content-type,x-firebase-appcheck');
 if(req.method==='OPTIONS'){res.writeHead(204);res.end();return;}
 if(req.url==='/__timeout'){mode='timeout';res.end(mode);return;}
 if(req.url==='/__500'){mode='500';res.end(mode);return;}
 console.log(`${new Date().toISOString()} ${mode} ${req.url?.split('?')[0]}`);
 if(mode==='timeout'){req.resume();return;}
 res.writeHead(500,{'Content-Type':'application/json'});res.end(JSON.stringify({error:{status:'INTERNAL',message:'STA209 injected function outage'}}));
}).listen(5001,'127.0.0.1',()=>console.log('STA209 fault responder at 127.0.0.1:5001'));
