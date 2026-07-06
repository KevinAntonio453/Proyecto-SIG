import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme.dart';
import '../../../core/models/hijo.dart';
import '../../../core/services/hijos_service.dart';
import '../../../core/services/auth_service.dart';
import 'register_child_screen.dart';

class ManageChildrenScreen extends StatefulWidget {
  final Function(int)? onTabChange;

  const ManageChildrenScreen({super.key, this.onTabChange});

  @override
  State<ManageChildrenScreen> createState() => _ManageChildrenScreenState();
}

class _ManageChildrenScreenState extends State<ManageChildrenScreen> {
  final _hijosService = HijosService();
  List<Hijo> _hijos = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _cargarHijos();
  }

  Future<void> _cargarHijos() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final hijos = await _hijosService.getMisHijos();
      if (mounted) {
        setState(() {
          _hijos = hijos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _copiarCodigo(String codigo) {
    Clipboard.setData(ClipboardData(text: codigo));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Código copiado al portapapeles.'),
        backgroundColor: AppTheme.primaryTeal,
      ),
    );
  }

  Future<void> _eliminarHijo(Hijo hijo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Integrante'),
        content: Text('¿Estás seguro de que quieres desvincular a ${hijo.nombre}? Perderás el acceso a su ubicación e historial.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.colorDanger),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      if (!mounted) return;
      setState(() => _isLoading = true);
      try {
        final authService = AuthService();
        final user = await authService.getCurrentUser();
        if (user != null) {
          await _hijosService.desvincularHijo(user.id, hijo.id);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Integrante eliminado exitosamente.'),
              backgroundColor: AppTheme.colorSafe,
            ),
          );
          _cargarHijos();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = e.toString().replaceFirst('Exception: ', '');
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_errorMessage),
              backgroundColor: AppTheme.colorDanger,
            ),
          );
        }
      }
    }
  }



  void _abrirRegistroNuevo() async {
    final result = await Navigator.push<Hijo>(
      context,
      MaterialPageRoute(builder: (context) => const RegisterChildScreen()),
    );
    if (result != null) {
      _cargarHijos();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final vinculados = _hijos.where((h) => h.vinculado).toList();
    final pendientes = _hijos.where((h) => !h.vinculado).toList();

    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(_errorMessage, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _cargarHijos, child: const Text('Reintentar')),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Cabecera (Título + Descripción + Botón +)
                      Padding(
                        padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Familia activa',
                                    style: textTheme.headlineLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Monitorea la ubicación y el estado de tu familia en tiempo real',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Botón superior derecho "+"
                            IconButton(
                              icon: const Icon(Icons.add, color: Colors.white, size: 20),
                              style: IconButton.styleFrom(
                                backgroundColor: AppTheme.primaryTeal,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.all(12),
                              ),
                              onPressed: _abrirRegistroNuevo,
                            ),
                          ],
                        ),
                      ),

                      // Listado de Familiares
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            // 1. Integrantes Vinculados
                            ...vinculados.map((hijo) {
                              final bool isSafe = hijo.estadoZona == 'DENTRO';
                              final Color statusColor = isSafe ? AppTheme.colorSafe : AppTheme.colorWarning;
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: const BorderSide(color: AppTheme.outline, width: 1),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: AppTheme.primaryTealSurface,
                                            child: Text(
                                              hijo.nombre.substring(0, 1).toUpperCase(),
                                              style: const TextStyle(
                                                color: AppTheme.primaryTeal,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${hijo.nombre} ${hijo.apellido ?? ''}',
                                                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                                ),
                                                const SizedBox(height: 6),
                                                // Chip dinámico (En zona segura / Fuera de zona)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: statusColor.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      CircleAvatar(radius: 4, backgroundColor: statusColor),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        isSafe ? 'En zona segura' : 'Fuera de zona',
                                                        style: TextStyle(
                                                          color: statusColor,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Botón de eliminar (Icono de papelera)
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: AppTheme.colorDanger),
                                            onPressed: () => _eliminarHijo(hijo),
                                            tooltip: 'Eliminar familiar',
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      // Fila de acciones (Ver mapa | Llamar)
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () {
                                                widget.onTabChange?.call(0); // Volver al Inicio (Mapa)
                                              },
                                              icon: const Icon(Icons.map_outlined, size: 18),
                                              label: const Text('Ver mapa'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.primaryTeal,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (hijo.telefono != null && hijo.telefono!.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(Icons.phone_outlined, color: AppTheme.primaryTeal),
                                              style: IconButton.styleFrom(
                                                backgroundColor: AppTheme.primaryTealSurface,
                                                padding: const EdgeInsets.all(12),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  side: const BorderSide(color: AppTheme.primaryTealLight),
                                                ),
                                              ),
                                              onPressed: () {
                                                launchUrl(Uri.parse('tel:${hijo.telefono}'));
                                              },
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),

                            // 2. Integrantes Pendientes de Vinculación
                            ...pendientes.map((hijo) {
                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: const BorderSide(color: AppTheme.outline, width: 1),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: Colors.grey.shade200,
                                            child: Text(
                                              hijo.nombre.substring(0, 1).toUpperCase(),
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  hijo.nombre,
                                                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                                ),
                                                const SizedBox(height: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade100,
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      CircleAvatar(radius: 4, backgroundColor: Colors.grey.shade400),
                                                      const SizedBox(width: 6),
                                                      const Text(
                                                        'Pendiente de vinculación',
                                                        style: TextStyle(
                                                          color: Colors.grey,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Botón de eliminar (Icono de papelera) para pendientes
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: AppTheme.colorDanger),
                                            onPressed: () => _eliminarHijo(hijo),
                                            tooltip: 'Eliminar familiar',
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      // Caja de código para copiar (Mockup 3)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.grey.shade200),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'CÓDIGO DE VINCULACIÓN',
                                                    style: TextStyle(
                                                      color: Colors.grey,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    hijo.codigoVinculacion ?? '------',
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 2,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            OutlinedButton.icon(
                                              onPressed: () => _copiarCodigo(hijo.codigoVinculacion ?? ''),
                                              icon: const Icon(Icons.copy, size: 14),
                                              label: const Text('Copiar'),
                                              style: OutlinedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),

                            // 3. Botón de añadir nuevo (Borde Punteado)
                            GestureDetector(
                              onTap: _abrirRegistroNuevo,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    width: 1.5,
                                    style: BorderStyle.solid, // Nota: BorderStyle.solid simulado, Flutter requiere CustomPainter para guiones reales
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: AppTheme.primaryTealSurface,
                                      child: const Icon(Icons.add, color: AppTheme.primaryTeal),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Añadir nuevo',
                                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Vincular un nuevo dispositivo',
                                      style: TextStyle(color: Colors.grey, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
