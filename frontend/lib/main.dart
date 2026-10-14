import 'dart:convert';
import 'package:dummy_apps/providers/cart_provider.dart';
import 'package:dummy_apps/providers/products_provider.dart';
import 'package:dummy_apps/screens/Shop.dart';
import 'package:dummy_apps/screens/Auth.dart';
import 'package:dummy_apps/screens/admin/home.dart';
import 'package:dummy_apps/widgets/drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'package:device_info_plus/device_info_plus.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';

import 'package:flutter_stripe/flutter_stripe.dart';

import 'screens/firebaseAuth.dart';

const storage = FlutterSecureStorage();
final appScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
String baseUrl = '';
const configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');

//to bypass SSL certificate verification for development purposes
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

Future<String> getDynamicBaseUrl() async {
  if (configuredApiBaseUrl.isNotEmpty) return configuredApiBaseUrl;
  if (kIsWeb) return 'http://localhost:3000';

  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  if (Platform.isAndroid) {
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    if (androidInfo.isPhysicalDevice) {
      // Physical Android Device -> Use your computer's local network IP
      return 'http://10.173.221.66:3000';
    } else {
      // Android Emulator
      return 'http://10.0.2.2:3000';
    }
  }

  if (Platform.isIOS) {
    IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
    if (iosInfo.isPhysicalDevice) {
      // Physical iOS Device -> Use your computer's local network IP
      return 'http://172.30.80.1:3000';
    } else {
      // iOS Simulator
      return 'http://localhost:3000';
    }
  }

  return 'http://localhost:3000';
}

const seedColor = Color(0xFF6366F1); // Modern Indigo

var kDarkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.dark,
  ),
);

var kLightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.light,
  ),
);

Future<String> loginStatus() async {
  final token = await storage.read(key: 'token');

  if (token == null) {
    return 'auth';
  }

  bool isExpired = JwtDecoder.isExpired(token);

  if (isExpired) {
    await storage.delete(key: 'token');
    return 'auth';
  }

  final decoded = JwtDecoder.decode(token);
  final role = decoded['role']?.toString().toLowerCase();

  if (role == 'admin') return 'admin';
  return 'home';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Stripe.publishableKey =
      // 'pk_test_51Tk18ICzTsuaQsGwXHcYO5cs3GloAdraaSMgh4ZFAMRy0xUei612vV7Q7rPgWNfsP9yn5MMdT5DXsIxbtPMNyh3g00D9zSRsTz';
      'pk_test_51TkGkD2Q5c5Bkb9qazDd3nFvnc82QL01rjFSbBnzmZwpJL42OtHPnmp56r8ubAdwkoBmIJ3CYbNVolue26OK6kpQ00VJTFfdyw';

  try {
    // print('Before applySettings');
    await Stripe.instance.applySettings();
    // print('After applySettings');
  } catch (e, st) {
    print('Stripe error: $e');
    print(st);
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  baseUrl = await getDynamicBaseUrl();

  HttpOverrides.global = MyHttpOverrides();
  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    ref.read(productProvider.notifier).fetchProducts(syncInventory: false);
    ref.read(cartProvider.notifier).fetchCart();

    final checkoutStatus = Uri.base.queryParameters['checkout'];
    if (checkoutStatus == 'success' || checkoutStatus == 'cancelled') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(
              checkoutStatus == 'success'
                  ? 'Payment successful and order confirmed.'
                  : 'Payment was cancelled. Your cart is unchanged.',
            ),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: appScaffoldMessengerKey,
      theme: kLightTheme,
      darkTheme: kDarkTheme,
      themeMode: ThemeMode.light,
      home: Builder(
        builder: (context) {
          return Scaffold(
            drawer: AppDrawer(),
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: AppBar(
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              title: Text(
                "Flutter ↔ Node Test",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),

            body: FutureBuilder<String>(
              future: loginStatus(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.data == 'admin') return const HomeScreen();
                if (snapshot.data == 'home') return Shop();

                return const AuthScreen();
                // return const FirebaseAuthScreen();
              },
            ),
          );
        },
      ),
    );
  }
}
