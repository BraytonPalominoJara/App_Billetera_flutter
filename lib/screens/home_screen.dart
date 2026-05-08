import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart' hide Source;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/transaction_model.dart';
import '../models/loan_model.dart';
import '../models/saving_goal_model.dart';
import '../models/category_model.dart';
import '../models/tree_state_model.dart';
import 'add_transaction_screen.dart';
import 'add_loan_screen.dart';
import 'add_goal_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Estado de los Filtros locales de transacciones
  String _typeFilter = 'Todos'; // 'Todos', 'Ingresos', 'Gastos'
  String _categoryFilter = 'Todas'; // 'Todas' + categorías fijas y dinámicas
  bool _isDashboardExpanded = false; // Estado del Dashboard de gráficos
  String _dashboardTab = 'Hoy'; // Pestaña seleccionada: 'Hoy' o 'Mes'
  String _dashboardType = 'expense'; // 'expense' (Gastos) o 'income' (Ingresos)
  int? _selectedDay; // Día seleccionado en el gráfico mensual (nulo para todo el mes)
  int? _selectedHourBlock; // Bloque horario seleccionado (0-5) (nulo para todo el día)
  DateTime _selectedHourlyDate = DateTime.now(); // Fecha para el gráfico por horas

  // Estado de gamificación interactiva (Arbórea)
  bool _isWateringActive = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> _playSound(String url) async {
    try {
      await _audioPlayer.stop(); // Detener cualquier reproducción previa
      await _audioPlayer.play(UrlSource(url));
    } catch (e) {
      debugPrint('Error al reproducir audio: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<User?>(context, listen: false);
      final service = Provider.of<FirestoreService>(context, listen: false);
      if (user != null) {
        service.checkAndResetDailyTasks(user.uid);
        _checkForUpdates(); // Búsqueda silenciosa de actualizaciones al arrancar
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final firestoreService = Provider.of<FirestoreService>(context);
    final user = Provider.of<User?>(context);

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF6366F1); // Indigo
    final String displayName = user.displayName ?? 'Usuario';

    // Lista de Vistas (Cuerpo)
    final List<Widget> _views = [
      _buildWalletTab(firestoreService, user.uid, displayName, isDark, context, authService),
      _buildLoansTab(firestoreService, user.uid, isDark, context),
      _buildDashboardTab(firestoreService, user.uid, isDark, context), // Pestaña dedicada
      _buildTreeGameTab(firestoreService, user.uid, isDark, context), // NUEVO: Juego del Árbol del Ahorro
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: _views[_currentIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Asegura que se muestren los títulos para 4 ítems
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            // Al cambiar de pestaña, reiniciamos los filtros interactivos de gráficos
            _selectedDay = null;
            _selectedHourBlock = null;
          });
        },
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: isDark ? Colors.grey[500] : Colors.grey[400],
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Billetera',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.handshake_rounded),
            label: 'Préstamos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Estadísticas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.park_rounded),
            label: 'Mi Árbol',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: FloatingActionButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddTransactionScreen()),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              ),
            )
          : _currentIndex == 1
              ? Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  child: FloatingActionButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddLoanScreen()),
                    ),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    child: const Icon(Icons.handshake_rounded, color: Colors.white, size: 28),
                  ),
                )
              : null, // Sin FAB en la pestaña de estadísticas
    );
  }

  void _confirmSignOut(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas salir de tu cuenta?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              authService.signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
  }

  static const String _currentAppVersion = '1.2.0';

  Future<void> _checkForUpdates({bool silent = true}) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('update_info')
          .get(const GetOptions(source: Source.server));

      if (!doc.exists) {
        if (!silent) {
          _showCustomSnackBar('Al día. Local: "$_currentAppVersion" | Doc Firestore no existe', isError: false);
        }
        return;
      }
 
      final data = doc.data();
      if (data == null) {
        if (!silent) {
          _showCustomSnackBar('Al día. Local: "$_currentAppVersion" | Datos vacíos', isError: false);
        }
        return;
      }
 
      final latestVersion = (data['latest_version'] ?? _currentAppVersion).toString().trim();
      final updateUrl = (data['update_url'] ?? '').toString().trim();
      final releaseNotes = (data['release_notes'] ?? 'Mejoras en la experiencia de usuario y optimizaciones.').toString().trim();
      final isMandatory = data['is_mandatory'] ?? false;
 
      debugPrint('Arbórea Debug: latest_version de Firestore = "$latestVersion" | _currentAppVersion de la App = "$_currentAppVersion"');
 
      if (latestVersion != _currentAppVersion) {
        _showUpdateDialog(latestVersion, updateUrl, releaseNotes, isMandatory);
      } else {
        if (!silent) {
          _showCustomSnackBar('BD: ${data.keys.toList()} | Remoto: "${data['latest_version']}" | Local: "$_currentAppVersion"', isError: false);
        }
      }
    } catch (e) {
      debugPrint('Error al comprobar actualizaciones: $e');
      if (!silent) {
        _showCustomSnackBar('No se pudo verificar la actualización.', isError: true);
      }
    }
  }

  void _showUpdateDialog(String latestVersion, String updateUrl, String releaseNotes, bool isMandatory) {
    showDialog(
      context: context,
      barrierDismissible: !isMandatory, // Si es obligatoria, no puede cerrarse tocando fuera
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = const Color(0xFF6366F1);

        return WillPopScope(
          onWillPop: () async => !isMandatory, // Impedir retroceso si es obligatoria
          child: AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1B4B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.system_update_alt_rounded, color: Colors.amber),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isMandatory ? 'Actualización Requerida' : 'Nueva Versión Disponible',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                      fontFamily: 'Roboto',
                    ),
                    children: [
                      const TextSpan(text: 'La versión '),
                      TextSpan(
                        text: 'v$latestVersion',
                        style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: ' ya está lista. Tu versión actual es '),
                      const TextSpan(
                        text: 'v$_currentAppVersion',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Notas de la versión:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        releaseNotes,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (!isMandatory)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Más tarde', style: TextStyle(color: Colors.grey)),
                ),
              ElevatedButton(
                onPressed: () async {
                  if (updateUrl.isNotEmpty) {
                    final uri = Uri.parse(updateUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } else {
                      _showCustomSnackBar('No se pudo abrir el enlace de descarga.', isError: true);
                    }
                  } else {
                    _showCustomSnackBar('No hay un enlace de descarga configurado.', isError: true);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: const Text('Actualizar Ahora', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAppInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = const Color(0xFF6366F1);
        bool checking = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1B4B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Column(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.park_rounded, color: primaryColor, size: 40),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Arbórea',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: -0.5),
                  ),
                  const Text(
                    'Versión $_currentAppVersion',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tu gestor financiero inteligente y gamificado. Ahorra, siembra metas, riega tus finanzas y mira crecer tu bosque virtual.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark ? Colors.grey[300] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: isDark ? Colors.white12 : Colors.grey[200]),
                  const SizedBox(height: 8),
                  Text(
                    '© 2026 Arbórea Inc.',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[400]),
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton.icon(
                  onPressed: checking
                      ? null
                      : () async {
                          setDialogState(() => checking = true);
                          await _checkForUpdates(silent: false);
                          if (mounted) {
                            setDialogState(() => checking = false);
                          }
                        },
                  icon: checking
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(checking ? 'Buscando...' : 'Buscar Actualización'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCustomSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }


  // ================= TAB 1: BILLETERA (WALLETS) =================
  Widget _buildWalletTab(
    FirestoreService service,
    String userId,
    String displayName,
    bool isDark,
    BuildContext context,
    AuthService authService,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¡Hola, de nuevo!',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    // Botón de Información y Buscar Actualizaciones
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          if (!isDark)
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(Icons.info_outline_rounded, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                        onPressed: () => _showAppInfoDialog(context),
                      ),
                    ),
                    // Botón de Cerrar Sesión
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          if (!isDark)
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(Icons.logout_rounded, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                        onPressed: () => _confirmSignOut(context, authService),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tarjeta de Balance General
          _buildPremiumSummaryCard(service, userId, isDark),

          // Banner Redirección a Estadísticas (Dashboard)
          _buildStatsRedirectBanner(isDark),

          // Sección de Metas de Ahorro (Carrusel Deslizable)
          _buildGoalsSection(service, userId, isDark),

          // Sección de Filtros de Transacciones
          _buildFiltersSection(service, userId, isDark),

          // Título de Movimientos Recientes
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Movimientos Recientes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  'Mantén presionado para borrar',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Lista de Movimientos Filtrada
          _buildTransactionList(service, userId, isDark),
          const SizedBox(height: 80), // Margen para evitar bloqueo por el FAB
        ],
      ),
    );
  }

  // ================= TAB 2: PRÉSTAMOS (LOANS) =================
  Widget _buildLoansTab(
    FirestoreService service,
    String userId,
    bool isDark,
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header de Préstamos
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Módulo de Préstamos',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Lleva el control de lo que debes y te deben',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),

        // Lista de Préstamos
        Expanded(
          child: StreamBuilder<List<LoanModel>>(
            stream: service.getLoans(userId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'Error al cargar préstamos',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Si es por índices de Firestore, por favor créalos usando el enlace de tu terminal o el diálogo provisto:\n\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final loans = snapshot.data ?? [];
              if (loans.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.handshake_outlined, size: 64, color: isDark ? Colors.grey[700] : Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(
                        'No tienes préstamos registrados',
                        style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: loans.length,
                itemBuilder: (context, index) {
                  final loan = loans[index];
                  final isBorrowed = loan.type == LoanType.borrowed;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                      ],
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey[100]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Icono representativo (Recibido vs Otorgado)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isBorrowed
                                ? const Color(0xFF6366F1).withOpacity(0.1)
                                : const Color(0xFFF59E0B).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isBorrowed ? Icons.download_rounded : Icons.upload_rounded,
                            color: isBorrowed ? const Color(0xFF6366F1) : const Color(0xFFF59E0B),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Detalles del Préstamo
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    loan.personName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Badge de Estado Pagado
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: loan.isPaid
                                          ? Colors.green.withOpacity(0.12)
                                          : Colors.redAccent.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      loan.isPaid ? 'Pagado' : 'Pendiente',
                                      style: TextStyle(
                                        color: loan.isPaid ? Colors.green : Colors.redAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${isBorrowed ? "Te prestó:" : "Le prestaste:"} \$${loan.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                                ),
                              ),
                              if (loan.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Motivo: ${loan.description}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                'Vence: ${DateFormat('dd MMMM, yyyy', 'es').format(loan.dueDate)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Botón de acción rápido (Alternar Pagado/Pendiente)
                        IconButton(
                          icon: Icon(
                            loan.isPaid ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            color: loan.isPaid ? Colors.green : (isDark ? Colors.grey[500] : Colors.grey[400]),
                            size: 28,
                          ),
                          onPressed: () => service.toggleLoanStatus(loan),
                          tooltip: 'Cambiar estado de pago',
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // Tarjeta de Resumen (Visualmente similar a una tarjeta bancaria premium)
  Widget _buildPremiumSummaryCard(FirestoreService service, String userId, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4F46E5), Color(0xFF3730A3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MI SALDO ESTIMADO',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),

          // Cálculo del Balance General
          StreamBuilder<double>(
            stream: service.getBalance(userId),
            builder: (context, snapshotBalance) {
              final balance = snapshotBalance.data ?? 0.0;
              final isNegative = balance < 0;
              return Text(
                '${isNegative ? '-' : ''}\$${balance.abs().toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Gasto Diario
              Expanded(
                child: StreamBuilder<double>(
                  stream: service.getDailyExpenses(userId, DateTime.now()),
                  builder: (context, snapshot) {
                    final amount = snapshot.data ?? 0.0;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.arrow_downward_rounded, color: Color(0xFFFECACA), size: 16),
                              SizedBox(width: 4),
                              Text('Gasto Hoy', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\$${amount.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Gasto Mensual
              Expanded(
                child: StreamBuilder<double>(
                  stream: service.getMonthlyExpenses(userId, DateTime.now()),
                  builder: (context, snapshot) {
                    final amount = snapshot.data ?? 0.0;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.calendar_month_rounded, color: Color(0xFFFDE68A), size: 16),
                              SizedBox(width: 4),
                              Text('Este Mes', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\$${amount.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // ================= SECCIÓN DE METAS DE AHORRO =================
  Widget _buildGoalsSection(FirestoreService service, String userId, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mis Metas de Ahorro',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF6366F1)),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddGoalScreen()),
                ),
              ),
            ],
          ),
        ),
        StreamBuilder<List<SavingGoalModel>>(
          stream: service.getSavingGoals(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 195,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final goals = snapshot.data ?? [];
            if (goals.isEmpty) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.grey[100]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.track_changes_rounded, color: Color(0xFF6366F1), size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '¡Comienza a ahorrar!',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Define una meta de ahorro y mantén la disciplina.',
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return SizedBox(
              height: 195,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: goals.length,
                itemBuilder: (context, index) {
                  final goal = goals[index];
                  final percent = (goal.targetAmount > 0)
                      ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
                      : 0.0;
                  return _buildGoalCard(context, service, goal, percent, isDark);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGoalCard(BuildContext context, FirestoreService service, SavingGoalModel goal, double percent, bool isDark) {
    return Container(
      width: 250,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
        ],
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  goal.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _confirmDeleteGoal(context, service, goal),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '\$${goal.currentAmount.toStringAsFixed(2)} / \$${goal.targetAmount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF6366F1)),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 6,
              backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Aportar
              InkWell(
                onTap: () => _showGoalAmountDialog(context, service, goal, true),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Aportar',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                  ),
                ),
              ),
              // Retirar
              InkWell(
                onTap: () => _showGoalAmountDialog(context, service, goal, false),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Retirar',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGoal(BuildContext context, FirestoreService service, SavingGoalModel goal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Meta'),
        content: Text('¿Estás seguro de que deseas eliminar la meta de ahorro "${goal.title}"?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              service.deleteSavingGoal(goal.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showGoalAmountDialog(BuildContext context, FirestoreService service, SavingGoalModel goal, bool isContribution) {
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isContribution ? 'Aportar a Meta' : 'Retirar de Meta'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Meta: ${goal.title}\nSaldo de ahorro actual: \$${goal.currentAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B)),
                  decoration: InputDecoration(
                    labelText: 'Cantidad',
                    prefixIcon: const Icon(Icons.monetization_on_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresa una cantidad';
                    final amt = double.tryParse(v);
                    if (amt == null || amt <= 0) return 'Monto no válido';
                    if (!isContribution && amt > goal.currentAmount) {
                      return 'No tienes suficientes fondos ahorrados';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final amt = double.parse(amountController.text);
                await service.updateSavingGoalAmount(goal, amt, isContribution);
                if (isContribution) {
                  await service.completeDailyTask(goal.userId, 'saving');
                }
                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isContribution ? const Color(0xFF6366F1) : Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  // ================= SECCIÓN DE FILTROS LOCALES =================
  Widget _buildFiltersSection(FirestoreService service, String userId, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Fila 1: Filtro de Tipo (Todos / Ingresos / Gastos)
        Padding(
          padding: const EdgeInsets.only(left: 20, top: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildFilterChip('Todos', _typeFilter == 'Todos', (selected) {
                  if (selected) setState(() => _typeFilter = 'Todos');
                }, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Ingresos', _typeFilter == 'Ingresos', (selected) {
                  if (selected) setState(() => _typeFilter = 'Ingresos');
                }, isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Gastos', _typeFilter == 'Gastos', (selected) {
                  if (selected) setState(() => _typeFilter = 'Gastos');
                }, isDark),
              ],
            ),
          ),
        ),

        // Fila 2: Filtro de Categoría (Todas / Comida / Transporte...)
        StreamBuilder<List<CategoryModel>>(
          stream: service.getCustomCategories(userId),
          builder: (context, snapshot) {
            final customCats = snapshot.data ?? [];
            final List<String> categories = ['Todas'];
            // Categorías fijas
            categories.addAll(['Comida', 'Transporte', 'Hogar', 'Entretenimiento', 'Salario', 'General']);
            // Categorías creadas por el usuario
            categories.addAll(customCats.map((c) => c.name));

            return Padding(
              padding: const EdgeInsets.only(left: 20, top: 8, bottom: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: categories.map((cat) {
                    final isSelected = _categoryFilter == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: _buildFilterChip(cat, isSelected, (selected) {
                        if (selected) setState(() => _categoryFilter = cat);
                      }, isDark, isSecondary: true),
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, ValueChanged<bool> onSelected, bool isDark, {bool isSecondary = false}) {
    final primaryColor = const Color(0xFF6366F1);
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.grey[300] : Colors.grey[700]),
        ),
      ),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: isSecondary ? const Color(0xFF4F46E5) : primaryColor,
      backgroundColor: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[100],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected
              ? Colors.transparent
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!),
        ),
      ),
    );
  }

  // Lista de Transacciones Recientes (Columna en Scroll Principal)
  Widget _buildTransactionList(FirestoreService service, String userId, bool isDark) {
    return StreamBuilder<List<TransactionModel>>(
      stream: service.getTransactions(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Error al cargar transacciones',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Si es por índices de Firestore, por favor créalos usando el enlace de tu terminal:\n\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator(),
          ));
        }

        final rawTransactions = snapshot.data ?? [];

        // FILTRAR LOCALMENTE (Instantáneo, evita configurar índices múltiples compuestos)
        final transactions = rawTransactions.where((tx) {
          // Filtro de Tipo
          if (_typeFilter == 'Ingresos' && tx.type != TransactionType.income) return false;
          if (_typeFilter == 'Gastos' && tx.type != TransactionType.expense) return false;

          // Filtro de Categoría
          if (_categoryFilter != 'Todas' && tx.category != _categoryFilter) return false;

          return true;
        }).toList();

        if (transactions.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.filter_list_off_rounded, size: 48, color: isDark ? Colors.grey[700] : Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    'No hay movimientos para este filtro',
                    style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        // Retornamos un Column en lugar de un ListView.builder para integrarse perfectamente
        // en el scroll unificado del SingleChildScrollView exterior.
        return Column(
          children: transactions.map((tx) {
            final isExpense = tx.type == TransactionType.expense;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.015),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                ],
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey[100]!,
                ),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isExpense
                        ? Colors.redAccent.withOpacity(0.12)
                        : Colors.greenAccent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isExpense ? Icons.arrow_outward_rounded : Icons.call_received_rounded,
                    color: isExpense ? Colors.redAccent : Colors.green,
                    size: 20,
                  ),
                ),
                title: Text(
                  tx.description,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                subtitle: Text(
                  DateFormat('dd MMMM, yyyy', 'es').format(tx.date),
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[500]),
                ),
                trailing: Text(
                  '${isExpense ? '-' : '+'}\$${tx.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: isExpense ? Colors.redAccent : Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                onLongPress: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Eliminar Transacción'),
                      content: const Text('¿Estás seguro de borrar este registro?'),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            service.deleteTransaction(tx.id);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Eliminar'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ================= SECCIÓN: BANNER DE REDIRECCIÓN A ESTADÍSTICAS =================
  Widget _buildStatsRedirectBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
              ? [const Color(0xFF1E293B), const Color(0xFF334155)] 
              : [const Color(0xFFEEF2FF), Colors.white],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFE0E7FF)),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _currentIndex = 2),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bar_chart_rounded,
                    color: Color(0xFF6366F1),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ver Estadísticas y Gráficos',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Analiza tus ingresos y gastos de hoy y del mes con máximo nivel de detalle.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= PESTAÑA PRINCIPAL: DASHBOARD ANALÍTICO COMPLETO =================
  Widget _buildDashboardTab(FirestoreService service, String userId, bool isDark, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header de la pestaña
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.insert_chart_outlined_rounded,
                  color: Color(0xFF6366F1),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Análisis Financiero',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Monitorea tus ingresos y egresos',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Cuerpo Principal
        Expanded(
          child: StreamBuilder<List<TransactionModel>>(
            stream: service.getTransactions(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final allTransactions = snapshot.data ?? [];
              
              // Filtrar según Gastos vs Ingresos
              final isExpense = _dashboardType == 'expense';
              final currentTypeTransactions = allTransactions
                  .where((tx) => isExpense 
                      ? tx.type == TransactionType.expense 
                      : tx.type == TransactionType.income)
                  .toList();

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Selector: Gastos vs Ingresos
                    _buildDashboardTypeSelector(isDark),
                    
                    // Selector de Pestaña: Hoy vs Mes
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: _buildDashboardTabs(isDark),
                    ),

                    // Gráfico correspondiente
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[100]!),
                        ),
                        child: _dashboardTab == 'Hoy'
                            ? _buildHourlyChart(currentTypeTransactions, isDark)
                            : _buildMonthlyChart(currentTypeTransactions, isDark),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Título de Detalles / Transacciones del periodo
                    _buildDetailsHeader(isDark),

                    // Lista de transacciones filtrada en base a las barras seleccionadas
                    _buildPeriodTransactionsList(currentTypeTransactions, isDark, service),
                    
                    const SizedBox(height: 80), // Espacio para no chocar con el BNB
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardTypeSelector(bool isDark) {
    final isExpense = _dashboardType == 'expense';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _dashboardType = 'expense';
                    // Al cambiar tipo de gráfico, resetear selecciones de barra
                    _selectedDay = null;
                    _selectedHourBlock = null;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isExpense 
                        ? const Color(0xFFEF4444).withOpacity(0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isExpense 
                        ? Border.all(color: const Color(0xFFEF4444).withOpacity(0.4))
                        : null,
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_downward_rounded,
                          size: 16,
                          color: isExpense ? const Color(0xFFEF4444) : (isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Gastos',
                          style: TextStyle(
                            color: isExpense ? const Color(0xFFEF4444) : (isDark ? Colors.grey[400] : Colors.grey[600]),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _dashboardType = 'income';
                    _selectedDay = null;
                    _selectedHourBlock = null;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: !isExpense 
                        ? const Color(0xFF10B981).withOpacity(0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: !isExpense 
                        ? Border.all(color: const Color(0xFF10B981).withOpacity(0.4))
                        : null,
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_upward_rounded,
                          size: 16,
                          color: !isExpense ? const Color(0xFF10B981) : (isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Ingresos',
                          style: TextStyle(
                            color: !isExpense ? const Color(0xFF10B981) : (isDark ? Colors.grey[400] : Colors.grey[600]),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTabs(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _dashboardTab = 'Hoy';
                  _selectedDay = null;
                  _selectedHourBlock = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _dashboardTab == 'Hoy'
                      ? const Color(0xFF6366F1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Hoy (Por horas)',
                    style: TextStyle(
                      color: _dashboardTab == 'Hoy' ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _dashboardTab = 'Mes';
                  _selectedDay = null;
                  _selectedHourBlock = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _dashboardTab == 'Mes'
                      ? const Color(0xFF6366F1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Mes (Por días)',
                    style: TextStyle(
                      color: _dashboardTab == 'Mes' ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyChart(List<TransactionModel> transactions, bool isDark) {
    final now = DateTime.now();
    final isTodaySelected = _selectedHourlyDate.year == now.year &&
        _selectedHourlyDate.month == now.month &&
        _selectedHourlyDate.day == now.day;
    
    final isYesterdaySelected = _selectedHourlyDate.year == now.year &&
        _selectedHourlyDate.month == now.month &&
        _selectedHourlyDate.day == now.subtract(const Duration(days: 1)).day;

    final selectedDayTxs = transactions.where((tx) =>
        tx.date.year == _selectedHourlyDate.year &&
        tx.date.month == _selectedHourlyDate.month &&
        tx.date.day == _selectedHourlyDate.day).toList();

    // 6 bloques de 4 horas
    final List<double> hourlySums = List.filled(6, 0.0);
    for (var tx in selectedDayTxs) {
      final hour = tx.date.hour;
      final blockIndex = (hour / 4).floor().clamp(0, 5);
      hourlySums[blockIndex] += tx.amount;
    }

    final double maxVal = hourlySums.reduce((curr, next) => curr > next ? curr : next);
    final totalDay = hourlySums.reduce((a, b) => a + b);
    final isExpense = _dashboardType == 'expense';

    final List<String> labels = [
      '00-04h',
      '04-08h',
      '08-12h',
      '12-16h',
      '16-20h',
      '20-24h',
    ];

    String dateLabel = '';
    if (isTodaySelected) {
      dateLabel = 'Hoy';
    } else if (isYesterdaySelected) {
      dateLabel = 'Ayer';
    } else {
      dateLabel = DateFormat('dd MMM, yyyy', 'es').format(_selectedHourlyDate);
    }

    Future<void> _selectDate() async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedHourlyDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        locale: const Locale('es', 'ES'),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF6366F1),
                primary: const Color(0xFF6366F1),
                surface: isDark ? const Color(0xFF1E293B) : Colors.white,
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null && picked != _selectedHourlyDate) {
        setState(() {
          _selectedHourlyDate = picked;
          _selectedHourBlock = null; // Reiniciar bloque seleccionado
        });
      }
    }

    final Widget dateNavigator = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
          onPressed: () {
            setState(() {
              _selectedHourlyDate = _selectedHourlyDate.subtract(const Duration(days: 1));
              _selectedHourBlock = null; // Reset selection
            });
          },
          style: IconButton.styleFrom(
            padding: const EdgeInsets.all(8),
            backgroundColor: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[100],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF6366F1)),
                const SizedBox(width: 8),
                Text(
                  dateLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          onPressed: isTodaySelected
              ? null
              : () {
                  setState(() {
                    _selectedHourlyDate = _selectedHourlyDate.add(const Duration(days: 1));
                    _selectedHourBlock = null; // Reset selection
                  });
                },
          style: IconButton.styleFrom(
            padding: const EdgeInsets.all(8),
            backgroundColor: isTodaySelected
                ? Colors.transparent
                : (isDark ? Colors.white.withOpacity(0.04) : Colors.grey[100]),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          color: isTodaySelected ? Colors.grey.withOpacity(0.3) : null,
        ),
      ],
    );

    if (totalDay == 0) {
      return Column(
        children: [
          dateNavigator,
          const SizedBox(height: 24),
          SizedBox(
            height: 140,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isExpense ? Icons.pie_chart_outline_rounded : Icons.add_chart_rounded, color: Colors.grey[400], size: 40),
                  const SizedBox(height: 8),
                  Text(
                    'No hay ${isExpense ? "gastos" : "ingresos"} registrados el $dateLabel',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        dateNavigator,
        const SizedBox(height: 16),
        Divider(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black12, height: 1),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isExpense ? 'Gasto total del día:' : 'Ingreso total del día:',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            Text(
              '\$${totalDay.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(6, (index) {
            final sum = hourlySums[index];
            final percent = maxVal > 0 ? (sum / maxVal) : 0.0;
            final barHeight = 80.0 * percent; // máx 80 píxeles
            
            final bool isSelected = _selectedHourBlock == index;
            final bool hasSelection = _selectedHourBlock != null;
            final double barOpacity = hasSelection ? (isSelected ? 1.0 : 0.3) : 1.0;

            return GestureDetector(
              onTap: () {
                setState(() {
                  if (_selectedHourBlock == index) {
                    _selectedHourBlock = null;
                  } else {
                    _selectedHourBlock = index;
                  }
                });
              },
              child: Opacity(
                opacity: barOpacity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Etiqueta del monto arriba de la barra (solo si es > 0)
                    SizedBox(
                      height: 16,
                      child: sum > 0
                          ? Text(
                              '\$${sum.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : Colors.grey[800],
                              ),
                            )
                          : const SizedBox(),
                    ),
                    const SizedBox(height: 4),
                    // Barra animada/interactiva
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 28,
                      height: barHeight.clamp(4.0, 80.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: sum > 0 
                              ? (isExpense 
                                  ? [const Color(0xFFEF4444), const Color(0xFFB91C1C)]
                                  : [const Color(0xFF10B981), const Color(0xFF047857)])
                              : [Colors.grey.withOpacity(0.1), Colors.grey.withOpacity(0.2)],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(color: isDark ? Colors.white : const Color(0xFF1E293B), width: 1.5)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      labels[index],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected 
                            ? (isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981))
                            : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildMonthlyChart(List<TransactionModel> transactions, bool isDark) {
    final now = DateTime.now();
    final thisMonthTxs = transactions.where((tx) =>
        tx.date.year == now.year &&
        tx.date.month == now.month).toList();

    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final List<double> dailySums = List.filled(daysInMonth, 0.0);
    for (var tx in thisMonthTxs) {
      dailySums[tx.date.day - 1] += tx.amount;
    }

    final double maxVal = dailySums.reduce((curr, next) => curr > next ? curr : next);
    final totalMonth = dailySums.reduce((a, b) => a + b);
    final isExpense = _dashboardType == 'expense';

    if (totalMonth == 0) {
      return SizedBox(
        height: 140,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isExpense ? Icons.calendar_month_rounded : Icons.event_available_rounded, color: Colors.grey[400], size: 40),
              const SizedBox(height: 8),
              Text(
                'No hay ${isExpense ? "gastos" : "ingresos"} registrados este mes',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isExpense ? 'Gasto total del mes:' : 'Ingreso total del mes:',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            Text(
              '\$${totalMonth.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: daysInMonth,
            itemBuilder: (context, index) {
              final dayNum = index + 1;
              final sum = dailySums[index];
              final percent = maxVal > 0 ? (sum / maxVal) : 0.0;
              final barHeight = 70.0 * percent; // máx 70 píxeles

              final bool isSelected = _selectedDay == dayNum;
              final bool hasSelection = _selectedDay != null;
              final double barOpacity = hasSelection ? (isSelected ? 1.0 : 0.3) : 1.0;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_selectedDay == dayNum) {
                        _selectedDay = null;
                      } else {
                        _selectedDay = dayNum;
                      }
                    });
                  },
                  child: Opacity(
                    opacity: barOpacity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Monto arriba de la barra
                        SizedBox(
                          height: 14,
                          child: sum > 0
                              ? Text(
                                  '\$${sum.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white70 : Colors.grey[800],
                                  ),
                                )
                              : const SizedBox(),
                        ),
                        const SizedBox(height: 4),
                        // Barra animada
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 16,
                          height: barHeight.clamp(3.0, 70.0),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: sum > 0 
                                  ? (isExpense 
                                      ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                                      : [const Color(0xFF10B981), const Color(0xFF059669)])
                                  : [Colors.grey.withOpacity(0.08), Colors.grey.withOpacity(0.15)],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            borderRadius: BorderRadius.circular(4),
                            border: isSelected
                                ? Border.all(color: isDark ? Colors.white : const Color(0xFF1E293B), width: 1.5)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dayNum.toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: (dayNum == now.day || isSelected) ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? (isExpense ? const Color(0xFFF59E0B) : const Color(0xFF10B981))
                                : dayNum == now.day 
                                    ? const Color(0xFF6366F1)
                                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsHeader(bool isDark) {
    final hasFilter = _dashboardTab == 'Hoy' ? _selectedHourBlock != null : _selectedDay != null;
    final isExpense = _dashboardType == 'expense';
    String filterText = '';
    
    final now = DateTime.now();
    final isTodaySelected = _selectedHourlyDate.year == now.year &&
        _selectedHourlyDate.month == now.month &&
        _selectedHourlyDate.day == now.day;
    final isYesterdaySelected = _selectedHourlyDate.year == now.year &&
        _selectedHourlyDate.month == now.month &&
        _selectedHourlyDate.day == now.subtract(const Duration(days: 1)).day;
    
    String dayWord = 'Hoy';
    if (isTodaySelected) {
      dayWord = 'Hoy';
    } else if (isYesterdaySelected) {
      dayWord = 'Ayer';
    } else {
      dayWord = DateFormat('dd MMM', 'es').format(_selectedHourlyDate);
    }

    if (_dashboardTab == 'Hoy') {
      if (_selectedHourBlock == null) {
        filterText = 'Movimientos de $dayWord (Todo el día)';
      } else {
        final List<String> blocks = ['00-04h', '04-08h', '08-12h', '12-16h', '16-20h', '20-24h'];
        filterText = '${isExpense ? "Gastos" : "Ingresos"} de $dayWord (${blocks[_selectedHourBlock!]})';
      }
    } else {
      if (_selectedDay == null) {
        filterText = 'Movimientos del Mes (Todos los días)';
      } else {
        filterText = '${isExpense ? "Gastos" : "Ingresos"} del Día ${_selectedDay!.toString().padLeft(2, '0')}';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              filterText,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ),
          if (hasFilter)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedDay = null;
                  _selectedHourBlock = null;
                });
              },
              icon: const Icon(Icons.clear_all_rounded, size: 16, color: Color(0xFF6366F1)),
              label: const Text(
                'Limpiar',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPeriodTransactionsList(List<TransactionModel> transactions, bool isDark, FirestoreService service) {
    final now = DateTime.now();
    List<TransactionModel> filtered = [];

    if (_dashboardTab == 'Hoy') {
      // Filtrar por el día seleccionado (_selectedHourlyDate)
      final todayTxs = transactions.where((tx) =>
          tx.date.year == _selectedHourlyDate.year &&
          tx.date.month == _selectedHourlyDate.month &&
          tx.date.day == _selectedHourlyDate.day).toList();
      
      if (_selectedHourBlock == null) {
        filtered = todayTxs;
      } else {
        filtered = todayTxs.where((tx) {
          final hour = tx.date.hour;
          final blockIndex = (hour / 4).floor().clamp(0, 5);
          return blockIndex == _selectedHourBlock;
        }).toList();
      }
    } else {
      // Filtrar por este mes
      final monthTxs = transactions.where((tx) =>
          tx.date.year == now.year &&
          tx.date.month == now.month).toList();

      if (_selectedDay == null) {
        filtered = monthTxs;
      } else {
        filtered = monthTxs.where((tx) => tx.date.day == _selectedDay).toList();
      }
    }

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, color: Colors.grey[400], size: 48),
            const SizedBox(height: 12),
            Text(
              'No hay transacciones registradas para este filtro',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: filtered.map((tx) {
        final isExpense = tx.type == TransactionType.expense;
        final txColor = isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey[100]!),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withOpacity(0.01),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: txColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isExpense ? Icons.arrow_outward_rounded : Icons.call_received_rounded,
                color: txColor,
                size: 20,
              ),
            ),
            title: Text(
              tx.description.isNotEmpty ? tx.description : tx.category,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            subtitle: Text(
              '${tx.category} • ${DateFormat('dd MMMM, HH:mm', 'es').format(tx.date)}',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${isExpense ? '-' : '+'}\$${tx.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: txColor,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Eliminar Transacción'),
                        content: const Text('¿Estás seguro de borrar este registro?'),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancelar'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              service.deleteTransaction(tx.id);
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Eliminar'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ================= PESTAÑA DEL JUEGO: EL ÁRBOL DEL AHORRO =================
  Widget _buildTreeGameTab(FirestoreService service, String userId, bool isDark, BuildContext context) {
    return StreamBuilder<TreeStateModel?>(
      stream: service.getTreeState(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final tree = snapshot.data;
        if (tree == null) {
          // Si no existe, inicializar de forma asíncrona
          service.checkAndResetDailyTasks(userId);
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Sembrando tu Árbol del Ahorro...', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EL ÁRBOL DEL AHORRO',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cultiva tu disciplina financiera',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),

              // Contenedor principal del Jardín (Árbol)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
                        : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black38 : Colors.grey[200]!,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: isDark ? const Color(0xFF312E81) : const Color(0xFFBFDBFE),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    // Badge del nivel y etapa
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Nivel ${tree.level} • ${tree.stageLabel}',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Gotas disponibles
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.opacity_rounded, color: Color(0xFF3B82F6), size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '${tree.waterDroplets} Gotas',
                                style: const TextStyle(
                                  color: Color(0xFF3B82F6),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Árbol animado con capa de riego interactiva
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _SwayingTree(level: tree.level, isDark: isDark),
                          if (_isWateringActive)
                            _WateringAnimationOverlay(
                              onComplete: () {
                                setState(() {
                                  _isWateringActive = false;
                                });
                              },
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Barra de progreso de XP
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progreso de Crecimiento',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                            Text(
                              '${tree.xp % 100} / 100 XP',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: tree.progressPercentage,
                            minHeight: 10,
                            backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Botón para Regar
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                         onPressed: (tree.waterDroplets > 0 && !_isWateringActive)
                             ? () async {
                                 // 1. Activar animación de la regadera cayendo
                                 setState(() {
                                   _isWateringActive = true;
                                 });

                                 // 2. Efecto físico háptico y sonido de riego (salpicadura de agua)
                                 HapticFeedback.mediumImpact();
                                 _playSound('https://assets.mixkit.co/active_storage/sfx/2568/2568-84.wav');

                                 // 3. Registrar el regado en Firestore de forma asíncrona
                                 await service.waterTree(userId);
                                 final nextXp = tree.xp + 10;
                                 final newLevel = (nextXp / 100).floor() + 1;

                                 if (newLevel > tree.level) {
                                   // Esperar a que las gotas terminen de caer (1.2 segundos) para el nivel alto
                                   await Future.delayed(const Duration(milliseconds: 1200));
                                   HapticFeedback.vibrate();
                                   _playSound('https://assets.mixkit.co/active_storage/sfx/2019/2019-84.wav');
                                   _showSnackBar('¡Felicidades! Tu árbol subió al nivel $newLevel! 🎉🌟🌳');
                                 } else {
                                   _showSnackBar('¡Árbol regado con éxito! +10 XP 💧🌳');
                                 }
                               }
                             : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                          disabledForegroundColor: Colors.grey[500],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: tree.waterDroplets > 0 ? 4 : 0,
                        ),
                        icon: const Icon(Icons.opacity_rounded, size: 20),
                        label: Text(
                          tree.waterDroplets > 0
                              ? 'REGAR ÁRBOL (-1 GOTA)'
                              : '¡SIN GOTAS! COMPLETA TAREAS DIARIAS',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Sección Tareas Diarias
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  'TAREAS DIARIAS (CONSIGUE GOTAS)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ),

              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey[100]!,
                  ),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.01),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                  ],
                ),
                child: Column(
                  children: [
                    // Tarea 1: Visita Diaria
                    _buildTaskRow(
                      context,
                      isCompleted: true,
                      title: 'Visita Diaria de tu Árbol',
                      subtitle: 'Ingresar a la app hoy',
                      rewardText: '+1 gota',
                      isDark: isDark,
                    ),
                    const Divider(height: 24),
                    // Tarea 2: Registrar Transacción
                    _buildTaskRow(
                      context,
                      isCompleted: tree.completedTasks['transaction'] == true,
                      title: 'Registrar Finanzas Diarias',
                      subtitle: 'Registrar un ingreso o un gasto',
                      rewardText: '+2 gotas',
                      isDark: isDark,
                      actionButton: TextButton(
                        onPressed: () {
                          setState(() {
                            _currentIndex = 0; // Redirige a Billetera
                          });
                        },
                        child: const Text('Registrar', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const Divider(height: 24),
                    // Tarea 3: Aportar a Meta
                    _buildTaskRow(
                      context,
                      isCompleted: tree.completedTasks['saving'] == true,
                      title: 'Sembrar el Ahorro',
                      subtitle: 'Aportar a cualquiera de tus metas',
                      rewardText: '+3 gotas',
                      isDark: isDark,
                      actionButton: TextButton(
                        onPressed: () {
                          setState(() {
                            _currentIndex = 1; // Redirige a Préstamos/Metas
                          });
                        },
                        child: const Text('Ahorrar', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskRow(
    BuildContext context, {
    required bool isCompleted,
    required String title,
    required String subtitle,
    required String rewardText,
    required bool isDark,
    Widget? actionButton,
  }) {
    return Row(
      children: [
        // Icono de estado
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isCompleted ? const Color(0xFF10B981).withOpacity(0.12) : Colors.grey.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isCompleted ? const Color(0xFF10B981) : Colors.grey,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        // Texto descriptivo
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        // Recompensa / Acción
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isCompleted ? const Color(0xFF10B981).withOpacity(0.12) : const Color(0xFF3B82F6).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isCompleted ? 'Recibido' : rewardText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isCompleted ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                ),
              ),
            ),
            if (!isCompleted && actionButton != null) actionButton,
          ],
        ),
      ],
    );
  }

  void _showSnackBar(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}

// ================= WIDGET DEL ÁRBOL QUE SE BALANCEA =================
class _SwayingTree extends StatefulWidget {
  final int level;
  final bool isDark;
  const _SwayingTree({required this.level, required this.isDark});

  @override
  State<_SwayingTree> createState() => _SwayingTreeState();
}

class _SwayingTreeState extends State<_SwayingTree> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Balanceo senoidal sutil de -0.04 a 0.04 radianes
        final swayAngle = (math.sin(_controller.value * 2 * math.pi) * 0.04);
        return CustomPaint(
          size: const Size(200, 200),
          painter: TreeVisualizerPainter(
            level: widget.level,
            swayAngle: swayAngle,
            isDark: widget.isDark,
          ),
        );
      },
    );
  }
}

// ================= WIDGET ANIMADO DE RIEGO INTERACTIVO =================
class _WateringAnimationOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  const _WateringAnimationOverlay({required this.onComplete});

  @override
  State<_WateringAnimationOverlay> createState() => _WateringAnimationOverlayState();
}

class _WateringAnimationOverlayState extends State<_WateringAnimationOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  // Animación de traslación y rotación de la regadera
  late Animation<double> _canSlideX;
  late Animation<double> _canSlideY;
  late Animation<double> _canRotate;
  late Animation<double> _canOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Movimiento en X de la regadera (entrada, permanencia y salida)
    _canSlideX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: -100.0, end: -20.0).chain(CurveTween(curve: Curves.easeOutBack)), weight: 30),
      TweenSequenceItem(tween: ConstantTween<double>(-20.0), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: -20.0, end: -100.0).chain(CurveTween(curve: Curves.easeInBack)), weight: 20),
    ]).animate(_controller);

    // Movimiento en Y de la regadera (entrada, permanencia y salida)
    _canSlideY = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: -80.0, end: -50.0).chain(CurveTween(curve: Curves.easeOutBack)), weight: 30),
      TweenSequenceItem(tween: ConstantTween<double>(-50.0), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: -50.0, end: -80.0).chain(CurveTween(curve: Curves.easeInBack)), weight: 20),
    ]).animate(_controller);

    // Rotación inclinando para verter agua (comienza a verter a partir del 30% del progreso)
    _canRotate = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: -0.6).chain(CurveTween(curve: Curves.easeInOut)), weight: 15),
      TweenSequenceItem(tween: ConstantTween<double>(-0.6), weight: 35),
      TweenSequenceItem(tween: Tween<double>(begin: -0.6, end: 0.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 10),
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 10),
    ]).animate(_controller);

    // Opacidad para hacer fade in y fade out de la regadera
    _canOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 60),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_controller);

    _controller.forward().then((_) {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        return SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Renderizado de las gotas cayendo por gravedad física
              if (progress >= 0.4 && progress <= 0.85)
                ...List.generate(5, (index) {
                  final startOffset = 0.4 + (index * 0.07);
                  final endOffset = startOffset + 0.22;
                  if (progress < startOffset || progress > endOffset) {
                    return const SizedBox.shrink();
                  }

                  // Normalizar el progreso relativo de esta gota individual
                  final t = (progress - startOffset) / (endOffset - startOffset);
                  
                  // Coordenadas parabólicas de origen (pico de regadera) a destino (base del árbol)
                  final double startX = 25.0;
                  final double startY = -42.0;
                  final double endX = 0.0;
                  final double endY = 40.0;

                  final currentX = startX + (endX - startX) * t;
                  // Gravedad simulada (aceleración cuadrática)
                  final currentY = startY + (endY - startY) * t * t;

                  final showSplash = t > 0.88;
                  final splashScale = (t - 0.88) / 0.12;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (!showSplash)
                        Positioned(
                          left: 100 + currentX - 6,
                          top: 100 + currentY - 6,
                          child: Opacity(
                            opacity: (1.0 - t).clamp(0.0, 1.0),
                            child: const Icon(
                              Icons.opacity_rounded,
                              color: Color(0xFF60A5FA),
                              size: 15,
                            ),
                          ),
                        ),
                      if (showSplash)
                        Positioned(
                          left: 100 + endX - (15 * splashScale),
                          top: 100 + endY - (6 * splashScale),
                          child: Opacity(
                            opacity: (1.0 - splashScale).clamp(0.0, 1.0),
                            child: Container(
                              width: 30 * splashScale,
                              height: 12 * splashScale,
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFF60A5FA), width: 1.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                }),

              // 2. La Regadera Virtual
              Positioned(
                left: 100 + _canSlideX.value - 30,
                top: 100 + _canSlideY.value - 30,
                child: Opacity(
                  opacity: _canOpacity.value,
                  child: Transform.rotate(
                    angle: _canRotate.value,
                    origin: const Offset(15, 15),
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Cuerpo de la regadera
                          const Icon(
                            Icons.local_drink_rounded,
                            size: 40,
                            color: Color(0xFF3B82F6),
                          ),
                          // Pico dispensador
                          Positioned(
                            right: 6,
                            top: 18,
                            child: Transform.rotate(
                              angle: 0.8,
                              child: Container(
                                width: 14,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ================= PAINTER VECTORIAL DEL ÁRBOL =================
class TreeVisualizerPainter extends CustomPainter {
  final int level;
  final double swayAngle;
  final bool isDark;

  TreeVisualizerPainter({
    required this.level,
    required this.swayAngle,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 15);
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // 1. Dibujar Tierra / Maceta
    final soilPaint = Paint()
      ..color = isDark ? const Color(0xFF451A03) : const Color(0xFF78350F)
      ..style = PaintingStyle.fill;
    
    final soilPath = Path()
      ..moveTo(center.dx - 65, center.dy)
      ..quadraticBezierTo(center.dx, center.dy - 16, center.dx + 65, center.dy)
      ..close();
    canvas.drawPath(soilPath, soilPaint);

    final grassPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.fill;
    final grassPath = Path()
      ..moveTo(center.dx - 30, center.dy - 3)
      ..quadraticBezierTo(center.dx, center.dy - 9, center.dx + 30, center.dy - 3)
      ..close();
    canvas.drawPath(grassPath, grassPaint);

    // 2. Dibujar Árbol según el Nivel
    if (level <= 2) {
      // --- FASE 1: Semilla / Brote ---
      // Semilla
      final seedPaint = Paint()..color = const Color(0xFF92400E);
      canvas.drawCircle(Offset(center.dx - 6, center.dy - 2), 5, seedPaint);

      // Tallo
      final stemPaint = Paint()
        ..color = const Color(0xFF34D399)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
      
      final stemPath = Path()
        ..moveTo(center.dx, center.dy - 4)
        ..quadraticBezierTo(
          center.dx + (swayAngle * 50),
          center.dy - 22,
          center.dx + (swayAngle * 100),
          center.dy - 38,
        );
      canvas.drawPath(stemPath, stemPaint);

      // Hojitas
      final leafPaint = Paint()..color = const Color(0xFF10B981);
      final tipX = center.dx + (swayAngle * 100);
      final tipY = center.dy - 38;

      canvas.drawOval(
        Rect.fromCenter(center: Offset(tipX - 7, tipY - 3), width: 11, height: 7),
        leafPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(tipX + 7, tipY - 3), width: 11, height: 7),
        leafPaint,
      );
    } else if (level <= 4) {
      // --- FASE 2: Planta Joven ---
      final stemPaint = Paint()
        ..color = const Color(0xFF059669)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..strokeCap = StrokeCap.round;

      final stemPath = Path()
        ..moveTo(center.dx, center.dy - 5)
        ..cubicTo(
          center.dx,
          center.dy - 35,
          center.dx + (swayAngle * 100),
          center.dy - 60,
          center.dx + (swayAngle * 150),
          center.dy - 85,
        );
      canvas.drawPath(stemPath, stemPaint);

      final leafPaint = Paint()..color = const Color(0xFF10B981);
      final tipX = center.dx + (swayAngle * 150);
      final tipY = center.dy - 85;

      // Hojas de arriba
      canvas.drawOval(Rect.fromCenter(center: Offset(tipX - 12, tipY - 5), width: 18, height: 11), leafPaint);
      canvas.drawOval(Rect.fromCenter(center: Offset(tipX + 12, tipY - 5), width: 18, height: 11), leafPaint);

      // Hojas intermedias
      final midX = center.dx + (swayAngle * 80);
      final midY = center.dy - 45;
      canvas.drawOval(Rect.fromCenter(center: Offset(midX - 12, midY), width: 16, height: 9), leafPaint);
      canvas.drawOval(Rect.fromCenter(center: Offset(midX + 12, midY - 12), width: 16, height: 9), leafPaint);
    } else if (level <= 6) {
      // --- FASE 3: Arbusto ---
      final trunkPaint = Paint()
        ..color = const Color(0xFF78350F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round;

      final trunkPath = Path()
        ..moveTo(center.dx, center.dy - 5)
        ..quadraticBezierTo(
          center.dx + (swayAngle * 60),
          center.dy - 55,
          center.dx + (swayAngle * 100),
          center.dy - 100,
        );
      canvas.drawPath(trunkPath, trunkPaint);

      final foliageX = center.dx + (swayAngle * 100);
      final foliageY = center.dy - 100;

      final leafPaint = Paint()..color = const Color(0xFF10B981);
      canvas.drawCircle(Offset(foliageX, foliageY - 20), 36, leafPaint);
      canvas.drawCircle(Offset(foliageX - 22, foliageY + 2), 28, leafPaint);
      canvas.drawCircle(Offset(foliageX + 22, foliageY + 2), 28, leafPaint);

      final lightLeafPaint = Paint()..color = const Color(0xFF34D399);
      canvas.drawCircle(Offset(foliageX - 6, foliageY - 30), 14, lightLeafPaint);
      canvas.drawCircle(Offset(foliageX + 14, foliageY - 15), 12, lightLeafPaint);
    } else if (level <= 8) {
      // --- FASE 4: Árbol Maduro ---
      final trunkPaint = Paint()
        ..color = const Color(0xFF78350F)
        ..style = PaintingStyle.fill;

      final tX = center.dx + (swayAngle * 115);
      final tY = center.dy - 120;

      final trunkPath = Path()
        ..moveTo(center.dx - 10, center.dy - 5)
        ..lineTo(center.dx + 10, center.dy - 5)
        ..quadraticBezierTo(center.dx + 7, center.dy - 65, tX + 6, tY)
        ..lineTo(tX - 6, tY)
        ..quadraticBezierTo(center.dx - 7, center.dy - 65, center.dx - 10, center.dy - 5)
        ..close();
      canvas.drawPath(trunkPath, trunkPaint);

      final branchPaint = Paint()
        ..color = const Color(0xFF78350F)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      
      canvas.drawLine(Offset(center.dx, center.dy - 65), Offset(tX - 30, tY + 25), branchPaint);
      canvas.drawLine(Offset(center.dx, center.dy - 75), Offset(tX + 30, tY + 35), branchPaint);

      final foliagePaint = Paint()..color = const Color(0xFF047857);
      final foliagePaint2 = Paint()..color = const Color(0xFF10B981);
      final lightFoliage = Paint()..color = const Color(0xFF34D399);

      canvas.drawCircle(Offset(tX - 28, tY + 20), 28, foliagePaint);
      canvas.drawCircle(Offset(tX + 28, tY + 25), 28, foliagePaint);
      canvas.drawCircle(Offset(tX, tY - 15), 42, foliagePaint2);
      canvas.drawCircle(Offset(tX - 18, tY - 30), 26, lightFoliage);
      canvas.drawCircle(Offset(tX + 18, tY - 24), 24, lightFoliage);
    } else {
      // --- FASE 5: Árbol Dorado de la Fortuna 🌟 (Nivel 9+) ---
      final trunkPaint = Paint()
        ..color = const Color(0xFF78350F)
        ..style = PaintingStyle.fill;

      final tX = center.dx + (swayAngle * 125);
      final tY = center.dy - 130;

      final trunkPath = Path()
        ..moveTo(center.dx - 14, center.dy - 5)
        ..lineTo(center.dx + 14, center.dy - 5)
        ..quadraticBezierTo(center.dx + 9, center.dy - 70, tX + 8, tY)
        ..lineTo(tX - 8, tY)
        ..quadraticBezierTo(center.dx - 9, center.dy - 70, center.dx - 14, center.dy - 5)
        ..close();
      canvas.drawPath(trunkPath, trunkPaint);

      final glowPaint = Paint()
        ..color = const Color(0xFFFBBF24).withOpacity(0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
      canvas.drawCircle(Offset(tX, tY - 20), 75, glowPaint);

      final foliageDarkGold = Paint()..color = const Color(0xFFD97706);
      final foliageGold = Paint()..color = const Color(0xFFF59E0B);
      final foliageLightGold = Paint()..color = const Color(0xFFFBBF24);
      final foliageYellow = Paint()..color = const Color(0xFFFEF08A);

      canvas.drawCircle(Offset(tX - 38, tY + 12), 35, foliageDarkGold);
      canvas.drawCircle(Offset(tX + 38, tY + 18), 35, foliageDarkGold);
      
      canvas.drawCircle(Offset(tX, tY - 20), 48, foliageGold);
      canvas.drawCircle(Offset(tX - 22, tY - 32), 32, foliageLightGold);
      canvas.drawCircle(Offset(tX + 22, tY - 26), 30, foliageLightGold);

      canvas.drawCircle(Offset(tX, tY - 48), 22, foliageYellow);

      // Moneditas doradas colgando
      final coinPaint = Paint()..color = const Color(0xFFFEF08A);
      final coinBorder = Paint()
        ..color = const Color(0xFFF59E0B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;
      
      canvas.drawCircle(Offset(tX - 28, tY + 45), 7, coinPaint);
      canvas.drawCircle(Offset(tX - 28, tY + 45), 7, coinBorder);

      canvas.drawCircle(Offset(tX + 28, tY + 50), 7, coinPaint);
      canvas.drawCircle(Offset(tX + 28, tY + 50), 7, coinBorder);

      canvas.drawCircle(Offset(tX, tY + 18), 8, coinPaint);
      canvas.drawCircle(Offset(tX, tY + 18), 8, coinBorder);

      // Pequeñas estrellas de destellos
      final starPaint = Paint()..color = const Color(0xFFFEF08A);
      canvas.drawCircle(Offset(tX - 60, tY - 30), 2, starPaint);
      canvas.drawCircle(Offset(tX + 60, tY - 20), 3, starPaint);
      canvas.drawCircle(Offset(tX - 10, tY - 80), 2, starPaint);
      canvas.drawCircle(Offset(tX + 25, tY - 70), 2.5, starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant TreeVisualizerPainter oldDelegate) {
    return oldDelegate.level != level || oldDelegate.swayAngle != swayAngle || oldDelegate.isDark != isDark;
  }
}
