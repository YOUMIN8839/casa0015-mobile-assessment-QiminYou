import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {

  final String email;
  final String password;

  LoginScreen({this.email = '', this.password = ''});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late TextEditingController _emailController = TextEditingController();
  late TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      final args = ModalRoute.of(context)!.settings.arguments as Map;
      _emailController.text = args['email'];
      _passwordController.text = args['password'];
    });
  }

  void _loginWithEmail() async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      print("User logged in: ${userCredential.user}");
      // Show snackbar on successful login
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successful Logged in! Welcome! ${userCredential.user?.email}'),
          duration: Duration(seconds: 3),
        ),
      );

      // Navigate to the MainScreen or another initial route after showing the SnackBar
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => MainScreen())
      );

    } on FirebaseAuthException catch (e) {
      print("Error logging in: $e");
      // Handle errors here
    }
  }

  Future<void> _loginWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth = await googleUser
            .authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final userCredential = await _auth.signInWithCredential(credential);
        print("User logged in with Google: ${userCredential.user}");
        // Navigate to home screen or wherever
      }
    } catch (e) {
      print("Failed to sign in with Google: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            SizedBox(height: 8.0), // Add some space
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 16.0), // Add some space
            ElevatedButton(
              onPressed: _loginWithEmail,
              child: Text('Login with Email'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(
                    double.infinity, 36), // Set the minimum button size
              ),
            ),
            SizedBox(height: 8.0), // Add some space
            ElevatedButton.icon(
              icon: Image.asset('assets/images/google_logo.png', height: 24.0),
              // Google Logo
              label: Text('Sign in with Google'),
              onPressed: _loginWithGoogle,
              style: ElevatedButton.styleFrom(
                // primary: Colors.red, // Google's brand color
                // onPrimary: Colors.white,
                minimumSize: Size(
                    double.infinity, 36), // Set the minimum button size
              ),
            ),
            SizedBox(height: 24.0), // Add some space
            TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed(
                    '/register'); // Navigate to the register page
              },
              child: Text('Don\'t have an account? Register here'),
            ),
          ],
        ),
      ),
    );
  }
}

