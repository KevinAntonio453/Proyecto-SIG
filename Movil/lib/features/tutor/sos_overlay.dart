import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme.dart';

/// Modal de pantalla completa que se muestra al tutor cuando recibe una alerta SOS.
/// Incluye las opciones: Llamar, Navegar (abrir mapa externo), y Descartar.
class SosOverlay {
  static bool _isShowing = false;

  /// Mostrar el overlay SOS fullscreen.
  /// [context] debe ser un BuildContext válido y montado.
  /// [childName] nombre del hijo que activó el SOS.
  /// [lat] y [lng] coordenadas de la ubicación del hijo al momento del SOS.
  /// [telefono] número del hijo (opcional, para llamar).
  static void show({
    required BuildContext context,
    required String childName,
    required double lat,
    required double lng,
    String? telefono,
  }) {
    if (_isShowing) return; // Evitar duplicados
    _isShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.red.shade900.withOpacity(0.85),
      builder: (dialogContext) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Icono de emergencia animado
                    const Icon(
                      Icons.emergency,
                      color: Colors.white,
                      size: 80,
                    ),
                    const SizedBox(height: 24),

                    // Título
                    const Text(
                      '🚨 ALERTA SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Nombre del hijo
                    Text(
                      childName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Mensaje
                    const Text(
                      'Ha activado una alerta de pánico.\nSu ubicación se muestra a continuación.',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Coordenadas
                    Text(
                      '📍 ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // Botón: Llamar
                    if (telefono != null && telefono.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: () {
                          launchUrl(Uri.parse('tel:$telefono'));
                        },
                        icon: const Icon(Icons.call, size: 24),
                        label: const Text('Llamar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.colorSafe,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (telefono != null && telefono.isNotEmpty)
                      const SizedBox(height: 12),

                    // Botón: Navegar (abrir en Google Maps)
                    ElevatedButton.icon(
                      onPressed: () {
                        final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
                        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                      },
                      icon: const Icon(Icons.navigation, size: 24),
                      label: const Text('Navegar hacia la ubicación'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Botón: Descartar
                    OutlinedButton(
                      onPressed: () {
                        _isShowing = false;
                        Navigator.of(dialogContext).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                      child: const Text('Descartar alerta'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ).then((_) {
      _isShowing = false;
    });
  }
}
