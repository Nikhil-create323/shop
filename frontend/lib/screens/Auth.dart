import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dummy_apps/screens/Shop.dart';
import 'package:dummy_apps/screens/admin/home.dart';
import 'package:dummy_apps/main.dart';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:dummy_apps/widgets/drawer.dart';
import 'package:dummy_apps/screens/forgot-password.dart';
import 'package:dummy_apps/main.dart' show baseUrl;

import 'package:dummy_apps/utils/auth-service.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _storage = const FlutterSecureStorage();
  final String _baseUrl = baseUrl;

  // Email form controllers & state
  final _emailFormKey = GlobalKey<FormState>();
  final _emailNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _emailPasswordController = TextEditingController();
  bool _isSignUp = false;
  bool _emailPasswordVisible = false;
  bool _isLoadingEmail = false;
  String _emailLoginRole = 'user';

  // Google state
  bool _isLoadingGoogle = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailNameController.dispose();
    _emailController.dispose();
    _emailPasswordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Email Flow Submission
  Future<void> _submitEmailAuth() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() => _isLoadingEmail = true);
    final email = _emailController.text.trim();
    final password = _emailPasswordController.text;
    final name = _emailNameController.text.trim();

    try {
      final url = Uri.parse(_isSignUp ? '$_baseUrl/signup' : '$_baseUrl/login');
      final body = _isSignUp
          ? {"name": name, "email": email, "password": password}
          : {"email": email, "password": password, "role": _emailLoginRole};

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final token = data['token'];
        final user = data['user'];
        final userName = user != null && user['name'] != null
            ? user['name'].toString()
            : name;

        if (token != null) {
          await _storage.write(key: 'token', value: token);
          if (userName.isNotEmpty) {
            await AuthService.saveUserName(userName);
          }
          if (user != null) {
            print("User ID: ${user['id']}");
            print("User Name: ${user['name']}");
          }

          final decoded = JwtDecoder.decode(token);
          final resolvedRole =
              (user?['role'] ?? decoded['role'] ?? _emailLoginRole)
                  .toString()
                  .toLowerCase();

          _showSnackBar(
            _isSignUp ? 'Account created successfully!' : 'Welcome back!',
          );

          if (resolvedRole == 'admin') {
            _navigateToAdminHome();
          } else {
            _navigateToShop();
          }
        } else {
          _showSnackBar(
            'Authentication succeeded but token is missing.',
            isError: true,
          );
        }
      } else {
        _showSnackBar(
          data['message'] ?? 'Authentication failed.',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar('Network error: $e', isError: true);
    } finally {
      setState(() => _isLoadingEmail = false);
    }
  }

  // Google Authentication Trigger
  Future<void> _triggerGoogleAuth() async {
    setState(() => _isLoadingGoogle = true);

    try {
      final provider = GoogleAuthProvider();
      provider.setCustomParameters({'prompt': 'select_account'});
      final googleUser = kIsWeb
          ? await FirebaseAuth.instance.signInWithPopup(provider)
          : await FirebaseAuth.instance.signInWithProvider(provider);

      final firebaseUser = googleUser.user;
      if (firebaseUser == null) {
        throw StateError('Firebase sign-in did not return a user.');
      }

      final token = await firebaseUser.getIdToken(true);
      if (token == null || token.isEmpty) {
        throw StateError('Firebase did not provide an ID token.');
      }

      await _storage.write(key: 'token', value: token);
      final returnedName = firebaseUser.displayName ?? 'Google User';
      if (returnedName.isNotEmpty) {
        await AuthService.saveUserName(returnedName);
      }

      _showSnackBar('Logged in with Google: $returnedName');
      _navigateToShop();
    } on FirebaseAuthException catch (e) {
      final isCancelled =
          e.code == 'popup-closed-by-user' ||
          e.code == 'web-context-canceled' ||
          e.code == 'sign_in_canceled';
      _showSnackBar(
        isCancelled
            ? 'Google sign-in was canceled.'
            : e.message ?? 'Google sign-in failed.',
        isError: !isCancelled,
      );
    } catch (e) {
      _showSnackBar('Google authentication failed: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoadingGoogle = false);
      }
    }
  }

  void _navigateToShop() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => Shop()),
    );
  }

  void _navigateToAdminHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      drawer: AppDrawer(),
      // Auth screen keeps drawer as empty to avoid exposing app before login
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          'Authentication',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: 24,
            letterSpacing: 0.5,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: themeColor,
          labelColor: themeColor,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          tabs: const [
            Tab(text: 'Email', icon: Icon(Icons.email_outlined)),
            Tab(text: 'Google', icon: Icon(Icons.g_mobiledata, size: 36)),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // EMAIL TAB
            _buildEmailView(themeColor),

            // GOOGLE TAB
            _buildGoogleView(themeColor),
          ],
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildEmailView(Color themeColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _emailFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isSignUp ? 'Create Account' : 'Welcome Back',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Name Field (Only on Sign Up)
                if (_isSignUp) ...[
                  TextFormField(
                    controller: _emailNameController,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: _buildInputDecoration(
                      label: 'Full Name',
                      icon: Icons.person_outline,
                    ),
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Please enter your name'
                        : null,
                  ),
                  const SizedBox(height: 16),
                ],

                // Email Field
                TextFormField(
                  controller: _emailController,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  decoration: _buildInputDecoration(
                    label: 'Email Address',
                    icon: Icons.alternate_email,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(val.trim())) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: _emailPasswordController,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  obscureText: !_emailPasswordVisible,
                  maxLength: 128,
                  decoration: _buildInputDecoration(
                    label: 'Password',
                    icon: Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(
                        _emailPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      onPressed: () {
                        setState(() {
                          _emailPasswordVisible = !_emailPasswordVisible;
                        });
                      },
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    if (val.length > 128) {
                      return 'Password cannot exceed 128 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                if (!_isSignUp) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Login as',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ToggleButtons(
                    isSelected: [
                      _emailLoginRole == 'user',
                      _emailLoginRole == 'admin',
                    ],
                    onPressed: (index) {
                      setState(() {
                        _emailLoginRole = index == 0 ? 'user' : 'admin';
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    selectedColor: Theme.of(context).colorScheme.onPrimary,
                    fillColor: Theme.of(context).colorScheme.primary,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    constraints: const BoxConstraints(
                      minHeight: 42,
                      minWidth: 120,
                    ),
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('User'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('Admin'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // Submit Button
                ElevatedButton(
                  onPressed: _isLoadingEmail ? null : _submitEmailAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoadingEmail
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.onPrimary,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _isSignUp ? 'Sign Up' : 'Log In',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ForgotPasswordScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'Forgot password?',
                    style: TextStyle(color: themeColor),
                  ),
                ),

                // Toggle Button
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isSignUp = !_isSignUp;
                    });
                  },
                  child: Text(
                    _isSignUp
                        ? 'Already have an account? Sign In'
                        : 'New here? Create an Account',
                    style: TextStyle(
                      color: themeColor.withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleView(Color themeColor) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.g_mobiledata,
                size: 100,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Sign In with Google',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Enjoy a fast, secure and completely passwordless authentication experience using Google OAuth services.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),

            // Premium Google Button
            OutlinedButton(
              onPressed: _isLoadingGoogle ? null : _triggerGoogleAuth,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outline,
                  width: 1.5,
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerLow,
              ),
              child: _isLoadingGoogle
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.onSurface,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.network(
                          'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg',
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Continue with Google',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
    String? hint,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 14,
      ),
      hintText: hint,
      hintStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
        fontSize: 13,
      ),
      prefixIcon: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.error,
          width: 1,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.error,
          width: 1,
        ),
      ),
    );
  }
}
