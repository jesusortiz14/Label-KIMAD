import json, urllib.request, time
BASE="http://127.0.0.1:8001"
def req(m,p,b):
    data=json.dumps(b).encode()
    r=urllib.request.Request(BASE+p,data=data,method=m,headers={"Content-Type":"application/json"})
    try:
        with urllib.request.urlopen(r,timeout=10) as resp: return resp.status, json.loads(resp.read().decode())
    except Exception as e:
        import urllib.error as ue
        if isinstance(e,ue.HTTPError): return e.code, json.loads(e.read().decode())
        return 0,{"error":str(e)}
s,ch=req("POST","/auth/eyelock/challenge",{})
print("CHALLENGE:",ch)
alg=ch["algebra"]; gaze=ch["gaze_challenge"]; nonce=ch["nonce"]
print(f"Resuelve: {alg.get('prompt')} -> respuesta {alg['answer']}")
s2,res2=req("POST","/auth/eyelock/validate",{
  "eyelock_id":"EYE-CC8F4O","label_code":"LBL-JESUS001","phrase_6":"miel cafe luna sol rio mar",
  "iris_template":"iris-template-demo","voice_sample":"voz-demo",
  "gaze_sequence":gaze,"blink_count":2,"timestamp_ms":int(time.time()*1000),
  "nonce":nonce,"algebra_challenge":alg,"algebra_answer":alg["answer"]
})
print("VALIDATE ADMIN:",s2,res2)
