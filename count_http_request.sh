#!/bin/bash

function count_http_request_log()
{
   local req_log=$1
   #input content: {"_level":"INFO","_timestampUtc":"2018-10-09T05:20:21.4150714Z","_thread":"85","_logger":"Microsoft.Azure.SignalR.HttpRequestLogging","traceId":"0HLHDKFL1FHP2:00000001","ipAddress":"10.3.1.172","method":"GET","url":"https://hznobufferlog.servicedev.signalr.net/client/?hub=benchhub&asrs.op=%2Fsignalrbench&id=C0tpDugSRXP3saOCLbwMHg","headers":{"Connection":["close"],"Authorization":["Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYmYiOjE1MzkwNjI0MjAsImV4cCI6MTUzOTA2NjAyMCwiaWF0IjoxNTM5MDYyNDIwLCJhdWQiOiJodHRwczovL2h6bm9idWZmZXJsb2cuc2VydmljZWRldi5zaWduYWxyLm5ldC9jbGllbnQvP2h1Yj1iZW5jaGh1YiJ9.p5rO9VOZQqHJU1HHDLsfcOF5XLoHrb-afahxupgDP4M"],"Cookie":["SIGNALRROUTE=ac4dc1cd120602c5e0b3ab56b03f0fec2a7a836f"],"Host":["hznobufferlog.servicedev.signalr.net"],"User-Agent":["Microsoft.AspNetCore.Http.Connections.Client/1.0.2-rtm-32055"],"X-Request-ID":["56392aabf23c0d8cc31dcb50820199ed"],"X-Real-IP":["13.66.159.103"],"X-Forwarded-For":["13.66.159.103"],"X-Forwarded-Host":["hznobufferlog.servicedev.signalr.net"],"X-Forwarded-Port":["443"],"X-Forwarded-Proto":["https"],"X-Original-URI":["/client/?hub=benchhub&asrs.op=%2Fsignalrbench&id=C0tpDugSRXP3saOCLbwMHg"],"X-Scheme":["https"],"X-Requested-With":["XMLHttpRequest"]},"statusCode":200,"duration":0.35029,"signature":"p5rO9VOZQqHJU1HHDLsfcOF5XLoHrb-afahxupgDP4M","routeCookie":"ac4dc1cd120602c5e0b3ab56b03f0fec2a7a836f","_eventId":1,"_template":"Request processed.","_eventName":"RequestProcessed","_exception":null} 
   grep Microsoft.Azure.SignalR.HttpRequestLogging $req_log \|
        awk -F , '{print $2}' \| # "_timestampUtc":"2018-10-09T05:22:06.6476933Z"
        awk -F : '{print $2":"$3}' \| 
        tr -d '"'                  \| # 2018-10-09T05:25
        awk '{s[$0]++}END{for (i in s) print i" " s[i]}'|sort -k 1
}

if [ $1 -ne 1 ]
then
  echo "Specify the ASRS log file"
  exit 1
fi

count_http_request_log $1
