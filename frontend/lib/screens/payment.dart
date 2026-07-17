import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:dummy_apps/main.dart';
import 'package:dummy_apps/widgets/drawer.dart';

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

      // Backend endpoint that creates PaymentIntent
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

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'My Store',
          paymentIntentClientSecret: clientSecret,
        ),
      );

      await Stripe.instance.presentPaymentSheet();

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

      if (!mounted) return;
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
