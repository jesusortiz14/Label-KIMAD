import hashlib, json, urllib.request
BASE="http://127.0.0.1:8001"
def make_eid(seed):
    h=hashlib.sha256(seed.encode()).hexdigest().upper()
    body5=''.join([c for c in h if c in "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"][:5])
    s=sum(ord(c) for c in body5)%36
    return f"EYE-{body5}{'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'[s]}"
def req(m,path,body):
    data=json.dumps(body).encode()
    r=urllib.request.Request(BASE+path,data=data,method=m,headers={"Content-Type":"application/json"})
    try:
        with urllib.request.urlopen(r,timeout=10) as resp: return resp.status, json.loads(resp.read().decode())
    except Exception as e:
        try:
            import urllib.error as ue
            if isinstance(e,ue.HTTPError): return e.code, json.loads(e.read().decode())
        except: pass
        return 0,{"error":str(e)}
eid_admin=make_eid("jesus-tulancingo")
print("Admin EyeLock:",eid_admin)
print(req("POST","/auth/eyelock/register",{"eyelock_id":eid_admin,"label_code":"LBL-JESUS001","phrase_6":"miel cafe luna sol rio mar","iris_template":"iris-template-demo","voice_sample":"voz-demo","email":"jesus@kimad.mx","role":"admin"}))
eid_user=make_eid("demo-flutter-user")
print("User EyeLock:",eid_user)
print(req("POST","/auth/eyelock/register",{"eyelock_id":eid_user,"label_code":"LBL-DEMO001","phrase_6":"nube flor piedra viento fuego tierra","iris_template":"iris-template-demo","voice_sample":"voz-demo","role":"user"}))
print("=== PARA ENTRAR EN FLUTTER ===")
print(f"Admin: EyeLock={eid_admin} Label=LBL-JESUS001 Frase=miel cafe luna sol rio mar")
print(f"Demo: EyeLock={eid_user} Label=LBL-DEMO001 Frase=nube flor piedra viento fuego tierra")
print("Iris: iris-template-demo / Voz: voz-demo")
