---
title: "#SendHeader"
description: "Holds HTTP header information for the send command."
kind: variable
category: result
access: rw
type: string
source: wiki
---

The system variable #sendHeader is a variable that lets you add additional header lines to the post request sent by the send command. Each line must be finished with a $ to mark the end.

```euo
set #sendheader content-type: , #spc , blabla$line2: , #spc , blabla2$
```

- If #sendheader doesn't contain any $ signs at all then no additional lines will be added to the header. Setting #sendheader to $$$ will obviously mess up the outgoing packet so that is not recommended.

- First let's look at EUO default format for http requests:

```euo
; test1
send debugHTTPPost localhost /euo/action.php?getVar=getValue postVar=postValue
halt
```

- Outgoing HTTP request:

```euo
POST /euo/action.php?getvar=getvalue HTTP/1.0 Host: localhost Content-Length: 17 postVar=postValue
```

- Supposing you want your HTTP request to be identifiied as issued by EasyUO by adding the directive "User-Agent: EasyUO #cliVer" to the HTTP header:

```euo
; test2
set #sendHeader User-Agent: , #spc , EasyUO , #spc , #cliVer , $
send debugHTTPPost localhost /euo/action.php?getVar=getValue postVar=postValue
halt
```

- Outgoing HTTP request:

```euo
POST /euo/action.php?getvar=getvalue HTTP/1.0 Host: localhost Content-Length: 17 user-agent: easyuo 4.0.0e postVar=postValue
```

- If you need to specify more than one http directive, you may use the following syntax:

```euo
set #sendHeader User-Agent: , #spc , EasyUO , #spc , #cliVer , $ ,
+ Content-type: , #spc , application/x-www-form-urlencoded$
```

or

```euo
set #sendHeader User-Agent: , #spc , EasyUO , #spc , #cliVer , $
set #sendHeader #sendHeader , Content-type: , #spc , application/x-www-form-urlencoded$
```

- In order to reset #sendHeader, try any of these:

```euo
set #sendHeader N/A
set #sendHeader invalid content
```

:::note
- Two consecutive '$' will break the header structure and are likely to cause inpredictable results!
- You cannot SET a value containing spaces to #sendHeader without 'escaping' them using the #spc constant.
- The value of #sendHeader is converted to lowercase when added to the HTTP header.
- It must be terminated by a single end-of-line symbol '$'. Without this symbol, #sendHeader value will be ignored and not added to the HTTP header.
:::

### Example

```euo
set #sendHeader Content-type: , #spc , application/x-www-form-urlencoded$
```

## Send cookie

```euo
set #sendheader Cookie:Var1=Val1 , #smc , Var2=Val2 $

Example ( send cookie for php session ):
set #sendheader Cookie: , #spc , PHPSESSID= , %sessionid , #smc , #spc , path=/ $
```

## HTTP POST

```euo
set %USERID_POST userid= , %username
set %PASSWD_POST passwd= , %password

set #sendheader Content-Type: , #spc , application/x-www-form-urlencoded , $  ;without headers, no post data
send DebugHTTPPost localhost /login.php !USERID_POST , & , !PASSWD_POST
```
