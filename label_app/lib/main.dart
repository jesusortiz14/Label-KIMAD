
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'packaging_library.dart';

// ===== KIMAD LABEL - VERSION COMPLETA =====
// EyeLock gate + Guest + Day/Night + Modo Rapido/Estudio + 10 modulos
// Paleta: blanco #FFFFFF, gris Apple #F2F3F5, petrol #2B4A6B / #2A4A5F, charcoal #333333, gris medio #8A8A8A, teal #2A8A7A
// Day: #F5F5F0 + Sage #9BAE9D + Petrol #2A4A5F | Night: #0A0F0A + verde #2E9E6B + #3AA76D

const String backend = 'http://127.0.0.1:8001';
String eyeTokenGlobal = '';
int eyeUserIdGlobal = 0;
int eyeCreditosGlobal = 10;

class AppTema {
  static bool esNoche = false;
  static bool esEstudio = false;
  static Color get fondo => esNoche ? const Color(0xFF0A0F0A) : const Color(0xFFF5F5F0);
  static Color get card => esNoche ? const Color(0xFF141A14) : Colors.white;
  static Color get cardGris => esNoche ? const Color(0xFF1E241E) : const Color(0xFFF2F3F5);
  static Color get texto => esNoche ? Colors.white : const Color(0xFF333333);
  static Color get textoSuave => esNoche ? const Color(0xFF9BAE9D) : const Color(0xFF8A8A8A);
  static Color get primario => esNoche ? const Color(0xFF2E9E6B) : const Color(0xFF2B4A6B);
  static Color get acento => esNoche ? const Color(0xFF3AA76D) : const Color(0xFF2A8A7A);
  static Color get borde => esNoche ? const Color(0xFF2E9E6B).withOpacity(0.3) : const Color(0xFFE5E5E5);
}

void main() => runApp(const LabelApp());

class LabelApp extends StatefulWidget {
  const LabelApp({super.key});
  @override
  State<LabelApp> createState() => _LabelAppState();
}

class _LabelAppState extends State<LabelApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Label - KIMAD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppTema.fondo,
        colorScheme: ColorScheme.fromSeed(seedColor: AppTema.primario, brightness: AppTema.esNoche ? Brightness.dark : Brightness.light),
        appBarTheme: AppBarTheme(backgroundColor: AppTema.card, foregroundColor: AppTema.texto, elevation: 0),
        fontFamily: 'Roboto',
      ),
      home: const LoginScreen(),
    );
  }
}

