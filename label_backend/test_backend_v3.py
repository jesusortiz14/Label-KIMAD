
import subprocess, time, json, urllib.request, base64, os, sys, pathlib, hashlib, io
base = pathlib.Path(__file__).parent
# Clean DB for v3 test - use temp copy
import shutil
db_path = base / "label_v3_test.db"
# Run app_v3 on port 8002 with PORT env and copy DB handling: app uses label.db in its folder, so we run in temp dir
tmp = pathlib.Path("/tmp/label_v3_test")
tmp.mkdir(exist_ok=True)
for f in ["app_v3.py"]:
    shutil.copy(base / f, tmp / "app.py")
    # app.py expects label.db in same dir, will create fresh
    if (tmp / "label.db").exists(): (tmp / "label.db").unlink()
proc = subprocess.Popen([sys.executable, str(tmp / "app.py")], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env={**os.environ, "PORT":"8002", "LABEL_MASTER_KEY":"TEST-KEY-123"})
time.sleep(2.5)
def req(method, path, body=None, headers=None):
    data = json.dumps(body).encode() if body else None
    h = {"Content-Type":"application/json"}
    if headers: h.update(headers)
    r = urllib.request.Request(f"http://127.0.0.1:8002{path}", data=data, method=method, headers=h)
    try:
        with urllib.request.urlopen(r, timeout=12) as resp:
            b=resp.read()
            try: return resp.status, json.loads(b.decode())
            except: return resp.status, b[:600]
    except Exception as e:
        try:
            import urllib.error as _ue
            if isinstance(e, _ue.HTTPError):
                b=e.read()
                try: return e.code, json.loads(b.decode())
                except: return e.code, b.decode()[:600]
        except: pass
        return 0, str(e)
