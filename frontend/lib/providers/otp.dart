import 'package:firebase_auth/firebase_auth.dart';

final FirebaseAuth auth = FirebaseAuth.instance;

var _verificationId = "";

Future<void> sendOTP(String phoneNumber) async {
  await auth.verifyPhoneNumber(
    phoneNumber: phoneNumber,

    verificationCompleted: (PhoneAuthCredential credential) async {
      // Auto verification (Android)
      await auth.signInWithCredential(credential);
    },

    verificationFailed: (FirebaseAuthException e) {
      print(e.message);
      print(e.code);
    },

    codeSent: (String verificationId, int? resendToken) {
      print("OTP Sent");

      _verificationId = verificationId;
    },

    codeAutoRetrievalTimeout: (String verificationId) {
      _verificationId = verificationId;
    },
  );
}

Future<String?> verifyOTP(String otp) async {
  try {
    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: _verificationId,
      smsCode: otp,
    );

    final userCredential = await auth.signInWithCredential(credential);
    final token = await userCredential.user?.getIdToken();

    print("User Logged In");
    return token;
  } on FirebaseAuthException catch (e) {
    print(e.message);
    rethrow;
  }
}
