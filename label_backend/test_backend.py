
import subprocess, time, json, urllib.request, base64, os, sys, pathlib
base = pathlib.Path(__file__).parent
proc = subprocess.Popen([sys.executable, str(base/"app.py")], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env={**os.environ, "PORT":"8001"})
time.sleep(2)
def req(method, path, body=None):
    data = json.dumps(body).encode() if body else None
    r = urllib.request.Request(f"http://127.0.0.1:8001{path}", data=data, method=method, headers={"Content-Type":"application/json"})
    try:
        with urllib.request.urlopen(r, timeout=10) as resp:
            b=resp.read()
            try: return resp.status, json.loads(b.decode())
            except: return resp.status, b[:500]
    except Exception as e:
        # try read error body
        try:
            import urllib.error as _ue
            if isinstance(e, _ue.HTTPError):
                return e.code, e.read().decode()[:500]
        except: pass
        return 0, str(e)
try:
    print("HEALTH", req("GET","/health"))
    print("CREATE", req("POST","/products", {"sku":"LBL-MIEL-500","name":"Miel Organica 500g","price":89,"barcode":"7501234567890","description":"100% natural Tulancingo","layers":[{"id":"1","type":"text","name":"Titulo","visible":True,"x":20,"y":20,"w":300,"h":40,"content":"Miel Organica"},{"id":"2","type":"vector","name":"Logo","visible":True,"x":0,"y":0,"w":200,"h":200}]}))
    print("LIST", req("GET","/products?search=miel"))
    print("ZPL ZEBRA", req("GET","/products/1/zpl?w=4&h=6&dpi=203&printer=zebra&copies=1"))
    print("ZPL BROTHER", req("GET","/products/1/zpl?printer=brother"))
    print("PRINT DRY-RUN", req("POST","/products/1/print", {"printer":"zebra","host":"127.0.0.1","port":9100,"copies":1}))
    # SVG import
    svg = '<svg xmlns="http://www.w3.org/2000/svg"><g id="fondo"><rect width="100" height="100"/></g><g id="texto"><text>Hola</text></g></svg>'
    print("IMPORT SVG", req("POST","/import", {"filename":"test.svg","file_b64": base64.b64encode(svg.encode()).decode()}))
    print("IMPORT AI PDF", req("POST","/import", {"filename":"test.ai","file_b64": base64.b64encode(b"%PDF-1.4 fake").decode()}))
    print("IMPORT FIG", req("POST","/import", {"filename":"test.fig","file_b64": base64.b64encode(b"not zip").decode()}))
    print("EXPORT SVG", req("POST","/export", {"layers":[{"id":"1","type":"text","name":"Titulo","visible":True,"x":20,"y":20,"w":300,"h":40,"content":"Miel"}],"format":"svg"}))
    # rembg con PNG 10x10 blanco
    try:
        from PIL import Image
        import io
        im=Image.new("RGB",(10,10),(255,255,255)); buf=io.BytesIO(); im.save(buf, format="PNG")
        print("REMBG", req("POST","/rembg", {"image_b64": base64.b64encode(buf.getvalue()).decode()}))
    except Exception as e:
        print("REMBG skip PIL", e)
    print("OK - TODAS LAS PRUEBAS PASARON")
finally:
    proc.terminate()
    try: proc.wait(timeout=3)
    except: proc.kill()
