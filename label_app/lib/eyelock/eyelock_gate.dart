import 'package:flutter/material.dart';
import 'eyelock_core.dart';

/// PUERTA REAL EyeLock - Reemplaza el placeholder anterior
/// En producción, irisFeatures viene de cámara IR + modelo de iris.
/// En web preview, se deriva de un challenge auditable + tu frase, para que puedas probar la lógica sin hardware.

class EyeLockGate {
  // Registro - Solo se guarda: eyeLockId, salt, phiHash. NUNCA iris crudo.
  static Map<String,String> registrar({required String eyeLockId, required String irisFeaturesSimulado}) {
    final salt = EyeLockCore.generarSalt();
    final phi = EyeLockCore.phiHash(irisFeatures: irisFeaturesSimulado, salt: salt, eyeLockId: eyeLockId);
    return {'eyeLockId': eyeLockId, 'salt': salt, 'phiHash': phi};
  }
}
