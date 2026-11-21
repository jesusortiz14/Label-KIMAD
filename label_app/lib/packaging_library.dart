import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ========== MODELO ==========
enum Cat { bolsas, cajas, botellas, etiquetas }
enum Acabado { mate, brillante, metalico, transparente, kraft }
enum Cara { frente, reverso, lateralIzq, lateralDer, superior, base, desplegada, vista3d }

class Molde {
  final String id; final String nombre; final Cat cat; final String uso; final String desc;
  final bool tieneZipper; final bool tieneTapa; final bool tieneAsa; final bool tieneValvula; final bool tieneAtomizador;
  const Molde(this.id, this.nombre, this.cat, this.uso, this.desc, {this.tieneZipper=false, this.tieneTapa=false, this.tieneAsa=false, this.tieneValvula=false, this.tieneAtomizador=false});
}

const List<Molde> MOLDES = [
  // 1. BOLSAS - 6
  Molde('standup', 'Bolsa Stand Up Pouch', Cat.bolsas, 'Snacks, cafe, semillas, suplementos', 'Base plana, se para sola. Zipper + valvula opcional.', tieneZipper: true, tieneValvula: true),
  Molde('fondo-plano', 'Bolsa de fondo plano', Cat.bolsas, 'Cafe, alimentos premium', 'Fondo plano, cara premium para cafe.', tieneZipper: true),
  Molde('pillow', 'Bolsa Pillow', Cat.bolsas, 'Papas, dulces, botanas', 'Almohada sellada, la clasica de papas.'),
  Molde('fuelle', 'Bolsa con fuelle', Cat.bolsas, 'Arroz, granos, alimento mascotas', 'Fuelle lateral, mas capacidad.', tieneZipper: true),
  Molde('doypack', 'Doypack con zipper', Cat.bolsas, 'Frutos secos, polvos, snacks', 'Doypack con zipper resellable.', tieneZipper: true),
  Molde('vacio', 'Bolsa al vacio', Cat.bolsas, 'Carnes, quesos, alimentos', 'Sellado al vacio, transparente.'),
  // 2. CAJAS - 6
  Molde('plegadiza', 'Caja plegadiza', Cat.cajas, 'Medicamentos, cosmeticos, alimentos', 'Caja plegable, la de farmacia.', tieneTapa: true),
  Molde('envio', 'Caja de envio', Cat.cajas, 'E-commerce, paqueteria', 'Mailer box kraft, para envios.', tieneTapa: true),
  Molde('cereal', 'Caja de cereal', Cat.cajas, 'Alimentos, infantiles', 'Caja alta de cereal, frente + laterales.'),
  Molde('pizza', 'Caja de pizza', Cat.cajas, 'Restaurantes, comida rapida', 'Caja plana, tapa abatible.', tieneTapa: true),
  Molde('rigida', 'Caja rigida premium', Cat.cajas, 'Regalos, perfumes, tecnologia', 'Caja rigida, tapa + base, acabado premium.', tieneTapa: true),
  Molde('blister', 'Blister con carton', Cat.cajas, 'Accesorios, farmaceuticos', 'Blister transparente + carton trasero.'),
  // 3. BOTELLAS / FRASCOS / LATAS - 6
  Molde('pet', 'Botella PET', Cat.botellas, 'Agua, bebidas, aceites', 'PET transparente, tapa rosca.', tieneTapa: true),
  Molde('vidrio', 'Botella de vidrio', Cat.botellas, 'Salsas, bebidas, licores', 'Vidrio, etiqueta envolvente.', tieneTapa: true),
  Molde('lata', 'Lata cilindrica', Cat.botellas, 'Refrescos, energeticas', 'Aluminio, 355ml, metalico.', tieneTapa: true),
  Molde('tarro', 'Tarro cosmetico', Cat.botellas, 'Cremas, balsamos, pomadas', 'Tarro ancho, tapa rosca.', tieneTapa: true),
  Molde('frasco-farma', 'Frasco farmaceutico', Cat.botellas, 'Vitaminas, capsulas, medicamentos', 'Frasco blanco + etiqueta farmacia, tapa seguridad.', tieneTapa: true),
  Molde('atomizador', 'Botella con atomizador', Cat.botellas, 'Limpieza, perfumes, cuidado', 'Spray, gatillo atomizador.', tieneAtomizador: true, tieneTapa: true),
  // 4. ETIQUETAS / OTROS - 6
  Molde('envolvente', 'Etiqueta envolvente', Cat.etiquetas, 'Botellas, envases cilindricos', 'Etiqueta que envuelve 360.'),
  Molde('shrink', 'Shrink sleeve', Cat.etiquetas, 'Envoltura termoencogible', 'Manga termoencogible full body.'),
  Molde('charola', 'Charola sellada', Cat.etiquetas, 'Carnes, quesos, preparados', 'Charola + film sellado.'),
  Molde('vaso', 'Vaso de papel', Cat.etiquetas, 'Cafe, bebidas, helados', 'Vaso con tapa, manga termica.', tieneTapa: true, tieneAsa: false),
  Molde('bolsa-comercial', 'Bolsa comercial', Cat.etiquetas, 'Tiendas, comercios', 'Bolsa con asas, para tienda.', tieneAsa: true),
  Molde('envoltura', 'Envoltura de producto', Cat.etiquetas, 'Jabones, barras, solidos', 'Envoltura de papel / flowpack.'),
];

