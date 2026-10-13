import 'package:dummy_apps/screens/Shop.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const String testEmail = 'nikhildager13@gmail.com';
const String testPassword = 'nikhil8822';

class FirebaseAuthScreen extends StatefulWidget {
  const FirebaseAuthScreen({super.key});

  @override
  State<FirebaseAuthScreen> createState() => _FirebaseAuthScreenState();
}

class _FirebaseAuthScreenState extends State<FirebaseAuthScreen> {
  bool _isLoading = false;

  Future<void> _authenticate({required bool createAccount}) async {
    setState(() => _isLoading = true);

    try {
      if (createAccount) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: testEmail,
          password: testPassword,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: testEmail,
          password: testPassword,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            createAccount
                ? 'Firebase sign-up successful.'
                : 'Firebase sign-in successful.',
          ),
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => Shop()),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${createAccount ? 'Sign-up' : 'Sign-in'} failed: '
            '${error.message ?? error.code}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Auth Test')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Test email: $testEmail'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isLoading
                    ? null
                    : () => _authenticate(createAccount: false),
                child: const Text('Test sign in'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () => _authenticate(createAccount: true),
                child: const Text('Sign up'),
              ),
              if (_isLoading) ...[
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
