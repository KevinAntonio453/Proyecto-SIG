import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Paleta de colores principal
  static const Color primaryTeal = Color(0xFF0D7377);
  static const Color primaryTealLight = Color(0xFF14A3A8);
  static const Color primaryTealSurface = Color(0xFFE0F7F7);
  static const Color secondaryCoral = Color(0xFFFF6B6B);
  
  static const Color background = Color(0xFFFAFBFC);
  static const Color surface = Color(0xFFFFFFFF);
  
  static const Color onSurface = Color(0xFF1A1D26);
  static const Color onSurfaceVariant = Color(0xFF6B7280);
  static const Color outline = Color(0xFFE5E7EB);

  // Colores semánticos
  static const Color colorSafe = Color(0xFF10B981);    // Verde esmeralda (DENTRO)
  static const Color colorWarning = Color(0xFFF59E0B); // Ámbar (FUERA)
  static const Color colorDanger = Color(0xFFEF4444);  // Rojo (SOS/Pánico)
  static const Color colorInfo = Color(0xFF3B82F6);    // Azul cielo (Informativo)
  static const Color colorOffline = Color(0xFF9CA3AF); // Gris (Desconectado)

  // Tema Claro de la aplicación
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: primaryTeal,
        secondary: secondaryCoral,
        surface: surface,
        error: colorDanger,
      ),
      scaffoldBackgroundColor: background,
      dividerTheme: const DividerThemeData(
        color: outline,
        thickness: 1,
        space: 1,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        const TextTheme(
          displayLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: onSurface),
          headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: onSurface),
          headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: onSurface),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: onSurface),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: onSurface),
          bodyLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: onSurface),
          bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: onSurfaceVariant),
          labelLarge: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: onSurfaceVariant),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: onSurface),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      buttonTheme: const ButtonThemeData(
        buttonColor: primaryTeal,
        textTheme: ButtonTextTheme.primary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryTeal,
          foregroundColor: surface,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryTeal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: colorDanger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: colorDanger, width: 1.5),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(color: onSurfaceVariant),
        hintStyle: GoogleFonts.plusJakartaSans(color: onSurfaceVariant),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: outline),
        ),
        margin: EdgeInsets.zero,
      ),
    );
  }
}
