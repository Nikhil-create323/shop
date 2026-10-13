import 'dart:convert';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:dummy_apps/main.dart';
import 'package:dummy_apps/widgets/drawer.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dummy_apps/utils/auth-service.dart';

class Payment extends StatefulWidget {
  final int amount;
  final bool cartCheckout;
  final String? productId;
  final int quantity;

  const Payment({
    super.key,
    required this.amount,
    this.cartCheckout = false,
    this.productId,
    this.quantity = 1,
  });

  @override
  State<Payment> createState() => _PaymentState();
}

class _PaymentState extends State<Payment> {
  bool _loading = false;

  String _responseError(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'] ?? decoded['error'];
        if (message is String && message.isNotEmpty) return message;
      }
    } on FormatException {
      // Use the HTTP status when the backend does not return JSON.
    }
    return '$fallback (HTTP ${response.statusCode})';
  }

  Future<void> makePayment() async {
    if (_loading) return;
    try {
      setState(() {
        _loading = true;
      });

      if (baseUrl.isEmpty) {
        baseUrl = await getDynamicBaseUrl();
      }
      final token = await AuthService.getToken();

      if (kIsWeb) {
        final response = await http.post(
          Uri.parse('${baseUrl}/api/create-checkout-session'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'amount': widget.amount,
            'cartCheckout': widget.cartCheckout,
            if (!widget.cartCheckout) ...{
              'productId': widget.productId,
              'quantity': widget.quantity,
            },
          }),
        );

        if (response.statusCode != 200) {
          throw Exception(
            _responseError(response, 'Unable to create checkout session'),
          );
        }

        final decoded = jsonDecode(response.body);
        final checkoutUrl = decoded is Map<String, dynamic>
            ? decoded['url']
            : null;
        final checkoutUri = checkoutUrl is String
            ? Uri.tryParse(checkoutUrl)
            : null;
        if (checkoutUri == null ||
            !checkoutUri.hasScheme ||
            checkoutUri.host.isEmpty ||
            (checkoutUri.scheme != 'https' &&
                checkoutUri.host != 'localhost')) {
          throw Exception('Checkout URL is missing');
        }

        final launched = await launchUrl(
          checkoutUri,
          webOnlyWindowName: '_self',
        );
        if (!launched) {
          throw Exception('Unable to open Stripe Checkout');
        }
        return;
      }

      final response = await http.post(
        Uri.parse('${baseUrl}/api/create-payment-intent'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'amount': widget.amount,
          'cartCheckout': widget.cartCheckout,
          if (!widget.cartCheckout) ...{
            'productId': widget.productId,
            'quantity': widget.quantity,
          },
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(_responseError(response, 'Unable to create payment'));
      }

      final decoded = jsonDecode(response.body);
      final clientSecret = decoded is Map<String, dynamic>
          ? decoded['clientSecret']
          : null;
      final paymentIntentId = decoded is Map<String, dynamic>
          ? decoded['paymentIntentId']
          : null;
      if (clientSecret is! String ||
          clientSecret.isEmpty ||
          paymentIntentId is! String ||
          paymentIntentId.isEmpty) {
        throw Exception('Payment service returned incomplete payment details');
      }

      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        // MOBILE: Use the native PaymentSheet on Android and iOS.
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            merchantDisplayName: 'My Store',
            paymentIntentClientSecret: clientSecret,
          ),
        );

        await Stripe.instance.presentPaymentSheet();
      } else {
        throw UnsupportedError(
          'Stripe payments are not supported on ${defaultTargetPlatform.name}. '
          'Run the web build in a browser or use Android/iOS.',
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment Successful')));

      Navigator.pop(context, {
        'success': true,
        'paymentIntentId': paymentIntentId,
      });
    } on StripeException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.error.localizedMessage ?? 'Payment cancelled'),
        ),
      );
      Navigator.pop(context, {'success': false});
      print(e.error.localizedMessage);
    } catch (e) {
      if (!mounted) return;

      print("error : ${e}");

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Payment failed: $e')));
      if (Navigator.of(context).canPop()) {
        Navigator.pop(context, {'success': false});
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      makePayment();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Payment'),
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: makePayment,
                child: const Text('Retry Payment'),
              ),
      ),
    );
  }
}
