// Label Backend Service - Flutter - KIMAD - PASO 2 ROBUSTO
import 'dart:convert';
import 'package:http/http.dart' as http;

class LabelBackend {
  static const String base = 'http://127.0.0.1:8001';
  static Future<Map<String,dynamic>> health() async {
    final r = await http.get(Uri.parse('$base/health'));
    return jsonDecode(r.body);
  }
  static Future<List<dynamic>> products({String search=''}) async {
    final r = await http.get(Uri.parse('$base/products?search=$search'));
    return jsonDecode(r.body)['products'];
  }
  static Future<Map<String,dynamic>> createProduct(Map<String,dynamic> p) async {
    final r = await http.post(Uri.parse('$base/products'), headers: {'Content-Type':'application/json'}, body: jsonEncode(p));
    return jsonDecode(r.body);
  }
  static Future<Map<String,dynamic>> zpl(int id, {double w=4, double h=6, int dpi=203, String printer='zebra', int copies=1}) async {
    final r = await http.get(Uri.parse('$base/products/$id/zpl?w=$w&h=$h&dpi=$dpi&printer=$printer&copies=$copies'));
    return jsonDecode(r.body);
  }
  static Future<Map<String,dynamic>> printProduct(int id, {String printer='zebra', String host='127.0.0.1', int port=9100, int copies=1, bool cups=false}) async {
    final r = await http.post(Uri.parse('$base/products/$id/print'), headers: {'Content-Type':'application/json'}, body: jsonEncode({'printer':printer,'host':host,'port':port,'copies':copies,'cups':cups}));
    return jsonDecode(r.body);
  }
  static Future<String> rembg(String imageB64) async {
    final r = await http.post(Uri.parse('$base/rembg'), headers: {'Content-Type':'application/json'}, body: jsonEncode({'image_b64': imageB64}));
    return jsonDecode(r.body)['image_b64'];
  }
  static Future<Map<String,dynamic>> importFile(String filename, String fileB64) async {
    final r = await http.post(Uri.parse('$base/import'), headers: {'Content-Type':'application/json'}, body: jsonEncode({'filename':filename,'file_b64':fileB64}));
    return jsonDecode(r.body);
  }
  static Future<Map<String,dynamic>> exportLayers(List layers, String format) async {
    final r = await http.post(Uri.parse('$base/export'), headers: {'Content-Type':'application/json'}, body: jsonEncode({'layers':layers,'format':format}));
    if (format=='svg') return {'svg': r.body};
    return jsonDecode(r.body);
  }
}
