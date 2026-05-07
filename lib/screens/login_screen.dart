import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      if (_isLogin) {
        final result = await authService.signIn(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        if (result == null && mounted) {
          _showError('Error al iniciar sesión. Verifica tus credenciales.');
        }
      } else {
        final displayName = '${_nameController.text.trim()} ${_lastNameController.text.trim()}';
        final result = await authService.register(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          displayName,
        );
        if (result == null && mounted) {
          _showError('Error al registrar usuario. Intenta con otro correo.');
        }
      }
    } catch (e) {
      _showError('Ocurrió un error inesperado.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final primaryColor = const Color(0xFF6366F1); // Indigo moderno
    final secondaryColor = const Color(0xFF4F46E5);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Fondo con gradiente dinámico y círculos decorativos
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF0F172A), const Color(0xFF1E1B4B)]
                    : [const Color(0xFFEEF2F6), const Color(0xFFE0E7FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Círculo decorativo desenfocado 1
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withOpacity(isDark ? 0.2 : 0.15),
              ),
            ),
          ),
          // Círculo decorativo desenfocado 2
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEC4899).withOpacity(isDark ? 0.15 : 0.1), // Rosa neon suave
              ),
            ),
          ),
          // Filtro de desenfoque general para el fondo
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: const SizedBox.shrink(),
            ),
          ),
          // Contenido principal
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Encabezado animado / Icono Premium
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: primaryColor.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 52,
                          color: isDark ? Colors.white : primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isLogin ? 'Bienvenido' : 'Crear Cuenta',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isLogin
                            ? 'Inicia sesión para gestionar tus finanzas diarias'
                            : 'Regístrate para tomar el control de tus gastos',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Tarjeta con efecto Glassmorphism para los campos del formulario
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.04)
                                  : Colors.white.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.white.withOpacity(0.4),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (!_isLogin) ...[
                                  // Nombre
                                  _buildTextField(
                                    controller: _nameController,
                                    label: 'Nombre',
                                    icon: Icons.person_outline,
                                    isDark: isDark,
                                    primaryColor: primaryColor,
                                    validator: (v) => v!.isEmpty ? 'Ingresa tu nombre' : null,
                                  ),
                                  const SizedBox(height: 16),
                                  // Apellido
                                  _buildTextField(
                                    controller: _lastNameController,
                                    label: 'Apellido',
                                    icon: Icons.people_outline,
                                    isDark: isDark,
                                    primaryColor: primaryColor,
                                    validator: (v) => v!.isEmpty ? 'Ingresa tu apellido' : null,
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Correo Electrónico
                                _buildTextField(
                                  controller: _emailController,
                                  label: 'Correo Electrónico',
                                  icon: Icons.mail_outline_rounded,
                                  keyboardType: TextInputType.emailAddress,
                                  isDark: isDark,
                                  primaryColor: primaryColor,
                                  validator: (v) {
                                    if (v!.isEmpty) return 'Ingresa tu correo';
                                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                                      return 'Correo no válido';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Contraseña
                                _buildTextField(
                                  controller: _passwordController,
                                  label: 'Contraseña',
                                  icon: Icons.lock_outline_rounded,
                                  obscureText: _obscurePassword,
                                  isDark: isDark,
                                  primaryColor: primaryColor,
                                  validator: (v) => v!.length < 6 ? 'Mínimo 6 caracteres' : null,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                 ),
                                 if (_isLogin) ...[
                                   Align(
                                     alignment: Alignment.centerRight,
                                     child: TextButton(
                                       onPressed: _showForgotPasswordDialog,
                                       style: TextButton.styleFrom(
                                         padding: EdgeInsets.zero,
                                         minimumSize: const Size(50, 30),
                                         tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                         foregroundColor: primaryColor,
                                       ),
                                       child: const Text(
                                         '¿Olvidaste tu contraseña?',
                                         style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                       ),
                                     ),
                                   ),
                                   const SizedBox(height: 16),
                                 ] else ...[
                                   const SizedBox(height: 24),
                                 ],

                                 // Botón Premium con Gradiente
                                 Container(
                                   height: 54,
                                   decoration: BoxDecoration(
                                     gradient: LinearGradient(
                                       colors: [primaryColor, secondaryColor],
                                     ),
                                     borderRadius: BorderRadius.circular(16),
                                     boxShadow: [
                                       BoxShadow(
                                         color: primaryColor.withOpacity(0.3),
                                         blurRadius: 12,
                                         offset: const Offset(0, 6),
                                       ),
                                     ],
                                   ),
                                   child: ElevatedButton(
                                     onPressed: _isLoading ? null : _submit,
                                     style: ElevatedButton.styleFrom(
                                       backgroundColor: Colors.transparent,
                                       shadowColor: Colors.transparent,
                                       shape: RoundedRectangleBorder(
                                         borderRadius: BorderRadius.circular(16),
                                       ),
                                     ),
                                     child: _isLoading
                                         ? const SizedBox(
                                             height: 24,
                                             width: 24,
                                             child: CircularProgressIndicator(
                                               strokeWidth: 2.5,
                                               valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                             ),
                                           )
                                         : Text(
                                             _isLogin ? 'Iniciar Sesión' : 'Registrar Cuenta',
                                             style: const TextStyle(
                                               fontSize: 16,
                                               fontWeight: FontWeight.bold,
                                               color: Colors.white,
                                             ),
                                           ),
                                   ),
                                 ),

                                 // Inicio de Sesión Social con Google (Solo si no está cargando)
                                 if (!_isLoading) ...[
                                   const SizedBox(height: 20),
                                   Row(
                                     children: [
                                       Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.grey[300])),
                                       Padding(
                                         padding: const EdgeInsets.symmetric(horizontal: 16),
                                         child: Text(
                                           'O bien continúa con',
                                           style: TextStyle(
                                             fontSize: 12,
                                             color: isDark ? Colors.grey[500] : Colors.grey[600],
                                           ),
                                         ),
                                       ),
                                       Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.grey[300])),
                                     ],
                                   ),
                                   const SizedBox(height: 16),
                                   OutlinedButton.icon(
                                     onPressed: _submitGoogle,
                                     style: OutlinedButton.styleFrom(
                                       foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
                                       backgroundColor: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
                                       side: BorderSide(
                                         color: isDark ? Colors.white10 : Colors.grey[300]!,
                                         width: 1.5,
                                       ),
                                       shape: RoundedRectangleBorder(
                                         borderRadius: BorderRadius.circular(16),
                                       ),
                                       padding: const EdgeInsets.symmetric(vertical: 13),
                                     ),
                                     icon: Image.network(
                                       'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1024px-Google_%22G%22_logo.svg.png',
                                       height: 18,
                                       width: 18,
                                     ),
                                     label: const Text(
                                       'Iniciar con Google',
                                       style: TextStyle(
                                         fontSize: 14,
                                         fontWeight: FontWeight.bold,
                                       ),
                                     ),
                                   ),
                                 ],
                               ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Botón para cambiar entre Login y Registro con micro-interacciones
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLogin = !_isLogin;
                            _formKey.currentState?.reset();
                          });
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Roboto',
                              color: isDark ? Colors.grey[400] : Colors.grey[700],
                            ),
                            children: [
                              TextSpan(
                                text: _isLogin ? '¿No tienes una cuenta? ' : '¿Ya tienes una cuenta? ',
                              ),
                              TextSpan(
                                text: _isLogin ? 'Regístrate' : 'Inicia Sesión',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
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
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    required bool isDark,
    required Color primaryColor,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        fontSize: 15,
        color: isDark ? Colors.white : const Color(0xFF1E293B),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? Colors.grey[400] : Colors.grey[600],
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: isDark ? Colors.grey[400] : Colors.grey[500]),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark ? Colors.black.withOpacity(0.2) : Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: primaryColor.withOpacity(0.7),
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Colors.redAccent,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Colors.redAccent,
            width: 1.5,
          ),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController(text: _emailController.text);
    final dialogFormKey = GlobalKey<FormState>();
    bool isResetting = false;

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = const Color(0xFF6366F1);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1B4B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.lock_reset_rounded, color: primaryColor),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Recuperar Cuenta',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ],
              ),
              content: Form(
                key: dialogFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Ingresa tu correo electrónico registrado y te enviaremos las instrucciones para restablecer tu contraseña.',
                      style: TextStyle(fontSize: 13, height: 1.4, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v!.isEmpty) return 'Ingresa tu correo';
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                          return 'Correo no válido';
                        }
                        return null;
                      },
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      decoration: InputDecoration(
                        labelText: 'Correo Electrónico',
                        labelStyle: const TextStyle(fontSize: 14),
                        prefixIcon: const Icon(Icons.mail_outline_rounded),
                        filled: true,
                        fillColor: isDark ? Colors.black26 : Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white10 : Colors.grey[200]!,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: primaryColor.withOpacity(0.7),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isResetting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isResetting
                      ? null
                      : () async {
                          if (!dialogFormKey.currentState!.validate()) return;
                          setDialogState(() => isResetting = true);
                          
                          final authService = Provider.of<AuthService>(context, listen: false);
                          final email = emailController.text.trim();
                          final success = await authService.sendPasswordReset(email);
                          
                          if (mounted) {
                            Navigator.of(context).pop();
                            if (success) {
                              _showSuccess('¡Correo enviado con éxito! Revisa tu bandeja de entrada. 📬🔓');
                            } else {
                              _showError('No pudimos enviar el correo. Verifica si la cuenta existe.');
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: isResetting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Enviar Instrucciones', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitGoogle() async {
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);

    try {
      final user = await authService.signInWithGoogle();
      if (user != null && mounted) {
        _showSuccess('¡Bienvenido a Arbórea! 🌳🚀');
      }
    } catch (e) {
      debugPrint('Error en _submitGoogle: $e');
      if (mounted) {
        _showError(
          'No se pudo conectar con Google.\nConfigura tu huella SHA-1 en Firebase para habilitarlo.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
