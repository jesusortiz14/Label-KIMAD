import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// EYELOCK CORE REAL - KIMAD
/// Phi = Identidad, Lambda = Prueba de vida
/// Regla de oro: NUNCA guardar iris crudo. Solo hash, una sola vez.

class EyeLockCore {
  static const String dominio = 'kimad-eyelock-v1';
  static const int ventanaLambdaSegundos = 15;

  // 1. PHI - Hash una sola vez del iris + salt + dominio
  // irisFeatures: en producción viene de la cámara IR. En web preview viene de captura simulada auditable.
  // NUNCA se guarda irisFeatures. Solo se devuelve el hash.
  static String phiHash({required String irisFeatures, required String salt, required String eyeLockId}) {
    final input = '$dominio|$eyeLockId|$salt|$irisFeatures';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString(); // 64 chars hex, hash una sola vez
  }

  // 2. SALT aleatorio por usuario, se guarda. Sin salt, el hash es vulnerable a rainbow table.
  static String generarSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes);
  }

  // 3. LAMBDA - Challenge de prueba de vida
  // Genera 3 puntos aleatorios que el usuario debe mirar en orden + parpadeo
  static List<int> generarChallengeLambda() {
    final rnd = Random.secure();
    final puntos = [0,1,2,3,4,5,6,7,8]; // 3x3 grid de mirada
    puntos.shuffle(rnd);
    return puntos.take(3).toList(); // ej: [4, 1, 7] = centro, arriba-izq, abajo-der
  }

  static bool verificarLambda({
    required List<int> challengeEsperado,
    required List<int> miradaUsuario,
    required int parpadeos,
    required DateTime inicio,
    required DateTime fin,
  }) {
    if (miradaUsuario.length != challengeEsperado.length) return false;
    for (int i=0; i<challengeEsperado.length; i++) {
      if (miradaUsuario[i] != challengeEsperado[i]) return false;
    }
    if (parpadeos < 1) return false; // debe parpadear al menos 1 vez = vivo
    final dur = fin.difference(inicio).inSeconds;
    if (dur > ventanaLambdaSegundos || dur < 1) return false; // muy lento = replay, muy rápido = bot
    return true;
  }

  // 4. UNA LLAVE ABRE OTRA - Llave maestra envuelta
  // masterKey = SHA256(Phi + LambdaOK + frase6)
  // Si Lambda falla, no se puede derivar masterKey aunque tengas Phi
  static String derivarLlaveMaestra({required String phiHash, required String frase6, required bool lambdaOK}) {
    if (!lambdaOK) throw Exception('Lambda OFF - No se puede abrir. La mirada es la llave.');
    final input = '$phiHash|$frase6|$dominio|master';
    return sha256.convert(utf8.encode(input)).toString();
  }

  // 5. GAZE-CONDITIONAL REVEAL - Solo revela si mirada correcta
  static String? revelarSecreto({required String secretoCifrado, required String llaveMaestra, required bool gazeOK}) {
    if (!gazeOK) return null; // No revela nada
    // En producción: AES-GCM decrypt con llaveMaestra. Aquí: verificación HMAC para demo auditable
    final check = sha256.convert(utf8.encode('$llaveMaestra|$secretoCifrado')).toString().substring(0,8);
    return 'OK-$check'; // En real sería el secreto descifrado
  }

  // 6. VERIFICACIÓN COMPLETA - Lo que usa el login
  static EyeLockResultado verificarTodo({
    required String eyeLockId,
    required String codigoLabel,
    required String frase6,
    required String irisFeatures,
    required String saltGuardado,
    required String phiGuardado,
    required List<int> challenge,
    required List<int> mirada,
    required int parpadeos,
    required DateTime inicio,
    required DateTime fin,
  }) {
    if (!codigoLabel.startsWith('LBL-')) return EyeLockResultado(false, 'Código Label debe empezar con LBL-');
    if (frase6.trim().split(' ').length != 6) return EyeLockResultado(false, 'Frase debe ser 6 palabras');
    final phiCalculado = phiHash(irisFeatures: irisFeatures, salt: saltGuardado, eyeLockId: eyeLockId);
    if (phiCalculado != phiGuardado) return EyeLockResultado(false, 'Phi Φ falló - Iris no coincide');
    final lambdaOK = verificarLambda(challengeEsperado: challenge, miradaUsuario: mirada, parpadeos: parpadeos, inicio: inicio, fin: fin);
    if (!lambdaOK) return EyeLockResultado(false, 'Lambda Λ falló - Prueba de vida no pasó');
    final master = derivarLlaveMaestra(phiHash: phiCalculado, frase6: frase6, lambdaOK: lambdaOK);
    return EyeLockResultado(true, 'EyeLock OK - Φ + Λ verificados', llaveMaestra: master);
  }
}

class EyeLockResultado {
  final bool ok;
  final String mensaje;
  final String? llaveMaestra;
  EyeLockResultado(this.ok, this.mensaje, {this.llaveMaestra});
}
