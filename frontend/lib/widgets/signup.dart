import 'dart:convert';
import 'package:dummy_apps/screens/Shop.dart';
import 'package:dummy_apps/main.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final storage = FlutterSecureStorage(); //

Future<void> signUp(name, email, password) async {
  final url = Uri.parse("$baseUrl/signup");

  final response = await http.post(
    url,
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({"email": email, "password": password, "name": name}),
  );

  if (response.statusCode == 201) {
    final data = jsonDecode(response.body);
    print(data);
    final token = data['token'];

    if (token != null && token is String) {
      await storage.write(key: 'token', value: token);
    } else {
      throw "No token received";
    }
  } else {
    // print(response.error)
    throw 'signup failed: ${response.statusCode} ${response.reasonPhrase}';
  }
}

class SignUpSheet extends StatelessWidget {
  final nameController = TextEditingController(); // New Name Controller
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  SignUpSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Use MediaQuery to handle the keyboard pushing the sheet up
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Create Account",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: "Full Name"),
              ),

              TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: "Email"),
                keyboardType: TextInputType.emailAddress,
              ),

              TextField(
                controller: passwordController,
                obscureText: true,
                maxLength: 128,
                decoration: InputDecoration(labelText: "Password"),
              ),

              SizedBox(height: 24),

              SizedBox(
                width: double.infinity, // Makes the button full-width
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await signUp(
                        nameController.text,
                        emailController.text,
                        passwordController.text,
                      );

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('you signed up successfully')),
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => Shop()),
                      ); // Close sheet on success
                    } catch (e) {
                      // Show a simple snackbar if it fails
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  },
                  child: Text("Sign Up"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
