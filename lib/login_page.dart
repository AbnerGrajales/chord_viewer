import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'main.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  Future<UserCredential> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    final GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth?.accessToken,
      idToken: googleAuth?.idToken,
    );
    return await FirebaseAuth.instance.signInWithCredential(credential);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Bloquea el botón "Atrás" en LoginPage
      child: Scaffold(
        appBar: AppBar(title: const Text('Chord Viewer - Login')),
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              try {
                await signInWithGoogle();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const ChordHomePage()),
                      (Route<dynamic> route) => false, // Limpia toda la pila
                );
              } catch (e) {
                print('Error signing in: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error signing in: $e')),
                );
              }
            },
            child: const Text('Sign in with Google'),
          ),
        ),
      ),
    );
  }
}