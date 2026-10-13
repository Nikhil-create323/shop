import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

const FlutterSecureStorage storage = FlutterSecureStorage();

class AuthService {
  static Future<void> saveToken(String token) async {
    await storage.write(key: 'token', value: token);
  }

  static Future<void> saveUserName(String name) async {
    await storage.write(key: 'name', value: name);
  }

  static Future<String?> getToken() async {
    return await storage.read(key: 'token');
  }

  static Future<String?> getUserName() async {
    return await storage.read(key: 'name');
  }

  static Future<String?> getRole() async {
    final token = await getToken();
    if (token == null || JwtDecoder.isExpired(token)) return null;

    final decoded = JwtDecoder.decode(token);
    return decoded['role']?.toString();
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    if (token == null) return false;
    return !JwtDecoder.isExpired(token);
  }

  Future<String?> getUserId() async {
    final token = await getToken();
    if (token == null) return null;
    final decoded = JwtDecoder.decode(token);
    return decoded['userId']?.toString();
  }

  static Future<void> clear() async {
    await storage.delete(key: 'token');
    await storage.delete(key: 'name');
  }
}
