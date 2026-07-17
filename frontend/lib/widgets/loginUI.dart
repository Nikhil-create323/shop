// import 'dart:convert';
// import 'package:dummy_apps/screens/Shop.dart';
// import 'package:dummy_apps/widgets/signup.dart';
// import 'package:dummy_apps/main.dart';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'package:jwt_decoder/jwt_decoder.dart';

// final storage = FlutterSecureStorage();

// Future<void> login(email, password) async {
//   print("LOGIN FUNCTION STARTED");
//   final url = Uri.parse("$baseUrl/login");

//   final response = await http.post(
//     url,
//     headers: {"Content-Type": "application/json"},
//     body: jsonEncode({"email": email, "password": password}),
//   );

//   if (response.statusCode == 200) {
//     final data = jsonDecode(response.body);
//     // print("data: $data");
//     final token = data['token'];
//     try {
//       Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
//       print("Decoded Token:");
//       print(decodedToken);
//     } catch (e) {
//       print("JWT Decode Error: $e");
//     }

//     if (token != null) {
//       await storage.write(key: "token", value: token);
//       final user = data['user'];
//       if (user != null) {
//         print("User ID: ${user['id']}");
//         print("User Name: ${user['name']}");
//       }
//       print("Token: $token");
//     } else {
//       throw Exception('Token missing in /login response');
//     }
//   } else {
//     throw Exception(
//       'Login failed: ${response.statusCode} ${response.reasonPhrase}',
//     );
//   }
// }

// class LoginSheet extends StatelessWidget {
//   final emailController = TextEditingController();
//   final passwordController = TextEditingController();

//   LoginSheet({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: EdgeInsets.only(
//         bottom: MediaQuery.of(context).viewInsets.bottom,
//       ),
//       child: SafeArea(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               TextField(
//                 controller: emailController,
//                 decoration: InputDecoration(labelText: "Email"),
//               ),

//               TextField(
//                 controller: passwordController,
//                 obscureText: true,
//                 decoration: InputDecoration(labelText: "Password"),
//               ),

//               SizedBox(height: 20),

//               Row(
//                 children: [
//                   ElevatedButton(
//                     onPressed: () async {
//                       await login(
//                         emailController.text,
//                         passwordController.text,
//                       );
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(builder: (_) => Shop()),
//                       );
//                       print(emailController.text);
//                       print(passwordController.text);
//                     },
//                     child: Text("Login"),
//                   ),

//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(builder: (_) => SignUpSheet()),
//                       );
//                     },
//                     child: Text("sign up"),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
