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

class Payment extends StatefulWidget {
  final int amount;

  const Payment({super.key, required this.amount});

  @override
  State<Payment> createState() => _PaymentState();
}

class _PaymentState extends State<Payment> {
  bool _loading = false;

  Future<void> makePayment() async {
    try {
      setState(() {
        _loading = true;
      });

      if (baseUrl.isEmpty) {
        baseUrl = await getDynamicBaseUrl();
      }

      if (kIsWeb) {
        final response = await http.post(
          Uri.parse('${baseUrl}/api/create-checkout-session'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'amount': widget.amount}),
        );

        if (response.statusCode != 200) {
          throw Exception('Unable to create checkout session');
        }

        final data = jsonDecode(response.body);
        final checkoutUrl = data['url'];
        if (checkoutUrl is! String || checkoutUrl.isEmpty) {
          throw Exception('Checkout URL is missing');
        }

        final launched = await launchUrl(
          Uri.parse(checkoutUrl),
          webOnlyWindowName: '_self',
        );
        if (!launched) {
          throw Exception('Unable to open Stripe Checkout');
        }
        return;
      }

      final response = await http.post(
        Uri.parse('${baseUrl}/api/create-payment-intent'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'amount': widget.amount}),
      );

      if (response.statusCode != 200) {
        throw Exception('Unable to create payment');
      }

      final data = jsonDecode(response.body);
      final clientSecret = data['clientSecret'];
      final paymentIntentId = data['paymentIntentId'];

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
      Navigator.pop(context, {'success': false});
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