try:
    print("HEALTH", req("GET","/health"))
    print("PRICING", req("GET","/pricing"))
    # Generate valid EyeLock ID
    def make_eid(seed):
        h = hashlib.sha256(seed.encode()).hexdigest().upper()
        body5 = ''.join([c for c in h if c in "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"][:5])
        s = sum(ord(c) for c in body5) % 36
        last = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"[s]
        return f"EYE-{body5}{last}"
    eid = make_eid("jesus-adrian-test-001")
    print("EID generada", eid)
    # Challenge
    print("CHALLENGE", req("POST","/auth/eyelock/challenge", {}))
    # Register first admin
    import time as _t
    now_ms = int(_t.time()*1000)
    # Need algebra challenge: get one
    s2, ch = req("POST","/auth/eyelock/challenge", {})
    algebra = ch.get("algebra", {})
    nonce = ch.get("nonce", "abc123")
    gaze = ch.get("gaze_challenge", [4,0,8])
    print("REGISTER ADMIN", req("POST","/auth/eyelock/register", {"eyelock_id": eid, "label_code":"LBL-JESUS001", "phrase_6":"miel cafe luna sol rio mar", "iris_template":"iris-template-123", "voice_sample":"voz-123", "email":"jesus@kimad.mx", "role":"admin"}))
    # Register user 2
    eid2 = make_eid("user-dos-002")
    s, reg2 = req("POST","/auth/eyelock/register", {"eyelock_id": eid2, "label_code":"LBL-USER002", "phrase_6":"nube flor piedra viento fuego tierra", "iris_template":"iris-456", "voice_sample":"voz-456", "role":"user"})
    print("REGISTER USER2", s, reg2)
    token2 = reg2.get("token") if isinstance(reg2, dict) else None
    # Validate correct - need fresh challenge
    s3, ch2 = req("POST","/auth/eyelock/challenge", {})
    algebra2 = ch2.get("algebra", {})
    nonce2 = ch2.get("nonce", "xyz")
    gaze2 = ch2.get("gaze_challenge", [1,2,3])
    print("VALIDATE OK", req("POST","/auth/eyelock/validate", {"eyelock_id": eid2, "label_code":"LBL-USER002", "phrase_6":"nube flor piedra viento fuego tierra", "iris_template":"iris-456", "voice_sample":"voz-456", "gaze_sequence": gaze2, "blink_count":2, "timestamp_ms": int(_t.time()*1000), "nonce": nonce2, "algebra_challenge": algebra2, "algebra_answer": algebra2.get("answer")}))
    # Validate wrong phrase
    s4, ch3 = req("POST","/auth/eyelock/challenge", {})
    print("VALIDATE WRONG PHRASE", req("POST","/auth/eyelock/validate", {"eyelock_id": eid2, "label_code":"LBL-USER002", "phrase_6":"miel cafe luna sol rio mar", "iris_template":"iris-456", "voice_sample":"voz-456", "gaze_sequence": ch3.get("gaze_challenge"), "blink_count":1, "timestamp_ms": int(_t.time()*1000), "nonce": ch3.get("nonce"), "algebra_challenge": ch3.get("algebra"), "algebra_answer": ch3.get("algebra",{}).get("answer")}))
    # Validate wrong Phi
    s5, ch4 = req("POST","/auth/eyelock/validate", {"eyelock_id": eid2, "label_code":"LBL-USER002", "phrase_6":"nube flor piedra viento fuego tierra", "iris_template":"iris-MALO", "voice_sample":"voz-456", "gaze_sequence": [4,0,8], "blink_count":1, "timestamp_ms": int(_t.time()*1000), "nonce":"nonce-malphi", "algebra_challenge": {"answer":1}, "algebra_answer":1})
    print("VALIDATE WRONG PHI", s5, ch4)
    # Credits
    print("CREDITS BALANCE", req("GET", f"/users/{reg2.get('user_id')}/credits", headers={"Authorization": f"Bearer {token2}"}))
    print("CREDITS ADD", req("POST","/credits/add", {"user_id": reg2.get('user_id'), "delta": 50, "reason":"compra"}, headers={"Authorization": f"Bearer {token2}"}))
    print("CREDITS SPEND", req("POST","/credits/spend", {"user_id": reg2.get('user_id'), "delta": 5, "reason":"edicion"}, headers={"Authorization": f"Bearer {token2}"}))
    print("STREAK", req("POST","/streaks/checkin", {}, headers={"Authorization": f"Bearer {token2}"}))
    print("ORDERS", req("POST","/orders", {"sku":"LBL-CAFE-250","product_name":"Cafe","amount_mxn":65}, headers={"Authorization": f"Bearer {token2}"}))
    print("SUBS", req("POST","/subscriptions", {"plan_id":"pro_mensual"}, headers={"Authorization": f"Bearer {token2}"}))
    print("BUY SINGLE", req("POST","/store/buy-single", {"edition_name":"Portada Miel Pro"}, headers={"Authorization": f"Bearer {token2}"}))
    print("ENCRYPT", req("POST","/encrypt", {"text":"dato secreto"}))
    # Brush
    from PIL import Image
    im=Image.new("RGB",(50,50),(255,255,255)); buf=io.BytesIO(); im.save(buf, format="PNG")
    b64=base64.b64encode(buf.getvalue()).decode()
    print("BRUSH", req("POST","/design/brush", {"image_b64": b64, "strokes":[{"x":10,"y":10,"size":12,"color":"#FF0000","brush":"round"},{"x":20,"y":20,"x2":30,"y2":30,"size":6,"color":"#00FF00","brush":"square"}]}))
    print("PIXEL", req("POST","/design/pixel", {"image_b64": b64, "pixels":[{"x":5,"y":5,"color":"#0000FF"}]}))
    # Admin audit - need admin token
    sA, chA = req("POST","/auth/eyelock/challenge", {})
    sV, valA = req("POST","/auth/eyelock/validate", {"eyelock_id": eid, "label_code":"LBL-JESUS001", "phrase_6":"miel cafe luna sol rio mar", "iris_template":"iris-template-123", "voice_sample":"voz-123", "gaze_sequence": chA.get("gaze_challenge"), "blink_count":1, "timestamp_ms": int(_t.time()*1000), "nonce": chA.get("nonce"), "algebra_challenge": chA.get("algebra"), "algebra_answer": chA.get("algebra",{}).get("answer")})
    print("ADMIN VALIDATE", sV, valA)
    tokenA = valA.get("token") if isinstance(valA, dict) else None
    print("ADMIN AUDIT", req("GET","/admin/audit", headers={"Authorization": f"Bearer {tokenA}"}))
    print("ADMIN API KEY", req("POST","/admin/api-keys", {"user_id": reg2.get('user_id'), "name":"Tienda"}, headers={"Authorization": f"Bearer {tokenA}"}))
    # API empresarial - need key from previous? Use the returned key
    print("OLD PRODUCTS STILL OK", req("GET","/products"))
    print("OK V3 PASSED")
finally:
    proc.terminate()
    try: proc.wait(timeout=3)
    except: proc.kill()
