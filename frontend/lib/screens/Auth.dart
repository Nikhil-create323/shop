import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dummy_apps/screens/Shop.dart';
import 'package:dummy_apps/main.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:dummy_apps/providers/otp.dart';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:dummy_apps/widgets/drawer.dart';
import 'package:dummy_apps/screens/forgot-password.dart';
import 'package:dummy_apps/main.dart' show baseUrl;

import 'package:dummy_apps/utils/auth-service.dart';

final FirebaseAuth auth = FirebaseAuth.instance;

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

  // Phone form controllers & state
  final _phoneFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _phoneNameController =
      TextEditingController(); // For registration if phone is new
  bool _otpSent = false;
  bool _isLoadingPhone = false;
  int _resendTimerSeconds = 0;
  Timer? _timer;

  // Google state
  bool _isLoadingGoogle = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailNameController.dispose();
    _emailController.dispose();
    _emailPasswordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _phoneNameController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _resendTimerSeconds = 30;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimerSeconds == 0) {
        timer.cancel();
      } else {
        setState(() {
          _resendTimerSeconds--;
        });
      }
    });
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
          : {"email": email, "password": password};

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
          _showSnackBar(
            _isSignUp ? 'Account created successfully!' : 'Welcome back!',
          );
          _navigateToShop();
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
  Future<void> _triggerGoogleAuth(
    String dummyEmail,
    String dummyName,
    String googleId,
    String dummyImage,
  ) async {
    setState(() => _isLoadingGoogle = true);

    try {
      final url = Uri.parse('$_baseUrl/api/google-auth');
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "googleId": googleId,
          "email": dummyEmail,
          "name": dummyName,
          "profileImage": dummyImage,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final token = data['token'];
        final returnedName = data['user']?['name']?.toString() ?? dummyName;
        if (token != null) {
          await _storage.write(key: 'token', value: token);
          if (returnedName.isNotEmpty) {
            await AuthService.saveUserName(returnedName);
          }
          _showSnackBar('Logged in with Google: $returnedName');
          _navigateToShop();
        } else {
          _showSnackBar(
            'Google Auth succeeded but token is missing.',
            isError: true,
          );
        }
      } else {
        _showSnackBar(
          data['message'] ?? 'Google authentication failed.',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar('Error connecting to backend: $e', isError: true);
    } finally {
      setState(() => _isLoadingGoogle = false);
    }
  }

  void _showGoogleAccountPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return FractionallySizedBox(
          heightFactor: 0.75, // max 75% of screen height
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outline,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'Choose an account',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                Text(
                  'to continue to DummyShop',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // Scrollable content
                Expanded(
                  child: ListView(
                    children: [
                      _buildGoogleAccountItem(
                        email: 'nikhildager7@gmail.com',
                        name: 'Nikhil Dagar',
                        googleId: '1077778974450-nikhildager',
                        avatarUrl:
                            'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=120&q=80',
                      ),
                      Divider(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        height: 1,
                      ),

                      _buildGoogleAccountItem(
                        email: 'testuser@gmail.com',
                        name: 'Test User Account',
                        googleId: '1077778974450-testuser',
                        avatarUrl:
                            'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=120&q=80',
                      ),
                      Divider(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        height: 1,
                      ),

                      _buildGoogleAccountItem(
                        email: 'deepmindguest@gmail.com',
                        name: 'Guest Reviewer',
                        googleId: '1077778974450-guest',
                        avatarUrl:
                            'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?auto=format&fit=crop&w=120&q=80',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGoogleAccountItem({
    required String email,
    required String name,
    required String googleId,
    required String avatarUrl,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: CircleAvatar(
        backgroundImage: NetworkImage(avatarUrl),
        radius: 20,
      ),
      title: Text(
        name,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        email,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: 16,
      ),
      onTap: () {
        Navigator.pop(context); // Close bottom sheet
        _triggerGoogleAuth(email, name, googleId, avatarUrl);
      },
    );
  }

  void _navigateToShop() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => Shop()),
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
            Tab(text: 'Phone', icon: Icon(Icons.phone_outlined)),
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

            // PHONE TAB
            _buildPhoneView(themeColor),

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
                const SizedBox(height: 28),

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

  Widget _buildPhoneView(Color themeColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _phoneFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'OTP Authentication',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _otpSent
                      ? 'Enter the verification code sent to your phone'
                      : 'Sign up or login with your mobile phone number',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Phone field
                TextFormField(
                  controller: _phoneController,
                  enabled: !_otpSent,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  keyboardType: TextInputType.phone,
                  decoration: _buildInputDecoration(
                    label: 'Phone Number',
                    icon: Icons.phone,
                    hint: 'e.g. 9876543210',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter your phone number';
                    }
                    if (val.trim().length < 10) {
                      return 'Please enter a valid 10-digit number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // OTP View Fields (Shown once OTP is requested)
                if (_otpSent) ...[
                  // Name field for phone registration
                  TextFormField(
                    controller: _phoneNameController,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: _buildInputDecoration(
                      label: 'Full Name (For New Profiles)',
                      icon: Icons.person_outline,
                      hint: 'Optional name',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 6-digit code field
                  TextFormField(
                    controller: _otpController,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: _buildInputDecoration(
                      label: '6-digit OTP Code',
                      icon: Icons.domain_verification_outlined,
                      hint: 'Enter 6 digit code',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter the OTP';
                      }
                      if (val.trim().length < 6) {
                        return 'Please enter a valid 6-digit OTP';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                ],

                // Action Button
                ElevatedButton(
                  onPressed: _isLoadingPhone
                      ? null
                      : () async {
                          if (!_phoneFormKey.currentState!.validate()) return;

                          setState(() {
                            _isLoadingPhone = true;
                          });

                          try {
                            if (_otpSent) {
                              final token = await verifyOTP(
                                _otpController.text.trim(),
                              );
                              if (token != null) {
                                await _storage.write(
                                  key: 'token',
                                  value: token,
                                );
                                final phoneName = _phoneNameController.text
                                    .trim();
                                if (phoneName.isNotEmpty) {
                                  await AuthService.saveUserName(phoneName);
                                } else {
                                  await AuthService.saveUserName(
                                    '+91${_phoneController.text.trim()}',
                                  );
                                }
                              }

                              _showSnackBar("Login Successful");
                              _navigateToShop();
                            } else {
                              await sendOTP(
                                "+91${_phoneController.text.trim()}",
                              );

                              setState(() {
                                _otpSent = true;
                              });

                              _startResendTimer();

                              _showSnackBar("OTP Sent");
                            }
                          } catch (e) {
                            _showSnackBar(e.toString(), isError: true);
                          } finally {
                            setState(() {
                              _isLoadingPhone = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoadingPhone
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Theme.of(context).colorScheme.onPrimary,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _otpSent ? 'Verify & Continue' : 'Get OTP Code',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                ),

                if (_otpSent) ...[
                  const SizedBox(height: 12),
                  // Resend Action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _otpSent = false;
                            _otpController.clear();
                          });
                        },
                        child: Text(
                          'Change Number',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _resendTimerSeconds > 0
                            ? null
                            : () async {
                                await sendOTP(
                                  "+91${_phoneController.text.trim()}",
                                );
                                _startResendTimer();
                              },
                        child: Text(
                          _resendTimerSeconds > 0
                              ? 'Resend in ${_resendTimerSeconds}s'
                              : 'Resend OTP',
                          style: TextStyle(
                            color: _resendTimerSeconds > 0
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : themeColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
              onPressed: _isLoadingGoogle ? null : _showGoogleAccountPicker,
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




 // Request Phone OTP
  // Future<void> _requestOtp() async {
  //   if (!_phoneFormKey.currentState!.validate()) return;
  //   setState(() => _isLoadingPhone = true);
  //   final phone = _phoneController.text.trim();
  //   try {
  //     final url = Uri.parse('$_baseUrl/api/send-otp');
  //     final response = await http.post(
  //       url,
  //       headers: {"Content-Type": "application/json"},
  //       body: jsonEncode({"phone": phone}),
  //     );
  //     final data = jsonDecode(response.body);
  //     if (response.statusCode == 200 && data['success'] == true) {
  //       setState(() {
  //         _otpSent = true;
  //       });
  //       _startResendTimer();
  //       // Dynamic notification if Twilio Dev mode is active (returns OTP in response)
  //       if (data['otp'] != null) {
  //         _showSnackBar(
  //           'OTP Sent (Dev Mode)! Check console or enter ${data['otp']}',
  //         );
  //         print('[OTP Dev Mode] Code for $phone: ${data['otp']}');
  //       } else {
  //         _showSnackBar('OTP code sent successfully!');
  //       }
  //     } else {
  //       _showSnackBar(
  //         data['message'] ?? 'Failed to send OTP code.',
  //         isError: true,
  //       );
  //     }
  //   } catch (e) {
  //     _showSnackBar('Error: $e', isError: true);
  //   } finally {
  //     setState(() => _isLoadingPhone = false);
  //   }
  // }
  // Verify Phone OTP
  // Future<void> _verifyOtpAndLogin() async {
  
  //   final phone = _phoneController.text.trim();
  //   final otp = _otpController.text.trim();
  //   final name = _phoneNameController.text.trim();
  //   if (otp.length < 6) {
  //     _showSnackBar('Please enter a valid 6-digit OTP code.', isError: true);
  //     return;
  //   }
  //   setState(() => _isLoadingPhone = true);
  //   try {
  //     final url = Uri.parse('$_baseUrl/api/verify-otp');
  //     final response = await http.post(
  //       url,
  //       headers: {"Content-Type": "application/json"},
  //       body: jsonEncode({
  //         "phone": phone,
  //         "otp": otp,
  //         "name": name.isEmpty ? null : name,
  //       }),
  //     );
  //     final data = jsonDecode(response.body);
  //     if (response.statusCode == 200 && data['success'] == true) {
  //       final token = data['token'];
  //       if (token != null) {
  //         await _storage.write(key: 'token', value: token);
  //         _showSnackBar('OTP verified! Successfully logged in.');
  //         _navigateToShop();
  //       } else {
  //         _showSnackBar('OTP verified but token is missing.', isError: true);
  //       }
  //     } else {
  //       _showSnackBar(data['message'] ?? 'Incorrect OTP code.', isError: true);
  //     }
  //   } catch (e) {
  //     _showSnackBar('Error: $e', isError: true);
  //   } finally {
  //     setState(() => _isLoadingPhone = false);
  //   }
  // }