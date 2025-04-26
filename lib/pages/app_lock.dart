import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Homepage.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool isCreatingPin = false;
  bool checkPassword = false;
  bool showForgotPin = false;

  @override
  void initState() {
    super.initState();
    _checkIfPinExists();
  }

  Future<void> _checkIfPinExists() async {
    final prefs = await SharedPreferences.getInstance();
    final existingPin = prefs.getString('user_pin');
    setState(() {
      checkPassword = existingPin == null;
      isCreatingPin = checkPassword?false : true;
      showForgotPin = !isCreatingPin;
    });
  }
  Future<void> _passwordAuth() async {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Verify Google Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Enter your Google account password to reset your PIN:"),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Password"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
               try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    // Use the Google reauthentication method
                    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

                    if (googleUser == null) {

                      if (mounted){
                          ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Google sign-in failed.')),
                      );
                    }
                    
                      return;
                    }

                    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
                    
                    final AuthCredential credential = GoogleAuthProvider.credential(
                      accessToken: googleAuth.accessToken,
                      idToken: googleAuth.idToken,
                    );
                    
                    // Reauthenticate with Google credentials
                    await user.reauthenticateWithCredential(credential);
                    if (mounted){
                        Navigator.of(context).pop(); // Close dialog
                    }
                  
                    setState(() {
                      checkPassword = false;
                      isCreatingPin = true;
                      showForgotPin = false;
                    });
                    if (mounted){
                        ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Authentication successful. Set new PIN.')),
                    );
                    }
                    
                  }
                } catch (e) {
                   setState(() {
                      checkPassword = true;
                      isCreatingPin = false;
                      showForgotPin = false;
                    }); 
                  if (!mounted) return;
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reauthentication failed.')),
                  );
                }
              },
              child: const Text('Verify'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
    
  }
  Future<void> _createPin(String pin) async {
    if (pin.length == 4) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_pin', pin);
      _navigateToHome();
    }
  }



  Future<void> _validatePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPin = prefs.getString('user_pin');
    if (storedPin == pin) {
      _navigateToHome();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect PIN')),
      );
    }
  }

  Future<void> _forgotPinFlow() async {
     await _passwordAuth();
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const Homepage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = isCreatingPin ?  'Enter PIN' :'Create PIN';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: '4-digit PIN',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (checkPassword) {
                  await _passwordAuth(); 
                }else{

                   if(isCreatingPin ){
                    _createPin(_pinController.text);
                  }
                  else {
                    _validatePin(_pinController.text);
                  }
                }
               
              },
              child: Text(
                checkPassword ? 'Verify' : (isCreatingPin ? 'Unlock' : 'Create')
                ),
            ),
            if (showForgotPin)
              TextButton(
                onPressed: _forgotPinFlow,
                child: const Text('Forgot PIN?'),
              ),
          ],
        ),
      ),
    );
  }
}
