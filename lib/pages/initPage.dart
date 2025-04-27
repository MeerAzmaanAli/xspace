import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:xspace/pages/SigninPage.dart';

class Initpage extends StatefulWidget{
  const Initpage({super.key});

  @override
  State<Initpage> createState() => _initSignin();
}
class _initSignin extends State<Initpage>{

  final SigninPage signin = SigninPage();
  
  @override
  void initState() {
    super.initState();
    init();
    
  }
  Future<void> init() async{
    try {
      final user = FirebaseAuth.instance.currentUser;
      //print(user!.displayName);
      if (user != null) {
        await signin.signInWithGoogle(context);
      }else{
        WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SigninPage()),
        );
      });
      }

    }catch (e) {
      print(e);    
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              
              Text('XSpace', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              const Center(child: CircularProgressIndicator(color: Color.fromARGB(255, 43, 43, 43))),

            ],
          ),
        ),
      ),
    );
}
}