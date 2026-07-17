import 'dart:async';
import 'dart:convert';
import 'package:dummy_apps/screens/reset-password.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:dummy_apps/main.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _loading = false;
  bool _sent = false;
  String? _error;

  int _resendSeconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() => _resendSeconds = 30);

    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _error = 'Please enter your email';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _sent = true;
        });

        _startResendTimer();
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => ResetPasswordScreen()));
      } else {
        final data = jsonDecode(response.body);

        setState(() {
          _error = data['message'] ?? 'Failed to send reset link';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (!_sent) ...[
                    const Text(
                      'Enter your email address and we will send you a password reset link.',
                    ),

                    const SizedBox(height: 16),

                    Form(
                      key: _formKey,
                      child: TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                        onChanged: (_) {
                          if (_error != null) {
                            setState(() => _error = null);
                          }
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    ElevatedButton(
                      onPressed: _sendResetLink,
                      child: const Text('Send Reset Link'),
                    ),
                  ] else ...[
                    const Icon(Icons.mark_email_read_outlined, size: 70),

                    const SizedBox(height: 16),

                    const Text(
                      'Reset link sent successfully.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Check ${_emailController.text.trim()} for the password reset email.',
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 20),

                    if (_resendSeconds > 0)
                      Text(
                        'Resend available in $_resendSeconds seconds',
                        textAlign: TextAlign.center,
                      )
                    else
                      TextButton(
                        onPressed: _sendResetLink,
                        child: const Text('Resend Link'),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}