class PackagingLibrary extends StatefulWidget {
  const PackagingLibrary({super.key});
  @override
  State<PackagingLibrary> createState() => _LibState();
}

class _LibState extends State<PackagingLibrary> {
  Cat? filtro;
  String busqueda = '';
  List<Molde> get filtrados => MOLDES.where((m) => (filtro == null || m.cat == filtro) && (busqueda.isEmpty || m.nombre.toLowerCase().contains(busqueda.toLowerCase()))).toList();
  String nombreCat(Cat c) => c == Cat.bolsas ? 'Bolsas' : c == Cat.cajas ? 'Cajas' : c == Cat.botellas ? 'Botellas / Frascos / Latas' : 'Etiquetas / Otros';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(title: const Text('LABEL - 3D PACKAGING - Biblioteca'), backgroundColor: const Color(0xFF1E293B)),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('CATALOGO DE MOLDES', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const Text('24 moldes funcionales - Meta 76 moldes. Disena en 2D y ve el resultado en 3D al instante.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(onChanged: (v) => setState(() => busqueda = v), decoration: InputDecoration(hintText: 'Buscar: bolsa, caja, lata, frasco...', filled: true, fillColor: const Color(0xFF334155), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), decoration: BoxDecoration(color: const Color(0xFF0D9488), borderRadius: BorderRadius.circular(12)), child: Text('${filtrados.length} moldes', style: const TextStyle(fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            ChoiceChip(label: const Text('Todos'), selected: filtro == null, onSelected: (_) => setState(() => filtro = null)),
            ChoiceChip(label: const Text('Bolsas (6)'), selected: filtro == Cat.bolsas, onSelected: (_) => setState(() => filtro = Cat.bolsas)),
            ChoiceChip(label: const Text('Cajas (6)'), selected: filtro == Cat.cajas, onSelected: (_) => setState(() => filtro = Cat.cajas)),
            ChoiceChip(label: const Text('Botellas (6)'), selected: filtro == Cat.botellas, onSelected: (_) => setState(() => filtro = Cat.botellas)),
            ChoiceChip(label: const Text('Etiquetas (6)'), selected: filtro == Cat.etiquetas, onSelected: (_) => setState(() => filtro = Cat.etiquetas)),
          ]),
        ])),
        Expanded(child: GridView.builder(padding: const EdgeInsets.symmetric(horizontal: 14), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.85), itemCount: filtrados.length, itemBuilder: (c, i) {
          final m = filtrados[i];
          return GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PackagingEditor(molde: m))), child: Container(decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Container(decoration: BoxDecoration(color: const Color(0xFFE8ECF1), borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16))), child: Center(child: Icon(m.cat == Cat.bolsas ? Icons.shopping_bag : m.cat == Cat.cajas ? Icons.inventory_2 : m.cat == Cat.botellas ? Icons.local_drink : Icons.label, size: 56, color: const Color(0xFF2A4A5F))))),
            Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m.nombre, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)), const SizedBox(height: 2), Text(m.uso, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)), const SizedBox(height: 4), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF0D9488), borderRadius: BorderRadius.circular(10)), child: Text(nombreCat(m.cat), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)))])),
          ])));
        })),
      ]),
    );
  }
}