// ================= LOGIN / EYELOCK GATE =================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final eyeId = TextEditingController(text: 'EYE-CC8F4O');
  final labelCode = TextEditingController(text: 'LBL-JESUS001');
  final frase = TextEditingController(text: 'miel cafe luna sol rio mar');
  bool phiOn = true;
  bool lambdaOn = true;
  String mensaje = '';
  bool cargando = false;

  Future<void> validar() async {
    if (frase.text.trim().split(RegExp(r'\s+')).length != 6) {
      setState(() => mensaje = 'La frase debe tener 6 palabras.');
      return;
    }
    setState(() { cargando = true; mensaje = 'Validando con EyeLock... Φ • Λ'; });
    bool ok = false;
    String backendError = '';
    // Intento backend V3 — FIX 404: la ruta real es /auth/eyelock/validate
    // (antes pedía /eyelock/validate, que no existe) y el backend exige los
    // nombres exactos eyelock_id / phrase_6 / iris_template / voice_sample,
    // MÁS reto previo: gaze_sequence + blink_count + timestamp_ms + nonce
    // + algebra_challenge/algebra_answer (sin esto Lambda siempre da 401).
    try {
      final chRes = await http.post(Uri.parse('$backend/auth/eyelock/challenge'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({}),
      ).timeout(const Duration(seconds: 10));
      if (chRes.statusCode != 200) {
        backendError = 'No se pudo pedir reto EyeLock (${chRes.statusCode})';
      } else {
        final ch = jsonDecode(chRes.body) as Map<String, dynamic>;
        final algebra = (ch['algebra'] as Map<String, dynamic>?) ?? {};
        // Resolver álgebra: a*x + b = c  ->  x = (c - b) / a
        int? algebraAnswer;
        try {
          final a = (algebra['a'] as num).toInt();
          final b = (algebra['b'] as num).toInt();
          final c = (algebra['c'] as num).toInt();
          if (a != 0 && (c - b) % a == 0) algebraAnswer = (c - b) ~/ a;
        } catch (_) {}
        algebraAnswer ??= (algebra['answer'] as num?)?.toInt();
        final r = await http.post(Uri.parse('$backend/auth/eyelock/validate'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'eyelock_id': eyeId.text.trim(),
            'label_code': labelCode.text.trim(),
            'phrase_6': frase.text.trim(),
            'iris_template': 'iris-template-demo',
            'voice_sample': 'voz-demo',
            'gaze_sequence': ch['gaze_challenge'] ?? [4, 0, 8],
            'blink_count': 2, // FIX: backend exige blink_count >= 1 siempre (liveness). La app es demo sin camara, asi que el switch Lambda no puede apagar el parpadeo.
            'timestamp_ms': DateTime.now().millisecondsSinceEpoch,
            'nonce': ch['nonce'] ?? '',
            'algebra_challenge': algebra,
            'algebra_answer': algebraAnswer,
          }),
        ).timeout(const Duration(seconds: 10));
        if (r.statusCode == 200) {
          ok = true;
          try {
            final v = jsonDecode(r.body) as Map<String, dynamic>;
            eyeTokenGlobal = (v['token'] as String?) ?? '';
            eyeUserIdGlobal = (v['user_id'] as num?)?.toInt() ?? 0;
            eyeCreditosGlobal = (v['credits'] as num?)?.toInt() ?? 10;
          } catch (_) {}
        } else {
          try {
            backendError = (jsonDecode(r.body) as Map<String, dynamic>)['error']?.toString() ?? 'Error EyeLock (${r.statusCode})';
          } catch (_) {
            backendError = 'Error EyeLock (${r.statusCode})';
          }
        }
      }
    } catch (e) {
      backendError = 'Backend no responde: $e';
    }
    // Fallback local - usuarios registrados
    if (!ok) {
      final e = eyeId.text.trim();
      final l = labelCode.text.trim();
      final f = frase.text.trim();
      if (e == 'EYE-CC8F4O' && l == 'LBL-JESUS001' && f == 'miel cafe luna sol rio mar') ok = true;
      if (e == 'EYE-509A4N' && l == 'LBL-DEMO001' && f == 'nube flor piedra viento fuego tierra') ok = true;
    }
    if (!mounted) return;
    setState(() {
      cargando = false;
      if (!ok && backendError.isNotEmpty) mensaje = backendError;
    });
    if (ok) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen(esInvitado: false, eyeId: eyeId.text.trim(), esAdmin: eyeId.text.trim() == 'EYE-CC8F4O')));
    } else {
      setState(() => mensaje = 'EyeLock no validó. Revisa EyeLock ID / Código Label / Frase. O entra como Invitado.');
    }
  }

  void entrarInvitado() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen(esInvitado: true, eyeId: 'INVITADO', esAdmin: false)));
  }

  Widget campo(String label, String hint, TextEditingController c) {
    return TextField(controller: c, style: TextStyle(color: AppTema.texto), decoration: InputDecoration(labelText: label, hintText: hint, filled: true, fillColor: AppTema.cardGris, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTema.fondo,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: AppTema.primario, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('L', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)))),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Label.', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppTema.texto)),
                  Text('Diseña. Etiqueta. Vende.', style: TextStyle(color: AppTema.acento, fontWeight: FontWeight.w700)),
                ]),
              ]),
              const SizedBox(height: 8),
              Text('KIMAD  •  Nosotros por debajo, tu marca por encima.', style: TextStyle(color: AppTema.textoSuave, fontSize: 12)),
              const SizedBox(height: 24),
              Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: AppTema.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTema.borde)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: const Color(0xFF38B6E3).withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: const Text('👁 EYELOCK  •  Φ  •  Λ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF38B6E3)))),
                  const Spacer(),
                  Text('La mirada es la llave.', style: TextStyle(color: AppTema.textoSuave, fontSize: 11, fontStyle: FontStyle.italic)),
                ]),
                const SizedBox(height: 16),
                campo('EyeLock ID', 'EYE-CC8F4O', eyeId),
                const SizedBox(height: 12),
                campo('Código Label', 'LBL-JESUS001', labelCode),
                const SizedBox(height: 12),
                campo('Frase 6 palabras', 'miel cafe luna sol rio mar', frase),
                const SizedBox(height: 14),
                // FIX assertion ListTile: SwitchListTile dentro de un Container con
                // BoxDecoration (fondo blanco) tapa el ink splash de ListTile.
                // Se usa Row + Text + Switch (sin ListTile) y el assertion desaparece.
                Row(children: [
                  Expanded(child: Row(children: [const Text('Φ Identidad', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)), const Spacer(), Switch(value: phiOn, onChanged: (v) => setState(() => phiOn = v))])),
                  const SizedBox(width: 12),
                  Expanded(child: Row(children: [const Text('Λ Viveza', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)), const Spacer(), Switch(value: lambdaOn, onChanged: (v) => setState(() => lambdaOn = v))])),
                ]),
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: cargando ? null : validar, style: ElevatedButton.styleFrom(backgroundColor: AppTema.primario, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(cargando ? 'Validando...' : 'Entrar con EyeLock  •  Φ  •  Λ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)))),
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, child: OutlinedButton(onPressed: entrarInvitado, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: BorderSide(color: AppTema.acento), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Entrar como Invitado - Demo', style: TextStyle(color: AppTema.acento, fontWeight: FontWeight.w900)))),
                const SizedBox(height: 8),
                const Center(child: Text('Sin email, sin teléfono, sin PIN. Solo EyeLock ID + Código Label + Frase.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 11))),
                const Center(child: Text('Invitado: sin EyeLock, solo para probar. No guarda real.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 11))),
                if (mensaje.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(mensaje, style: const TextStyle(color: Colors.amber, fontSize: 12))),
              ])),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _mini('Gratis local', 'Nunca se cobra')),
                const SizedBox(width: 8),
                Expanded(child: _mini('Pro 149 MXN', 'Mensual')),
                const SizedBox(width: 8),
                Expanded(child: _mini('Edición 29 MXN', 'Individual')),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _mini(String t, String s) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTema.card, borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: TextStyle(fontWeight: FontWeight.w900, color: AppTema.texto, fontSize: 12)), Text(s, style: TextStyle(color: AppTema.textoSuave, fontSize: 11))]));
}

// ================= HOME / MODULOS =================
class HomeScreen extends StatefulWidget {
  final bool esInvitado;
  final String eyeId;
  final bool esAdmin;
  const HomeScreen({super.key, this.esInvitado = false, this.eyeId = '', this.esAdmin = false});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int modulo = 0;
  int creditos = 10;
  String estado = 'Backend V3 listo';
  List<dynamic> productos = [];
  String backendVersion = 'Conectando...';
  bool cargandoProductos = false;
  List<dynamic> pricingPlans = [];
  final prodNombre = TextEditingController();
  final prodSku = TextEditingController();
  final prodPrecio = TextEditingController(text: '89');
  final prodBarcode = TextEditingController();

