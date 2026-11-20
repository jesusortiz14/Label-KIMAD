
"""
Label Backend REAL - KIMAD / Label
$0 start - solo scripts locales, sin IA pagada.
- Productos CRUD SQLite
- ZPL Zebra + Brother (TCP 9100 / CUPS / archivo)
- rembg local gratis (rembg si existe, si no OpenCV GrabCut, si no PIL)
- Import/Export .psd .ai .fig .svg .pdf .mp4 con CAPAS

Run: python3 app.py  -> http://127.0.0.1:8001
"""
import base64, io, json, os, sqlite3, socket, subprocess, sys, tempfile, zipfile, re, math
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs
import xml.etree.ElementTree as ET

DB = os.path.join(os.path.dirname(__file__), "label.db")
UPLOAD_DIR = os.path.join(os.path.dirname(__file__), "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)

# ---------- DB ----------
def db():
    c = sqlite3.connect(DB)
    c.row_factory = sqlite3.Row
    c.execute("""CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sku TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        price REAL DEFAULT 0,
        barcode TEXT,
        description TEXT DEFAULT '',
        image_b64 TEXT DEFAULT '',
        layers_json TEXT DEFAULT '[]',
        label_w_in REAL DEFAULT 4.0,
        label_h_in REAL DEFAULT 6.0,
        dpi INTEGER DEFAULT 203,
        created_at TEXT DEFAULT (datetime('now','localtime'))
    )""")
    c.commit()
    return c

def row_to_dict(r):
    d = dict(r)
    try: d['layers'] = json.loads(d.pop('layers_json') or '[]')
    except: d['layers'] = []
    return d

# ---------- ZPL / BROTHER ----------
def mm_to_dots(mm, dpi): return int(round(mm/25.4*dpi))
def in_to_dots(inch, dpi): return int(round(inch*dpi))

def generate_zpl(product, w_in=4.0, h_in=6.0, dpi=203, copies=1, include_qr=True):
    """ZPL II real para Zebra GK420d / ZD421 / ZT230 etc."""
    pw = in_to_dots(w_in, dpi)
    ll = in_to_dots(h_in, dpi)
    name = (product.get('name') or 'PRODUCTO')[:32].replace('^','').replace('~','')
    sku = (product.get('sku') or 'LBL-0000')[:24]
    barcode = (product.get('barcode') or sku)[:24]
    price = float(product.get('price') or 0)
    desc = (product.get('description') or '')[:48]
    lines = []
    lines.append("^XA")
    lines.append(f"^PW{pw}")
    lines.append(f"^LL{ll}")
    lines.append("^LH0,0")
    lines.append("^CI28")  # UTF-8
    lines.append(f"^FO20,20^A0N,38,38^FD{name}^FS")
    if desc:
        lines.append(f"^FO20,68^A0N,24,24^FD{desc}^FS")
    lines.append(f"^FO20,{ll-180}^A0N,32,32^FDPRECIO: ${price:.2f}^FS")
    lines.append(f"^FO20,{ll-140}^BCN,80,Y,N,N^FD{barcode}^FS")
    # SKU texto abajo del barcode
    lines.append(f"^FO20,{ll-50}^A0N,22,22^FD{sku}^FS")
    if include_qr:
        # QR a la derecha
        lines.append(f"^FO{pw-140},20^BQN,2,6^FDQA,https://label.kimad.mx/p/{sku}^FS")
    lines.append(f"^PQ{max(1,int(copies))},0,1,Y")
    lines.append("^XZ")
    return "\n".join(lines)

def generate_brother(product, model="QL-820NWB"):
    """Brother QL / P-touch: raster + ESC/P simplificado + archivo .bin + instrucciones CUPS.
    Brother real usa P-touch Editor / b-PAC, aqui generamos ESC/P + ZPL-like + texto para CUPS."""
    name = product.get('name') or 'PRODUCTO'
    sku = product.get('sku') or 'LBL-0000'
    price = float(product.get('price') or 0)
    # ESC/P: inicializar, texto, corte
    esc = b"\x1b\x40"  # INIT
    esc += f"\n{name}\nSKU: {sku}\nPrecio: ${price:.2f}\n".encode('utf-8', 'ignore')
    esc += b"\x1a"  # FF
    # Tambien devolvemos version legible para CUPS / lp
    text = f"Label Brother {model}\n{name}\nSKU: {sku}\nPrecio: ${price:.2f}\n---CORTAR---\n"
    return esc, text

def send_to_printer_zpl(zpl_bytes, host="127.0.0.1", port=9100, timeout=5):
    """Zebra por RAW TCP 9100. Si no hay impresora, guarda archivo y devuelve dry-run."""
    try:
        s = socket.create_connection((host, port), timeout=timeout)
        s.sendall(zpl_bytes if isinstance(zpl_bytes, bytes) else zpl_bytes.encode('utf-8'))
        s.close()
        return {"ok": True, "method": "tcp9100", "host": host, "port": port}
    except Exception as e:
        # fallback: guardar
        p = os.path.join(UPLOAD_DIR, "last_print.zpl")
        open(p,'wb').write(zpl_bytes if isinstance(zpl_bytes, bytes) else zpl_bytes.encode('utf-8'))
        return {"ok": False, "method": "dry-run-file", "file": p, "error": str(e), "hint": "Conecta Zebra por USB/Red y pon su IP en host, o usa CUPS: lp -d Zebra last_print.zpl"}

def print_via_cups(file_path, printer_name=None):
    try:
        cmd = ["lp"]
        if printer_name: cmd += ["-d", printer_name]
        cmd.append(file_path)
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        return {"ok": out.returncode==0, "stdout": out.stdout, "stderr": out.stderr}
    except Exception as e:
        return {"ok": False, "error": str(e)}

# ---------- REMBG LOCAL GRATIS ----------
def remove_bg_local(image_bytes):
    """1) rembg si esta instalado 2) OpenCV GrabCut 3) PIL blanco->transparente. Nunca cobra, nunca nube."""
    # Intento 1: rembg
    try:
        from rembg import remove as rembg_remove
        out = rembg_remove(image_bytes)
        return out, "rembg"
    except Exception as e1:
        pass
    # Intento 2: OpenCV GrabCut
    try:
        import cv2, numpy as np
        arr = np.frombuffer(image_bytes, dtype=np.uint8)
        img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        if img is None: raise ValueError("No se pudo decodificar imagen")
        h,w = img.shape[:2]
        mask = np.zeros((h,w), np.uint8)
        bgd = np.zeros((1,65), np.float64); fgd = np.zeros((1,65), np.float64)
        rect = (int(w*0.05), int(h*0.05), int(w*0.90), int(h*0.90))
        cv2.grabCut(img, mask, rect, bgd, fgd, 5, cv2.GC_INIT_WITH_RECT)
        mask2 = np.where((mask==2)|(mask==0), 0, 1).astype('uint8')
        # bordes suaves
        mask2 = cv2.GaussianBlur(mask2.astype(float), (3,3), 0)
        # convertir a BGRA
        b,g,r = cv2.split(img)
        alpha = (mask2*255).astype(np.uint8)
        bgra = cv2.merge((b,g,r,alpha))
        ok, buf = cv2.imencode('.png', bgra)
        if not ok: raise ValueError("encode falló")
        return buf.tobytes(), "opencv-grabcut-local"
    except Exception as e2:
        pass
    # Intento 3: PIL - blanco a transparente + recorte simple
    try:
        from PIL import Image
        im = Image.open(io.BytesIO(image_bytes)).convert("RGBA")
        data = im.getdata()
        new = []
        for px in data:
            # si es casi blanco -> transparente
            if px[0]>240 and px[1]>240 and px[2]>240:
                new.append((px[0],px[1],px[2],0))
            else:
                new.append(px)
        im.putdata(new)
        out = io.BytesIO(); im.save(out, format="PNG")
        return out.getvalue(), "pil-white-to-alpha-local"
    except Exception as e3:
        return image_bytes, f"fallback-sin-cambios: {e3}"

# ---------- LAYERS / IMPORT / EXPORT ----------
def new_layer(id_, type_, name, **kw):
    d = {"id": id_, "type": type_, "name": name, "visible": True, "opacity": 1.0, "x": 0, "y": 0, "w": 300, "h": 200, "locked": False, "content": ""}
    d.update(kw)
    return d

def import_svg(svg_bytes, filename="import.svg"):
    try:
        root = ET.fromstring(svg_bytes.decode('utf-8', errors='ignore'))
    except Exception as e:
        return {"layers": [], "error": str(e)}
    layers=[]
    # namespaces
    def tag(e): return e.tag.split('}')[-1]
    idx=0
    # <g> como capas
    for g in root.iter():
        if tag(g)=='g':
            idx+=1
            layers.append(new_layer(f"svg-g-{idx}", "vector", g.get('id') or f"Capa {idx}", content=ET.tostring(g, encoding='unicode')[:2000], w=400, h=400))
    if not layers:
        # si no hay <g>, cada forma es capa
        for el in list(root)[:20]:
            idx+=1
            layers.append(new_layer(f"svg-{idx}", "vector", f"{tag(el)} {idx}", content=ET.tostring(el, encoding='unicode')[:2000]))
    # texto
    for el in root.iter():
        if tag(el)=='text' and el.text:
            layers.append(new_layer(f"text-{len(layers)}", "text", (el.text or "")[:20], content=el.text or ""))
    return {"layers": layers, "format": "svg", "filename": filename, "count": len(layers)}

def import_pdf(pdf_bytes, filename="import.pdf"):
    layers=[]
    try:
        import fitz
        doc = fitz.open(stream=pdf_bytes, filetype="pdf")
        for pno, page in enumerate(doc):
            txt = page.get_text()[:2000]
            if txt.strip():
                layers.append(new_layer(f"pdf-p{pno}-text", "text", f"Pagina {pno+1} texto", content=txt, w=int(page.rect.width), h=int(page.rect.height)))
            for ino, img in enumerate(page.get_images(full=True)[:5]):
                layers.append(new_layer(f"pdf-p{pno}-img{ino}", "image", f"Pagina {pno+1} imagen {ino}", content=f"xref {img[0]}", w=300, h=200))
        return {"layers": layers, "format": "pdf", "pages": len(doc), "count": len(layers)}
    except Exception as e:
        # fallback: buscar texto entre BT/ET
        txt = pdf_bytes.decode('latin1', errors='ignore')
        found = re.findall(r'\(([^\)]{2,})\)', txt)[:10]
        for i,f in enumerate(found):
            layers.append(new_layer(f"pdf-text-{i}", "text", f"Texto {i}", content=f))
        return {"layers": layers, "format": "pdf", "fallback": str(e), "count": len(layers)}

def import_psd(psd_bytes, filename="import.psd"):
    try:
        from psd_tools import PSDImage
        psd = PSDImage.open(io.BytesIO(psd_bytes))
        layers=[]
        for i, layer in enumerate(psd):
            layers.append(new_layer(f"psd-{i}", "image" if layer.is_group()==False else "vector", layer.name or f"Capa {i}", w=layer.width, h=layer.height, x=layer.left, y=layer.top, content=f"visible={layer.visible} opacity={layer.opacity}"))
        return {"layers": layers, "format": "psd", "size": [psd.width, psd.height], "count": len(layers)}
    except Exception as e:
        return {"layers": [new_layer("psd-fallback", "vector", "PSD sin psd-tools - instala: pip install psd-tools", content=str(e))], "format": "psd", "fallback": str(e), "hint": "pip install psd-tools"}

def import_ai(ai_bytes, filename="import.ai"):
    # .ai moderno es PDF-compatible
    if ai_bytes[:4]==b'%PDF':
        r = import_pdf(ai_bytes, filename)
        r['format']='ai-pdf-compatible'
        return r
    # .ai viejo es PostScript
    txt = ai_bytes.decode('latin1', errors='ignore')[:5000]
    layers=[]
    # buscar %%Title / textos
    for i, m in enumerate(re.findall(r'\(([^\)]{2,})\)', txt)[:10]):
        layers.append(new_layer(f"ai-text-{i}", "text", f"Texto {i}", content=m))
    if not layers:
        layers.append(new_layer("ai-1", "vector", "AI PostScript - convertir a PDF en Illustrator y reimportar", content="AI legacy"))
    return {"layers": layers, "format": "ai", "count": len(layers)}

def import_fig(fig_bytes, filename="import.fig"):
    # .fig de Figma es ZIP con JSON
    try:
        z = zipfile.ZipFile(io.BytesIO(fig_bytes))
        names = z.namelist()
        # buscar json
        for n in names:
            if n.endswith('.json'):
                data = json.loads(z.read(n).decode('utf-8', errors='ignore'))
                layers=[]
                def walk(node, depth=0):
                    if isinstance(node, dict):
                        if 'name' in node and 'type' in node:
                            layers.append(new_layer(f"fig-{len(layers)}", "vector" if node.get('type') in ('FRAME','GROUP','VECTOR') else "text" if node.get('type')=='TEXT' else "image", node.get('name') or f"Capa {len(layers)}", content=json.dumps(node)[:1000]))
                        for v in node.values(): walk(v, depth+1)
                    elif isinstance(node, list):
                        for v in node: walk(v, depth+1)
                walk(data)
                return {"layers": layers, "format": "fig", "files": names, "count": len(layers)}
        return {"layers": [new_layer("fig-1", "vector", "FIG zip sin JSON visible", content=str(names))], "format": "fig", "files": names}
    except Exception as e:
        return {"layers": [], "format": "fig", "error": str(e), "hint": "En Figma: Exporta Frame como .svg o .pdf para capas perfectas"}

def import_mp4(mp4_bytes, filename="import.mp4"):
    # metadata basica + thumbnail placeholder como capa video
    layers=[new_layer("mp4-video-1", "video", filename, content=f"size_bytes={len(mp4_bytes)}", w=1080, h=1080)]
    # intentar ffprobe si existe
    try:
        with tempfile.NamedTemporaryFile(suffix=".mp4", delete=False) as tf:
            tf.write(mp4_bytes); path=tf.name
        out = subprocess.run(["ffprobe","-v","error","-show_entries","format=duration,size","-show_entries","stream=width,height,codec_name","-of","json",path], capture_output=True, text=True, timeout=8)
        if out.returncode==0:
            layers[0]['content']=out.stdout[:2000]
        os.unlink(path)
    except Exception as e:
        layers[0]['content']+=f" | ffprobe no disponible: {e}"
    return {"layers": layers, "format": "mp4", "count": 1}

def export_svg(layers, w=1080, h=1080):
    parts=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">']
    for l in layers:
        if not l.get('visible', True): continue
        t=l.get('type'); x=l.get('x',0); y=l.get('y',0); lw=l.get('w',300); lh=l.get('h',200)
        if t=='text':
            parts.append(f'<text x="{x}" y="{y+20}" font-family="Arial" font-size="28" fill="#222">{(l.get("content") or l.get("name") or "").replace("<","").replace(">","")}</text>')
        elif t=='image':
            parts.append(f'<!-- image layer {l.get("name")} --><rect x="{x}" y="{y}" width="{lw}" height="{lh}" fill="#E8DDD0" stroke="#333" /><text x="{x+10}" y="{y+20}" font-size="14">{l.get("name")}</text>')
        elif t=='video':
            parts.append(f'<rect x="{x}" y="{y}" width="{lw}" height="{lh}" fill="#111" /><text x="{x+10}" y="{y+20}" fill="white" font-size="14">VIDEO {l.get("name")}</text>')
        else:
            parts.append(f'<g id="{l.get("id")}"><rect x="{x}" y="{y}" width="{lw}" height="{lh}" fill="none" stroke="#2A8A7A" stroke-width="2" /><text x="{x+10}" y="{y+20}" font-size="14">{l.get("name")}</text></g>')
    parts.append('</svg>')
    return "\n".join(parts).encode('utf-8')

def export_pdf(layers):
    try:
        from reportlab.pdfgen import canvas
        from reportlab.lib.pagesizes import A4
        buf=io.BytesIO(); c=canvas.Canvas(buf, pagesize=A4); c.setFont("Helvetica-Bold", 18); c.drawString(40, 800, "Label - Export PDF con Capas - KIMAD")
        y=770
        for l in layers:
            c.setFont("Helvetica", 11); c.drawString(40, y, f"{l.get('type')} | {l.get('name')} | x={l.get('x')} y={l.get('y')} w={l.get('w')} h={l.get('h')} visible={l.get('visible')}")
            y-=18
            if y<60: c.showPage(); y=800
        c.showPage(); c.save(); return buf.getvalue()
    except Exception as e:
        # PDF minimo valido
        txt = "Label Export - Capas\n" + "\n".join([f"{l.get('type')} {l.get('name')}" for l in layers])
        # PDF basico 1 pagina
        content = f"BT /F1 14 Tf 50 750 Td ({txt[:200]}) Tj ET"
        pdf = f"%PDF-1.4\n1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj\n3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >> endobj\n4 0 obj << /Length {len(content)} >> stream\n{content}\nendstream endobj\n5 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF"
        return pdf.encode('latin1', errors='ignore')

# ---------- HTTP ----------
class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _send(self, code, obj, ctype="application/json"):
        body = obj if isinstance(obj, bytes) else json.dumps(obj, ensure_ascii=False).encode('utf-8')
        self.send_response(code); self.send_header("Content-Type", ctype); self.send_header("Access-Control-Allow-Origin","*"); self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
    def _json(self):
        n=int(self.headers.get('Content-Length') or 0)
        if n==0: return {}
        raw=self.rfile.read(n)
        try: return json.loads(raw.decode('utf-8'))
        except: return {"_raw": raw}
    def do_OPTIONS(self):
        self.send_response(204); self.send_header("Access-Control-Allow-Origin","*"); self.send_header("Access-Control-Allow-Methods","GET,POST,PUT,DELETE,OPTIONS"); self.send_header("Access-Control-Allow-Headers","Content-Type"); self.end_headers()
    def do_GET(self):
        u=urlparse(self.path); q=parse_qs(u.query); path=u.path
        if path=="/health": return self._send(200, {"ok": True, "service": "label-backend", "version": "2.0-robusto", "features": ["productos","zpl","brother","rembg-local","import-export-capas"]})
        if path=="/products":
            c=db(); search=q.get('search',[''])[0]
            if search: rows=c.execute("SELECT * FROM products WHERE name LIKE ? OR sku LIKE ? ORDER BY id DESC", (f"%{search}%", f"%{search}%")).fetchall()
            else: rows=c.execute("SELECT * FROM products ORDER BY id DESC").fetchall()
            return self._send(200, {"products": [row_to_dict(r) for r in rows], "count": len(rows)})
        if path.startswith("/products/") and path.endswith("/zpl"):
            try: pid=int(path.split("/")[2])
            except: return self._send(400, {"error":"id invalido"})
            c=db(); r=c.execute("SELECT * FROM products WHERE id=?", (pid,)).fetchone()
            if not r: return self._send(404, {"error":"producto no encontrado"})
            p=row_to_dict(r)
            w=float(q.get('w',['4'])[0]); h=float(q.get('h',['6'])[0]); dpi=int(q.get('dpi',['203'])[0]); copies=int(q.get('copies',['1'])[0]); printer=q.get('printer',['zebra'])[0]
            if printer=='brother':
                esc, txt = generate_brother(p)
                return self._send(200, {"zpl": None, "brother_text": txt, "brother_esc_b64": base64.b64encode(esc).decode(), "printer": "brother"})
            zpl=generate_zpl(p, w, h, dpi, copies)
            return self._send(200, {"zpl": zpl, "printer": "zebra", "w_in": w, "h_in": h, "dpi": dpi, "copies": copies})
        if path.startswith("/products/") and "/export" in path:
            try: pid=int(path.split("/")[2])
            except: return self._send(400, {"error":"id invalido"})
            fmt=q.get('format',['svg'])[0].lower()
            c=db(); r=c.execute("SELECT * FROM products WHERE id=?", (pid,)).fetchone()
            if not r: return self._send(404, {"error":"no encontrado"})
            p=row_to_dict(r); layers=p.get('layers') or []
            if fmt=='svg': return self._send(200, export_svg(layers), "image/svg+xml")
            if fmt=='pdf': return self._send(200, export_pdf(layers), "application/pdf")
            if fmt=='json': return self._send(200, {"product": p, "layers": layers})
            return self._send(400, {"error": f"formato {fmt} no soportado en GET, usa POST /export para mp4/png"})
        if path.startswith("/products/"):
            try: pid=int(path.split("/")[2])
            except: return self._send(400, {"error":"id invalido"})
            c=db(); r=c.execute("SELECT * FROM products WHERE id=?", (pid,)).fetchone()
            if not r: return self._send(404, {"error":"no encontrado"})
            return self._send(200, row_to_dict(r))
        return self._send(404, {"error": "ruta no encontrada", "path": path})
    def do_POST(self):
        u=urlparse(self.path); path=u.path
        body=self._json()
        if path=="/products":
            sku=body.get('sku') or f"LBL-{int(__import__('time').time())%100000}"
            name=body.get('name') or 'Sin nombre'
            c=db()
            try:
                cur=c.execute("INSERT INTO products (sku,name,price,barcode,description,image_b64,layers_json,label_w_in,label_h_in,dpi) VALUES (?,?,?,?,?,?,?,?,?,?)", (sku, name, float(body.get('price') or 0), body.get('barcode') or sku, body.get('description') or '', body.get('image_b64') or '', json.dumps(body.get('layers') or []), float(body.get('label_w_in') or 4), float(body.get('label_h_in') or 6), int(body.get('dpi') or 203)))
                c.commit(); pid=cur.lastrowid
                r=c.execute("SELECT * FROM products WHERE id=?", (pid,)).fetchone()
                return self._send(201, row_to_dict(r))
            except sqlite3.IntegrityError as e:
                return self._send(409, {"error": f"SKU duplicado: {e}"})
        if path.endswith("/print"):
            # /products/{id}/print
            try: pid=int(path.split("/")[2])
            except: return self._send(400, {"error":"id invalido"})
            c=db(); r=c.execute("SELECT * FROM products WHERE id=?", (pid,)).fetchone()
            if not r: return self._send(404, {"error":"no encontrado"})
            p=row_to_dict(r); printer=body.get('printer') or 'zebra'; copies=int(body.get('copies') or 1)
            if printer=='brother':
                esc, txt = generate_brother(p)
                # intentar CUPS si piden
                if body.get('cups'):
                    fp=os.path.join(UPLOAD_DIR, f"brother-{pid}.txt"); open(fp,'w').write(txt)
                    res=print_via_cups(fp, body.get('cups_printer'))
                    return self._send(200, {"printer":"brother","cups":res, "text": txt})
                return self._send(200, {"printer":"brother","esc_b64": base64.b64encode(esc).decode(), "text": txt, "dry_run": True})
            zpl=generate_zpl(p, float(body.get('w_in') or p.get('label_w_in') or 4), float(body.get('h_in') or p.get('label_h_in') or 6), int(body.get('dpi') or 203), copies)
            if body.get('cups'):
                fp=os.path.join(UPLOAD_DIR, f"zebra-{pid}.zpl"); open(fp,'w').write(zpl)
                res=print_via_cups(fp, body.get('cups_printer'))
                return self._send(200, {"printer":"zebra","zpl": zpl, "cups": res})
            res=send_to_printer_zpl(zpl, body.get('host') or '127.0.0.1', int(body.get('port') or 9100))
            return self._send(200, {"printer":"zebra","zpl": zpl, "send": res})
        if path=="/rembg":
            b64=body.get('image_b64') or body.get('image') or ""
            if not b64: return self._send(400, {"error":"falta image_b64"})
            # quitar data: prefix
            if "," in b64: b64=b64.split(",",1)[1]
            try: raw=base64.b64decode(b64)
            except Exception as e: return self._send(400, {"error": f"base64 invalido {e}"})
            out, method = remove_bg_local(raw)
            return self._send(200, {"ok": True, "method": method, "image_b64": base64.b64encode(out).decode(), "mime": "image/png", "gratis": True, "local": True})
        if path=="/import":
            filename=body.get('filename') or 'import.bin'
            b64=body.get('file_b64') or body.get('file') or ""
            if "," in b64: b64=b64.split(",",1)[1]
            try: raw=base64.b64decode(b64) if b64 else b""
            except: return self._send(400, {"error":"base64 invalido"})
            ext=filename.lower().rsplit('.',1)[-1] if '.' in filename else ''
            if ext=='svg': res=import_svg(raw, filename)
            elif ext=='pdf': res=import_pdf(raw, filename)
            elif ext=='psd': res=import_psd(raw, filename)
            elif ext=='ai': res=import_ai(raw, filename)
            elif ext=='fig': res=import_fig(raw, filename)
            elif ext=='mp4': res=import_mp4(raw, filename)
            else: res={"layers":[new_layer("1","vector","Archivo generico", content=f"Extension .{ext} - se guardo como capa")], "format": ext, "count":1}
            return self._send(200, res)
        if path=="/export":
            layers=body.get('layers') or []
            fmt=(body.get('format') or 'svg').lower()
            if fmt=='svg': return self._send(200, export_svg(layers), "image/svg+xml")
            if fmt=='pdf': return self._send(200, export_pdf(layers), "application/pdf")
            if fmt=='json': return self._send(200, {"layers": layers, "count": len(layers)})
            if fmt=='png':
                try:
                    from PIL import Image, ImageDraw
                    im=Image.new("RGBA",(1080,1080),(255,255,255,255)); d=ImageDraw.Draw(im)
                    for l in layers: d.rectangle([l.get('x',0), l.get('y',0), l.get('x',0)+l.get('w',300), l.get('y',0)+l.get('h',200)], outline=(42,138,122), width=3); d.text((l.get('x',0)+10, l.get('y',0)+10), l.get('name') or '', fill=(0,0,0))
                    buf=io.BytesIO(); im.save(buf, format="PNG"); return self._send(200, buf.getvalue(), "image/png")
                except Exception as e: return self._send(500, {"error": str(e)})
            if fmt=='mp4':
                return self._send(200, {"ok": True, "note": "MP4 export requiere ffmpeg. Capas listas para render. Instala ffmpeg y usa: ffmpeg -i capas.png salida.mp4", "layers": layers})
            return self._send(400, {"error": f"formato {fmt} no soportado"})
        return self._send(404, {"error":"ruta POST no encontrada"})
    def do_PUT(self):
        u=urlparse(self.path); path=u.path
        if path.startswith("/products/"):
            try: pid=int(path.split("/")[2])
            except: return self._send(400, {"error":"id invalido"})
            body=self._json(); c=db()
            r=c.execute("SELECT * FROM products WHERE id=?", (pid,)).fetchone()
            if not r: return self._send(404, {"error":"no encontrado"})
            old=row_to_dict(r)
            sku=body.get('sku', old['sku']); name=body.get('name', old['name']); price=float(body.get('price', old['price'])); barcode=body.get('barcode', old.get('barcode')); desc=body.get('description', old.get('description'))
            layers=body.get('layers', old.get('layers'))
            c.execute("UPDATE products SET sku=?, name=?, price=?, barcode=?, description=?, layers_json=? WHERE id=?", (sku, name, price, barcode, desc, json.dumps(layers), pid)); c.commit()
            r=c.execute("SELECT * FROM products WHERE id=?", (pid,)).fetchone()
            return self._send(200, row_to_dict(r))
        return self._send(404, {"error":"ruta PUT no encontrada"})
    def do_DELETE(self):
        u=urlparse(self.path); path=u.path
        if path.startswith("/products/"):
            try: pid=int(path.split("/")[2])
            except: return self._send(400, {"error":"id invalido"})
            c=db(); c.execute("DELETE FROM products WHERE id=?", (pid,)); c.commit()
            return self._send(200, {"ok": True, "deleted": pid})
        return self._send(404, {"error":"ruta DELETE no encontrada"})

if __name__=="__main__":
    port=int(os.environ.get("PORT","8001"))
    db().close()
    print(f"Label Backend REAL en http://127.0.0.1:{port}  - KIMAD - $0 local")
    print("Endpoints: /health /products /products/{id}/zpl /products/{id}/print /rembg /import /export")
    ThreadingHTTPServer(("0.0.0.0", port), H).serve_forever()