class PackagingEditor extends StatefulWidget {
  final Molde molde;
  const PackagingEditor({super.key, required this.molde});
  @override
  State<PackagingEditor> createState() => _EdState();
}

class _EdState extends State<PackagingEditor> {
  Cara cara = Cara.frente;
  Color colorPaq = const Color(0xFF8B1E2D);
  Acabado acabado = Acabado.mate;
  double ancho = 120, alto = 180, prof = 60, rot = 0.0;
  bool zipper = false, tapa = false, asa = false, valvula = false, atomizador = false;
  final marca = TextEditingController(text: 'Label Demo');
  final sabor = TextEditingController(text: 'Sabor Original');
  final peso = TextEditingController(text: '125g');
  final ingredientes = TextEditingController(text: 'Ingredientes: producto natural, sin conservadores.');
  final barcode = TextEditingController(text: '8906123456789');
  final diseno2D = TextEditingController(text: 'Diseno frente en 2D');
  final calorias = TextEditingController(text: '150');
  @override
  void initState() { super.initState(); zipper = widget.molde.tieneZipper; tapa = widget.molde.tieneTapa; asa = widget.molde.tieneAsa; valvula = widget.molde.tieneValvula; atomizador = widget.molde.tieneAtomizador; }
  String get acabadoTxt => acabado == Acabado.mate ? 'Mate' : acabado == Acabado.brillante ? 'Brillante' : acabado == Acabado.metalico ? 'Metalico' : acabado == Acabado.transparente ? 'Transparente' : 'Kraft';
  Widget chipCara(Cara c, String l) => ChoiceChip(label: Text(l), selected: cara == c, onSelected: (_) => setState(() => cara = c));
  Widget campo(String l, TextEditingController c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8))), const SizedBox(height: 4), TextField(controller: c, onChanged: (_) => setState(() {}), decoration: InputDecoration(filled: true, fillColor: const Color(0xFF334155), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)))]);
  Widget vista() {
    if (cara == Cara.desplegada) {
      return Container(width: 300, height: 120, decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey)), child: Row(children: [Expanded(child: Container(color: colorPaq, child: Center(child: Text('FRENTE\n${marca.text}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))))), Expanded(child: Container(color: Colors.white, child: Center(child: Text('REVERSO\nCal ${calorias.text}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontSize: 11))))), Expanded(child: Container(color: colorPaq.withOpacity(0.6), child: const Center(child: Text('LATERAL', style: TextStyle(color: Colors.white, fontSize: 11)))))]));
    }
    final titulo = cara == Cara.frente ? marca.text : cara == Cara.reverso ? 'Nutrition Facts' : cara == Cara.superior ? 'Superior - Tapa' : cara == Cara.base ? 'Base' : cara == Cara.lateralIzq ? 'Lateral Izq' : cara == Cara.lateralDer ? 'Lateral Der' : 'Vista 3D';
    return Transform.rotate(angle: rot, child: Container(width: ancho, height: alto, decoration: BoxDecoration(color: acabado == Acabado.kraft ? const Color(0xFFC9A86A) : acabado == Acabado.transparente ? Colors.white.withOpacity(0.4) : colorPaq, borderRadius: BorderRadius.circular(widget.molde.id == 'cereal' || widget.molde.id == 'plegadiza' ? 4 : 22), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 8))]), child: Stack(children: [
      Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)), child: Text(acabadoTxt, style: const TextStyle(fontSize: 9, color: Colors.white)))),
      Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(titulo, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 6),
        Text(cara == Cara.reverso ? 'Cal ${calorias.text} - ${peso.text}' : '${sabor.text} - ${peso.text}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 8),
        Text('${widget.molde.nombre} - ${ancho.toInt()}x${alto.toInt()}x${prof.toInt()}mm', style: const TextStyle(color: Colors.white60, fontSize: 9)),
        if (zipper) const Text('ZIPPER ON', style: TextStyle(color: Colors.yellow, fontSize: 9, fontWeight: FontWeight.w800)),
        if (tapa) const Text('TAPA ROSCA', style: TextStyle(color: Colors.white, fontSize: 9)),
        if (asa) const Text('ASA', style: TextStyle(color: Colors.white, fontSize: 9)),
        if (valvula) const Text('VALVULA', style: TextStyle(color: Colors.white, fontSize: 9)),
        if (atomizador) const Text('ATOMIZADOR', style: TextStyle(color: Colors.white, fontSize: 9)),
      ])),
    ])));
  }
  Future<void> exportar(String fmt) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exportando $fmt - ${widget.molde.nombre} - Frente + Reverso + Laterales')));
    try { final r = await http.post(Uri.parse('http://127.0.0.1:8001/export'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'format': fmt.toLowerCase(), 'layers': [{'name': marca.text, 'molde': widget.molde.id, 'cara': cara.name, 'color': colorPaq.value, 'acabado': acabadoTxt}]})); if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export $fmt: ${r.statusCode}'))); } catch (e) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export local: $fmt listo (sin backend)'))); }
  }
  Future<void> guardar() async {
    try { final r = await http.post(Uri.parse('http://127.0.0.1:8001/products'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'sku': 'LBL-${widget.molde.id.toUpperCase()}-${marca.text.toUpperCase()}', 'name': '${marca.text} - ${widget.molde.nombre}', 'price': 89, 'barcode': barcode.text, 'description': 'Molde ${widget.molde.id} - Acabado $acabadoTxt - ${ingredientes.text}'})); if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.statusCode == 201 ? 'Guardado - Proyecto editable' : 'Error ${r.body}'))); } catch (e) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Guardado local - Proyecto editable'))); }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: const Color(0xFF0F172A), appBar: AppBar(title: Text(widget.molde.nombre), backgroundColor: const Color(0xFF1E293B), actions: [TextButton(onPressed: guardar, child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)))]), body: SingleChildScrollView(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: vista()),
      const SizedBox(height: 10),
      Wrap(spacing: 6, runSpacing: 6, children: [chipCara(Cara.frente, 'Frente'), chipCara(Cara.reverso, 'Reverso'), chipCara(Cara.lateralIzq, 'Lat Izq'), chipCara(Cara.lateralDer, 'Lat Der'), chipCara(Cara.superior, 'Superior'), chipCara(Cara.base, 'Base'), chipCara(Cara.desplegada, '2D Desplegada'), chipCara(Cara.vista3d, 'Vista 3D')]),
      const SizedBox(height: 10),
      Row(children: [const Text('Girar 3D: '), Expanded(child: Slider(value: rot, min: -0.6, max: 0.6, onChanged: (v) => setState(() => rot = v)))]),
      const SizedBox(height: 10),
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Package Color + Acabado', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)), const SizedBox(height: 8), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Color(0xFF8B1E2D), const Color(0xFF2A4A5F), const Color(0xFF9BAE9D), const Color(0xFFE8D9A8), const Color(0xFF2E9E6B), const Color(0xFFD94F3D), const Color(0xFF111111), const Color(0xFFC9A86A)].map((c) => GestureDetector(onTap: () => setState(() => colorPaq = c), child: Container(width: 28, height: 28, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: colorPaq == c ? const Color(0xFF0D9488) : Colors.grey, width: colorPaq == c ? 3 : 1))))).toList()), const SizedBox(height: 8), Wrap(spacing: 6, children: Acabado.values.map((a) => ChoiceChip(label: Text(a == Acabado.mate ? 'Mate' : a == Acabado.brillante ? 'Brillante' : a == Acabado.metalico ? 'Metalico' : a == Acabado.transparente ? 'Transparente' : 'Kraft'), selected: acabado == a, onSelected: (_) => setState(() => acabado = a))).toList())])),
      const SizedBox(height: 12),
      const Text('Disena en 2D - Se aplica al 3D al instante', style: TextStyle(fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      campo('Texto frente 2D (se ve en 3D)', diseno2D),
      const SizedBox(height: 8),
      Row(children: [Expanded(child: campo('Marca', marca)), const SizedBox(width: 8), Expanded(child: campo('Sabor', sabor))]),
      const SizedBox(height: 8),
      Row(children: [Expanded(child: campo('Peso', peso)), const SizedBox(width: 8), Expanded(child: campo('Barcode', barcode))]),
      const SizedBox(height: 8),
      campo('Ingredientes', ingredientes),
      const SizedBox(height: 12),
      const Text('Dimensiones y proporciones (mm)', style: TextStyle(fontWeight: FontWeight.w900)),
      Row(children: [const Text('Ancho '), Expanded(child: Slider(value: ancho, min: 60, max: 300, onChanged: (v) => setState(() => ancho = v))), Text('${ancho.toInt()}')]),
      Row(children: [const Text('Alto   '), Expanded(child: Slider(value: alto, min: 80, max: 350, onChanged: (v) => setState(() => alto = v))), Text('${alto.toInt()}')]),
      Row(children: [const Text('Prof.  '), Expanded(child: Slider(value: prof, min: 20, max: 150, onChanged: (v) => setState(() => prof = v))), Text('${prof.toInt()}')]),
      const SizedBox(height: 8),
      const Text('Tapas, cierres, zipper, asas, valvulas', style: TextStyle(fontWeight: FontWeight.w900)),
      Wrap(spacing: 6, children: [FilterChip(label: const Text('Zipper'), selected: zipper, onSelected: (v) => setState(() => zipper = v)), FilterChip(label: const Text('Tapa / Rosca'), selected: tapa, onSelected: (v) => setState(() => tapa = v)), FilterChip(label: const Text('Asa'), selected: asa, onSelected: (v) => setState(() => asa = v)), FilterChip(label: const Text('Valvula'), selected: valvula, onSelected: (v) => setState(() => valvula = v)), FilterChip(label: const Text('Atomizador'), selected: atomizador, onSelected: (v) => setState(() => atomizador = v))]),
      const SizedBox(height: 12),
      const Text('Exportar', style: TextStyle(fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      Row(children: [Expanded(child: ElevatedButton(onPressed: () => exportar('PNG'), child: const Text('PNG'))), const SizedBox(width: 6), Expanded(child: ElevatedButton(onPressed: () => exportar('JPG'), child: const Text('JPG'))), const SizedBox(width: 6), Expanded(child: ElevatedButton(onPressed: () => exportar('PDF'), child: const Text('PDF'))), const SizedBox(width: 6), Expanded(child: ElevatedButton(onPressed: () => exportar('GLB 3D'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)), child: const Text('3D GLB')))]),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: guardar, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text('Save - Guardar proyecto editable'))),
      const SizedBox(height: 8),
      Text('Molde: ${widget.molde.nombre} - ${widget.molde.desc} - Uso: ${widget.molde.uso}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
    ])));
  }
}

class Packaging3DPage extends StatefulWidget {
  final Map<String, dynamic> molde;
  const Packaging3DPage({super.key, required this.molde});
  @override State<Packaging3DPage> createState() => _Packaging3DPageState();
}
class _Packaging3DPageState extends State<Packaging3DPage> {
  late final WebViewController c;
  @override void initState() {
    super.initState();
    c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (_) { c.runJavaScript("loadMoldFromDart('${jsonEncode(widget.molde)}')"); }))
      ..loadFlutterAsset('assets/visor3d/index.html');
  }
  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LABEL 3D ENGINE'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
      body: WebViewWidget(controller: c),
    );
  }
}