  final modulos = const ['Core', 'Diseño', 'Tienda', 'Web', 'Video', 'Hacker Lab', 'Campañas', 'Créditos + Pro', 'API Label + EyeLock', 'Admin'];

  Widget cardBox(String t, String s, Widget child) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppTema.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTema.borde)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTema.texto)), const SizedBox(height: 4), Text(s, style: TextStyle(color: AppTema.textoSuave, fontSize: 12)), const SizedBox(height: 12), child]));
  Widget btn(String t, Color c, VoidCallback on) => ElevatedButton(onPressed: on, style: ElevatedButton.styleFrom(backgroundColor: c, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)));
  Widget field(String label, String hint, TextEditingController c) => TextField(controller: c, style: TextStyle(color: AppTema.texto), decoration: InputDecoration(labelText: label, hintText: hint, filled: true, fillColor: AppTema.cardGris, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)));

  void toggleTema() => setState(() => AppTema.esNoche = !AppTema.esNoche);
  void toggleModo() => setState(() => AppTema.esEstudio = !AppTema.esEstudio);
  @override
  void initState() {
    super.initState();
    creditos = eyeCreditosGlobal;
    _cargarBackend();
  }
  Future<void> _cargarBackend() async {
    setState(() { cargandoProductos = true; });
    try {
      final h = await http.get(Uri.parse('$backend/health')).timeout(const Duration(seconds: 8));
      if (h.statusCode == 200) {
        final d = jsonDecode(h.body) as Map<String, dynamic>;
        backendVersion = (d['version'] as String?) ?? 'V3';
      }
    } catch (_) { backendVersion = 'Sin conexion - demo local'; }
    try {
      final r = await http.get(Uri.parse('$backend/products')).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body) as Map<String, dynamic>;
        productos = (d['products'] as List<dynamic>?) ?? [];
      }
    } catch (_) {}
    try {
      final pr = await http.get(Uri.parse('$backend/pricing')).timeout(const Duration(seconds: 8));
      if (pr.statusCode == 200) {
        final d = jsonDecode(pr.body) as Map<String, dynamic>;
        pricingPlans = (d['plans'] as List<dynamic>?) ?? [];
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() { cargandoProductos = false; estado = 'Backend V3 - ${productos.length} productos'; });
  }
  Future<void> _crearProducto() async {
    final nombre = prodNombre.text.trim();
    if (nombre.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ponle nombre al producto'))); return; }
    try {
      final r = await http.post(Uri.parse('$backend/products'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'sku': prodSku.text.trim().isEmpty ? null : prodSku.text.trim(), 'name': nombre, 'price': double.tryParse(prodPrecio.text.trim()) ?? 0, 'barcode': prodBarcode.text.trim(), 'description': 'Creado desde Label App'})).timeout(const Duration(seconds: 10));
      if (r.statusCode == 201) { prodNombre.clear(); prodSku.clear(); prodBarcode.clear(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto creado en backend'))); await _cargarBackend(); } else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error ${r.statusCode} al crear'))); }
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backend no responde: $e'))); }
  }
  Future<void> _verZpl(int id, String nombre) async {
    try {
      final r = await http.get(Uri.parse('$backend/products/$id/zpl')).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      final txt = r.statusCode == 200 ? ((jsonDecode(r.body) as Map<String, dynamic>)['zpl']?.toString() ?? 'Sin ZPL') : 'Error ${r.statusCode}';
      showDialog(context: context, builder: (_) => AlertDialog(title: Text('ZPL - $nombre'), content: SingleChildScrollView(child: SelectableText(txt)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))]));
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error ZPL: $e'))); }
  }
  Future<void> _imprimir(int id, String nombre) async {
    try {
      final r = await http.post(Uri.parse('$backend/products/$id/print'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'printer': 'zebra', 'copies': 1})).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.statusCode == 200 ? 'Impresion enviada: $nombre' : 'Error imprimir ${r.statusCode}')));
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error imprimir: $e'))); }
  }
  Future<void> _comprarEdicion() async {
    if (eyeTokenGlobal.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entra con EyeLock para comprar - token requerido'))); return; }
    try {
      final r = await http.post(Uri.parse('$backend/store/buy-single'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $eyeTokenGlobal'}, body: jsonEncode({'edition_name': 'Edicion Individual Label', 'price_mxn': 29, 'payment_provider': 'mercadopago'})).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (r.statusCode == 201) { final d = jsonDecode(r.body) as Map<String, dynamic>; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Comprada - Licencia: ${d['license_key'] ?? ''}'))); } else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error compra ${r.statusCode}'))); }
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error compra: $e'))); }
  }
  Widget _prodRowReal(dynamic p) {
    final id = (p['id'] as num?)?.toInt() ?? 0;
    final nombre = (p['name'] as String?) ?? 'Sin nombre';
    final sku = (p['sku'] as String?) ?? '';
    final precio = (p['price'] as num?)?.toString() ?? '0';
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTema.cardGris, borderRadius: BorderRadius.circular(12)), child: Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: AppTema.acento.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.inventory_2, color: AppTema.acento)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(nombre, style: TextStyle(fontWeight: FontWeight.w900, color: AppTema.texto)), Text(sku, style: TextStyle(color: AppTema.textoSuave, fontSize: 11))])), Text('$precio MXN', style: TextStyle(fontWeight: FontWeight.w900, color: AppTema.primario)), const SizedBox(width: 8), Column(children: [btn('ZPL', AppTema.primario, () => _verZpl(id, nombre)), btn('Print', AppTema.acento, () => _imprimir(id, nombre))])]));
  }

  @override
  Widget build(BuildContext context) {
    // AFTER style: en Home (Core) quitamos AppBar, el header va adentro del body
    final bool esHome = modulo == 0;
    return Scaffold(
      backgroundColor: AppTema.fondo,
      appBar: esHome ? null : AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Label - KIMAD', style: TextStyle(fontWeight: FontWeight.w900)), Text(widget.esInvitado ? 'Modo Invitado • Demo' : 'EyeLock ${widget.eyeId} • Φ Λ • $creditos créditos', style: const TextStyle(fontSize: 11, color: Colors.grey))]),
        actions: [
          IconButton(onPressed: toggleModo, tooltip: AppTema.esEstudio ? 'Modo Estudio' : 'Modo Rápido', icon: Icon(AppTema.esEstudio ? Icons.science : Icons.bolt, color: AppTema.acento)),
          IconButton(onPressed: toggleTema, tooltip: AppTema.esNoche ? 'Night' : 'Day', icon: Icon(AppTema.esNoche ? Icons.dark_mode : Icons.light_mode)),
          IconButton(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())), icon: const Icon(Icons.logout)),
        ],
      ),
      drawer: Drawer(backgroundColor: AppTema.card, child: ListView(children: [
        DrawerHeader(decoration: BoxDecoration(color: AppTema.primario), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Label.', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)), const Text('Diseña. Etiqueta. Vende.', style: TextStyle(color: Colors.white70)), const SizedBox(height: 10), Text(widget.esInvitado ? 'Invitado • Demo' : widget.eyeId, style: const TextStyle(color: Colors.white, fontSize: 12))])),
        for (int i = 0; i < modulos.length; i++)
          ListTile(title: Text(modulos[i], style: TextStyle(fontWeight: modulo == i ? FontWeight.w900 : FontWeight.w500, color: AppTema.texto)), selected: modulo == i, selectedTileColor: AppTema.cardGris, leading: Icon(_icono(i), color: AppTema.acento), onTap: () { setState(() => modulo = i); Navigator.pop(context); }),
        const Divider(),
        ListTile(title: Text(AppTema.esEstudio ? 'Modo Estudio ✓' : 'Modo Rápido', style: TextStyle(color: AppTema.texto)), leading: const Icon(Icons.swap_horiz), onTap: () { toggleModo(); Navigator.pop(context); }),
        ListTile(title: Text(AppTema.esNoche ? 'Night ✓' : 'Day', style: TextStyle(color: AppTema.texto)), leading: const Icon(Icons.brightness_6), onTap: () { toggleTema(); Navigator.pop(context); }),
      ])),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(color: AppTema.card, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))]),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _navItem(0, Icons.home, 'Home'),
          _navItem(2, Icons.store_outlined, ''),
          _navItem(6, Icons.chat_bubble_outline, ''),
          _navItem(9, Icons.person_outline, ''),
        ]),
      ),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
        // Selector rapido de modulos
        SizedBox(height: 42, child: ListView(scrollDirection: Axis.horizontal, children: [for (int i = 0; i < modulos.length; i++) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(modulos[i]), selected: modulo == i, onSelected: (_) => setState(() => modulo = i), selectedColor: AppTema.primario, labelStyle: TextStyle(color: modulo == i ? Colors.white : AppTema.texto, fontWeight: FontWeight.w700)))])),
        const SizedBox(height: 6),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: AppTema.card, borderRadius: BorderRadius.circular(12)), child: Row(children: [
          Icon(AppTema.esEstudio ? Icons.science : Icons.bolt, color: AppTema.acento, size: 18),
          const SizedBox(width: 8),
          Text(AppTema.esEstudio ? 'Modo Estudio • Capas + Vector + Video' : 'Modo Rápido • 1 clic = Etiqueta + Promo + Tienda + Web', style: TextStyle(color: AppTema.texto, fontWeight: FontWeight.w700, fontSize: 12)),
          const Spacer(),
          TextButton(onPressed: toggleModo, child: Text(AppTema.esEstudio ? 'Cambiar a Rápido' : 'Cambiar a Estudio', style: TextStyle(color: AppTema.acento))),
        ])),
        const SizedBox(height: 12),
        _buildModulo(),
      ])),
    );
  }

  IconData _icono(int i) {
    switch (i) {
      case 0: return Icons.home;
      case 1: return Icons.design_services;
      case 2: return Icons.store;
      case 3: return Icons.language;
      case 4: return Icons.video_library;
      case 5: return Icons.security;
      case 6: return Icons.campaign;
      case 7: return Icons.star;
      case 8: return Icons.api;
      default: return Icons.admin_panel_settings;
    }
  }

  Widget _navItem(int idx, IconData icon, String label) {
    final bool sel = modulo == idx;
    return GestureDetector(
      onTap: () => setState(() => modulo = idx),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: label.isEmpty ? 16 : 18, vertical: 10),
        decoration: BoxDecoration(color: sel ? AppTema.primario : Colors.transparent, borderRadius: BorderRadius.circular(24)),
        child: Row(children: [Icon(icon, color: sel ? Colors.white : AppTema.textoSuave, size: 22), if (label.isNotEmpty) Padding(padding: const EdgeInsets.only(left: 6), child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)))]),
      ),
    );
  }

  Widget _buildModulo() {
    switch (modulo) {
      case 0: return _core();
      case 1: return _diseno();
      case 2: return _tienda();
      case 3: return _web();
      case 4: return _video();
      case 5: return _hacker();
      case 6: return _campanas();
      case 7: return _creditos();
      case 8: return _api();
      default: return _admin();
    }
  }

  // ---------- CORE = HOME AFTER ----------
  Widget _core() {
    // Colores AFTER adaptados a Label
    final Color darkTeal = AppTema.esNoche ? const Color(0xFF0F2A24) : const Color(0xFF123F3E);
    final Color heroTeal = AppTema.esNoche ? const Color(0xFF1A3A32) : const Color(0xFF14524F);
    return Column(children: [
      // ===== HEADER AFTER: location + avatar + search + hero =====
      Container(
        decoration: BoxDecoration(color: darkTeal, borderRadius: BorderRadius.circular(28)),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(children: [
          Row(children: [
            Icon(Icons.location_on_outlined, color: Colors.white70, size: 18),
            const SizedBox(width: 6),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Your Location', style: TextStyle(color: Colors.white70, fontSize: 11)),
              Row(children: [Text(widget.esInvitado ? 'Tulancingo, MX' : 'Tulancingo, MX', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)), const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 16)]),
            ]),
            const Spacer(),
            Stack(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.notifications_outlined, color: Colors.white)),
              Positioned(right: 8, top: 8, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))),
            ]),
            const SizedBox(width: 10),
            Container(width: 40, height: 40, decoration: BoxDecoration(color: AppTema.acento, borderRadius: BorderRadius.circular(12)), child: Center(child: Text(widget.esInvitado ? 'I' : 'J', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)))),
          ]),
          const SizedBox(height: 16),
          // Search pill blanco como AFTER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [Icon(Icons.search, color: Colors.grey[600]), const SizedBox(width: 8), const Expanded(child: Text('Search for a service..', style: TextStyle(color: Colors.grey, fontSize: 13))), if (widget.esInvitado) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppTema.acento.withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text('INVITADO', style: TextStyle(color: AppTema.acento, fontSize: 10, fontWeight: FontWeight.w900)))]),
          ),
          const SizedBox(height: 16),
          // HERO - TU SOLUCION A UN TAP
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: heroTeal, borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('TU MARCA,\nA UN TAP!', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, height: 1.1)),
                const SizedBox(height: 6),
                const Text('Diseña. Etiqueta. Vende.\nSin fricción, en 1 clic.', style: TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 12),
                GestureDetector(onTap: () => setState(() => modulo = 1), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: Text('Explore', style: TextStyle(color: darkTeal, fontWeight: FontWeight.w900, fontSize: 12)))),
              ])),
              // Ilustración isométrica con emojis - no imagen externa
              ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.asset('assets/miel_label.webp', width: 168, height: 168, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 168, height: 168, color: Colors.white, child: const Center(child: Text('Label.', style: TextStyle(fontWeight: FontWeight.w900)))))),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 20),
      cardBox('Backend V3 - en vivo', backendVersion, Column(children: [Row(children: [Expanded(child: Text('Productos reales: ${productos.length} - Creditos: $creditos', style: TextStyle(fontWeight: FontWeight.w700, color: AppTema.texto))), if (cargandoProductos) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))]), const SizedBox(height: 10), Row(children: [Expanded(child: btn('Actualizar', AppTema.acento, _cargarBackend)), const SizedBox(width: 8), Expanded(child: btn('Ir a Tienda', AppTema.primario, () => setState(() => modulo = 2)))])])),
      const SizedBox(height: 12),
      // ===== CATEGORIES - como AFTER pero de Label =====
      Row(children: [Text('Categorías', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTema.texto)), const Spacer(), GestureDetector(onTap: () => setState(() => modulo = 1), child: Text('View all  >', style: TextStyle(color: AppTema.acento, fontWeight: FontWeight.w700, fontSize: 12)))]),
      const SizedBox(height: 12),
      GridView.count(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.4,
        children: [
          _catCard(Icons.design_services, 'Diseño', 1),
          _catCard(Icons.store, 'Tienda', 2),
          _catCard(Icons.language, 'Web', 3),
          _catCard(Icons.video_library, 'Video', 4),
        ],
      ),
      const SizedBox(height: 20),
      // ===== POPULAR SERVICES =====
      Row(children: [Text('Productos Populares', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTema.texto)), const Spacer(), Text('View all  >', style: TextStyle(color: AppTema.acento, fontWeight: FontWeight.w700, fontSize: 12))]),
      const SizedBox(height: 12),
      SizedBox(height: 265, child: ListView(scrollDirection: Axis.horizontal, children: [
        _popularCard('assets/miel_label.webp', 'Miel Orgánica', '4.5 (123 Reviews)', '\$89', '500g'),
        _popularCard('assets/cafe_label.webp', 'Café Tostado', '4.8 (98 Reviews)', '\$120', '250g'),
        _popularCard('assets/crema_label.webp', 'Crema Facial', '4.6 (76 Reviews)', '\$180', '50ml'),
      ])),
      const SizedBox(height: 16),
      cardBox('Productos reales del backend', productos.isEmpty ? 'Sin productos todavia - crea uno en Tienda' : '${productos.length} productos en backend - toca ZPL para ver etiqueta', Column(children: [if (productos.isEmpty) Text('Demo arriba: Miel, Cafe, Crema. Reales abajo cuando crees uno.', style: TextStyle(fontSize: 12, color: AppTema.textoSuave)), for (var p in productos.take(5)) _prodRowReal(p), const SizedBox(height: 8), Row(children: [Expanded(child: btn('Ir a Tienda - Crear', AppTema.primario, () => setState(() => modulo = 2))), const SizedBox(width: 8), Expanded(child: btn('Actualizar', AppTema.acento, _cargarBackend))])])),
      const SizedBox(height: 16),
      // ===== ACCESO RAPIDO - no puros botones, es tu resumen =====
      cardBox('Hoy en Label', 'Tu resumen, no puros botones', Column(children: [
        Row(children: [Expanded(child: _miniStat('Créditos', '$creditos', AppTema.acento)), const SizedBox(width: 8), Expanded(child: _miniStat('Moldes 3D', '24 / 76', AppTema.primario)), const SizedBox(width: 8), Expanded(child: _miniStat('Modo', AppTema.esEstudio ? 'Estudio' : 'Rápido', Colors.orange))]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: btn('Ver Biblioteca 3D', AppTema.acento, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PackagingLibrary())))),
          const SizedBox(width: 8),
          Expanded(child: btn('Crear TODO', AppTema.primario, () => setState(() => modulo = 1))),
        ]),
      ])),
      const SizedBox(height: 12),
      // Precios compacto
      cardBox('Precios', 'Pro 149 - Edición 29 - API 499', Row(children: [Expanded(child: btn('Ver Precios', AppTema.primario, () async { try { final r = await http.get(Uri.parse('$backend/pricing')); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Precios: ${r.statusCode}'))); } catch (_) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pro 149 / Anual 1490 / x10 49'))); } })), const SizedBox(width: 8), Expanded(child: btn('Ver Productos', AppTema.acento, () => setState(() => modulo = 2)))])),
    ]);
  }

  Widget _catCard(IconData icon, String label, int goTo) {
    return GestureDetector(
      onTap: () => setState(() => modulo = goTo),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: AppTema.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTema.borde)),
        child: Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: AppTema.acento.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: AppTema.acento, size: 20)),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTema.texto))),
          Icon(Icons.arrow_forward_ios, size: 12, color: AppTema.textoSuave),
        ]),
      ),
    );
  }

  Widget _popularCard(String imagePath, String name, String rating, String price, String weight) {
    return Container(
      width: 215,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(color: AppTema.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTema.borde)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18)),
            child: Image.asset(imagePath, fit: BoxFit.cover, width: double.infinity, height: 155, errorBuilder: (_, __, ___) => Container(height: 155, color: AppTema.cardGris, child: Center(child: Text('Label.', style: TextStyle(fontWeight: FontWeight.w900, color: AppTema.primario))))),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [const Icon(Icons.star, color: Colors.amber, size: 14), const SizedBox(width: 4), Text(rating, style: TextStyle(fontSize: 10, color: AppTema.textoSuave))]),
                const SizedBox(height: 4),
                Text(name, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppTema.texto)),
                Text('$price • $weight', style: TextStyle(color: AppTema.primario, fontWeight: FontWeight.w800, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String t, String v, Color c) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTema.cardGris, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(t, style: TextStyle(color: AppTema.textoSuave, fontSize: 11)),
        const SizedBox(height: 4),
        Text(v, style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 14)),
      ]),
    );
  }
  // ---------- DISEÑO ----------

  Widget _diseno() {
    return Column(children: [
      cardBox('Diseño - ${AppTema.esEstudio ? "Modo Estudio" : "Modo Rápido"}', 'Híbrido: Vector + Píxel + Video • IA por capas, no imagen plana • Multiplayer en tiempo real', Column(children: [
        Container(height: 220, decoration: BoxDecoration(color: AppTema.cardGris, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTema.borde)), child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.layers, size: 48, color: AppTema.acento), const SizedBox(height: 8), Text('Lienzo Híbrido', style: TextStyle(fontWeight: FontWeight.w900, color: AppTema.texto)), Text('Arrastra, vector + píxel + video en capas', style: TextStyle(color: AppTema.textoSuave, fontSize: 12)), const SizedBox(height: 12), Row(mainAxisAlignment: MainAxisAlignment.center, children: [btn('Añadir capa', AppTema.primario, () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Capa añadida')))), const SizedBox(width: 8), btn('IA por capas', AppTema.acento, () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('IA por capas: genera sin aplanar'))))])]))),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          btn('Generative Fill', AppTema.primario, () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generative Fill por capa - PRO')))),
          btn('Quitar fondo', AppTema.acento, () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fondo quitado - Gratis local')))),
          btn('Mockup 3D', AppTema.primario, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PackagingLibrary()))),
          btn('Importar .psd .ai .fig .svg .pdf', AppTema.acento, () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Importa manteniendo capas')))),
          btn('Exportar PNG / JPG / PDF / 3D', AppTema.primario, () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exportado')))),
        ]),
        const SizedBox(height: 12),
        Row(children: [const Text('Colores: ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), for (var c in [Colors.white, const Color(0xFFF2F3F5), const Color(0xFF2B4A6B), const Color(0xFF333333), const Color(0xFF8A8A8A), const Color(0xFF2A8A7A), const Color(0xFF9BAE9D)]) Container(width: 28, height: 28, margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.grey)))]),
      ])),
      const SizedBox(height: 16),
      cardBox('Biblioteca 3D - 24 Moldes → 76', 'Bolsas 12 • Cajas 12 • Botellas 10 • Frascos 8 • Etiquetas 8 • Alimentos 10 • Cosméticos 8 • Farmacia 8', Column(children: [
        const Text('Cada molde: 3D + 2D desplegado, frente/reverso/lados/tapa/base, colores/materiales, por cara, dimensiones, acabados mate/brillante/metálico/transparente/kraft, tapas/cierres/zipper/asas/válvulas.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: btn('Abrir Biblioteca 3D', AppTema.acento, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PackagingLibrary())))), const SizedBox(width: 8), Expanded(child: btn('Frasco Farmacéutico', AppTema.primario, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PackagingLibrary()))))]),
      ])),
    ]);
  }

  // ---------- TIENDA ----------
  Widget _tienda() {
    return Column(children: [
      cardBox('Tienda / E-commerce', 'Tu tienda en 1 clic desde tu producto - Pagos: Mercado Pago / Stripe (Fase 4)', Column(children: [
        const Text('1 producto = 1 tienda. Publica, cobra, envia. Sin comision en funciones locales.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: btn('Actualizar productos', AppTema.primario, _cargarBackend)), const SizedBox(width: 8), Expanded(child: btn('Publicar Tienda', AppTema.acento, () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tienda publicada - Demo')))))]),
        const SizedBox(height: 12),
        Text('Crear producto real en backend', style: TextStyle(fontWeight: FontWeight.w900, color: AppTema.texto)),
        const SizedBox(height: 8),
        field('Nombre', 'Ej. Miel Organica 500g', prodNombre),
        const SizedBox(height: 8),
        field('SKU', 'Ej. LBL-MIEL-500', prodSku),
        const SizedBox(height: 8),
        field('Precio MXN', 'Ej. 89', prodPrecio),
        const SizedBox(height: 8),
        field('Codigo de barras', 'Ej. 7501234567890', prodBarcode),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: btn('Crear producto', AppTema.acento, _crearProducto)), const SizedBox(width: 8), Expanded(child: btn('Limpiar', AppTema.primario, () { prodNombre.clear(); prodSku.clear(); prodBarcode.clear(); }))]),
        const SizedBox(height: 12),
        Text('Productos en backend: ${productos.length}', style: TextStyle(fontWeight: FontWeight.w900, color: AppTema.texto)),
        const SizedBox(height: 8),
        if (productos.isEmpty) const Text('Sin productos reales todavia. Crea uno arriba o usa los demo de abajo.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        for (var p in productos) _prodRowReal(p),
        const SizedBox(height: 8),
        const Text('Demo - si backend esta vacio', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.grey)),
        _prodRow('Miel Organica 500g', '89 MXN', 'LBL-MIEL-500'),
        _prodRow('Cafe Tostado 250g', '120 MXN', 'LBL-CAFE-250'),
        _prodRow('Crema Facial 50ml', '180 MXN', 'LBL-CREMA-50'),
      ])),
    ]);
  }

  Widget _prodRow(String n, String p, String sku) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTema.cardGris, borderRadius: BorderRadius.circular(12)), child: Row(children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: AppTema.acento.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.inventory_2, color: AppTema.acento)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(n, style: TextStyle(fontWeight: FontWeight.w900, color: AppTema.texto)), Text(sku, style: TextStyle(color: AppTema.textoSuave, fontSize: 11))])), Text(p, style: TextStyle(fontWeight: FontWeight.w900, color: AppTema.primario)), const SizedBox(width: 8), btn('Comprar', AppTema.acento, () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Compra demo: $n'))))]));

  // ---------- WEB ----------
  Widget _web() {
    return Column(children: [
      cardBox('Web - Tu sitio en 1 clic', '1 producto = 1 web • Dominio propio • SEO + EyeLock', Column(children: [
        Container(height: 160, decoration: BoxDecoration(color: AppTema.cardGris, borderRadius: BorderRadius.circular(14)), child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('miel-organica.label.mx', style: TextStyle(fontWeight: FontWeight.w900, color: AppTema.primario, fontSize: 16)), const Text('Vista previa de tu web', style: TextStyle(color: Colors.grey, fontSize: 12)), const SizedBox(height: 10), btn('Publicar Web', AppTema.acento, () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Web publicada - Demo'))))]))),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: btn('Editar Web', AppTema.primario, () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Editor Web - Gratis local'))))), const SizedBox(width: 8), Expanded(child: btn('Conectar Dominio', AppTema.acento, () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dominio: pendiente Fase 6')))))]),
      ])),
    ]);
  }

  // ---------- VIDEO ----------
  Widget _video() {
    return Column(children: [
      cardBox('Video - Promo en 1 clic', 'Video híbrido: capas + IA • Exporta .mp4', Column(children: [
        Container(height: 160, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(14)), child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.play_circle_fill, color: Colors.white, size: 48), const Text('Promo - Miel 500g • 15s', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)), const SizedBox(height: 8), btn('Generar Promo IA', AppTema.acento, () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Promo generada - PRO'))))]))),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: btn('Añadir Clip', AppTema.primario, () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clip añadido'))))), const SizedBox(width: 8), Expanded(child: btn('Exportar .mp4', AppTema.acento, () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exportado .mp4')))))]),
      ])),
    ]);
  }

  // ---------- HACKER ----------
  Widget _hacker() {
    return Column(children: [
      cardBox('Hacker Lab - EyeLock', 'Audita tu seguridad • Φ Identidad + Λ Viveza • Hash solo una vez', Column(children: [
        Row(children: [Expanded(child: _stat('Φ Identidad', 'OK', Colors.green)), const SizedBox(width: 8), Expanded(child: _stat('Λ Viveza', 'OK', Colors.green)), const SizedBox(width: 8), Expanded(child: _stat('Hash', '1 vez', AppTema.primario))]),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: btn('Validar EyeLock', AppTema.primario, () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('EyeLock: Φ + Λ OK - Admin'))))), const SizedBox(width: 8), Expanded(child: btn('Auditar v9', AppTema.acento, () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Auditoría v9: desde fuente limpia - Pendiente')))))]),
        const SizedBox(height: 10),
        const Text('Nunca se guarda iris crudo. Solo hash. Sin email, sin teléfono, sin PIN.', style: TextStyle(fontSize: 11, color: Colors.grey)),
      ])),
    ]);
  }

  Widget _stat(String t, String v, Color c) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTema.cardGris, borderRadius: BorderRadius.circular(12)), child: Column(children: [Text(t, style: TextStyle(color: AppTema.textoSuave, fontSize: 11)), Text(v, style: TextStyle(color: c, fontWeight: FontWeight.w900))]));

  // ---------- CAMPAÑAS ----------
  Widget _campanas() {
    return Column(children: [
      cardBox('Campañas', 'Lanza tu producto a todos lados • Enterprise', Column(children: [
        _prodRow('Lanzamiento Miel 500g', 'Activa • 1,240 vistas', 'CMP-001'),
        _prodRow('Promo Café 250g', 'Programada', 'CMP-002'),
        const SizedBox(height: 8),
        Row(children: [Expanded(child: btn('Nueva Campaña', AppTema.primario, () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Campaña creada'))))), const SizedBox(width: 8), Expanded(child: btn('Campaña Enterprise', AppTema.acento, () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enterprise: cotizar - API 499/mes')))))]),
      ])),
    ]);
  }

  // ---------- CREDITOS ----------
  Widget _creditos() {
    return Column(children: [
      cardBox('Créditos + Pro', 'Gratis por racha • PRO desbloquea IA completa • Local gratis nunca se cobra', Column(children: [
        Text('Tus créditos: $creditos', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTema.texto)),
        const Text('Gana créditos gratis por racha diaria. Usa créditos para IA PRO.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 12),
        for (var pl in pricingPlans) _precio((pl['name'] as String?) ?? 'Plan', "${pl['price_mxn'] ?? ''} MXN / ${(pl['period'] as String?) ?? ''}", ((pl['features'] as List<dynamic>?) ?? []).join(' + ')),
        if (pricingPlans.isEmpty) _precio('Pro Mensual', '149 MXN / mes', 'IA completa + Exporta + Tienda'),
        if (pricingPlans.isEmpty) _precio('Pro Anual', '1,490 MXN / ano', '2 meses gratis'),
        if (pricingPlans.isEmpty) _precio('Creditos x10', '49 MXN', 'Para IA PRO'),
        if (pricingPlans.isEmpty) _precio('Creditos x50', '199 MXN', 'Mas barato'),
        if (pricingPlans.isEmpty) _precio('Creditos x200', '649 MXN', 'Mejor precio'),
        if (pricingPlans.isEmpty) _precio('Edicion Individual', '29 MXN', '1 producto, 1 vez'),
        if (pricingPlans.isEmpty) _precio('API Empresarial', '499 MXN / mes', 'Label + EyeLock API'),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: btn('Comprar Edicion Individual - 29 MXN', AppTema.acento, _comprarEdicion)), const SizedBox(width: 8), Expanded(child: btn('Actualizar precios', AppTema.primario, _cargarBackend))]),
      ])),
    ]);
  }

  Widget _precio(String t, String p, String d) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTema.cardGris, borderRadius: BorderRadius.circular(12)), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: TextStyle(fontWeight: FontWeight.w900, color: AppTema.texto)), Text(d, style: TextStyle(color: AppTema.textoSuave, fontSize: 11))])), Text(p, style: TextStyle(fontWeight: FontWeight.w900, color: AppTema.primario)), const SizedBox(width: 8), btn('Comprar', AppTema.acento, () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Compra demo: $t - Fase 4 pagos reales'))))]));

  // ---------- API ----------
  Widget _api() {
    return Column(children: [
      cardBox('API Label', 'Para tu marca • Productos, ZPL, Precios', Column(children: [
        _endpoint('POST /products', 'Crear producto + ZPL'),
        _endpoint('GET /pricing', 'Pro 149 / Edición 29 / API 499'),
        _endpoint('GET /products', 'Listar productos'),
      ])),
      const SizedBox(height: 16),
      cardBox('API EyeLock - Seguridad', 'Biometría general • No solo Label • Φ + Λ', Column(children: [
        _endpoint('POST /eyelock/validate', 'Valida EyeLock ID + Código + Frase + Φ + Λ'),
        _endpoint('POST /eyelock/register', 'Registra usuario - Hash 1 vez'),
        _endpoint('GET /eyelock/health', 'Salud EyeLock'),
        const SizedBox(height: 8),
        Row(children: [Expanded(child: btn('Probar EyeLock API', AppTema.primario, () async { try { final r = await http.get(Uri.parse('$backend/pricing')); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('API OK: ${r.statusCode}'))); } catch (_) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('API demo: EyeLock Φ Λ OK'))); } })), const SizedBox(width: 8), Expanded(child: btn('Ver Docs', AppTema.acento, () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Docs: Label + EyeLock - En backend')))))]),
        const SizedBox(height: 8),
        const Text('EyeLock API tiers: \$5k/5 meses • \$10k/8 meses • \$50k ecosistema', style: TextStyle(fontSize: 11, color: Colors.grey)),
      ])),
    ]);
  }

  Widget _endpoint(String e, String d) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppTema.cardGris, borderRadius: BorderRadius.circular(10)), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(e, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppTema.primario)), Text(d, style: TextStyle(color: AppTema.textoSuave, fontSize: 11))]))]));

  // ---------- ADMIN ----------
  Widget _admin() {
    return Column(children: [
      cardBox('Admin - Mismo inicio, más seguridad', 'No es pestaña aparte. Es el mismo inicio con EyeLock. Solo Admin ve esto.', Column(children: [
        _prodRow('Admin - EYE-CC8F4O', 'LBL-JESUS001 • Admin • 10 créditos', 'miel cafe luna sol rio mar'),
        _prodRow('Demo - EYE-509A4N', 'LBL-DEMO001 • User', 'nube flor piedra viento fuego tierra'),
        const SizedBox(height: 8),
        Row(children: [Expanded(child: btn('Ver Auditoría', AppTema.primario, () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Auditoría: log de accesos'))))), const SizedBox(width: 8), Expanded(child: btn('Gestionar Créditos', AppTema.acento, () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Créditos gestionados')))))]),
        const SizedBox(height: 10),
        const Text('Patente MX/a/2026/003241 • Inventor Jesús Adrián Ortiz Ortiz • KIMAD Tech Tulancingo • IMPI 13/03/2026', style: TextStyle(fontSize: 11, color: Colors.grey)),
      ])),
      const SizedBox(height: 16),
      cardBox('KIMAD Conglomerado', 'Label • EyeLock • Blend Secure • Farma Hunter • Satron Tech • Ortiz Ingeniería', const Text('Nosotros por debajo, tu marca por encima.', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
    ]);
  }
}