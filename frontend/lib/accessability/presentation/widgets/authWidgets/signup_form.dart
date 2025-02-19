import 'package:flutter/material.dart';
import 'package:frontend/accessability/logic/firebase_logic/SignupModel.dart';
import 'package:frontend/accessability/firebaseServices/auth/auth_service.dart';
import 'package:frontend/accessability/logic/firebase_logic/signUpToMongoDB.dart';
import 'package:frontend/accessability/presentation/screens/authScreens/login_screen.dart';

class SignupForm extends StatefulWidget {
  const SignupForm({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SignupFormState createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  // Controllers for the text fields
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController contactNumberController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  @override
  void dispose() {
    // Dispose of the controllers when the widget is removed from the widget tree
    usernameController.dispose();
    emailController.dispose();
    contactNumberController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void signup() async {
    final auth = AuthService();
    final signUpToMongoDB = SignUpToMongoDB();

    if (passwordController.text == confirmPasswordController.text) {
      try {
        // Attempt to sign up the user with Firebase
        await auth.signUpWithEmailAndPassword(
          emailController.text,
          passwordController.text,
          usernameController.text,
          contactNumberController.text,
        );

        // If Firebase signup is successful, create a SignUpModel instance
        final signUpModel = SignUpModel(
          username: usernameController.text,
          email: emailController.text,
          contactNumber: contactNumberController.text,
          password: passwordController.text,
        );

        // Debug: Print the signUpModel data
        print('SignUpModel: ${signUpModel.toJson()}');

        // Send data to MongoDB
        final response = await signUpToMongoDB.register(signUpModel, null);

        // Debug: Print the response from MongoDB
        print('MongoDB Response: $response');

        // Show a SnackBar and navigate back to the login page
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Successfully signed up!"),
            duration: Duration(seconds: 2),
          ),
        );

        // Wait for the SnackBar to display before navigating back
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.of(context).pop(); // Navigate back to the login page
        });
      } catch (e) {
        // Debug: Print the error
        print('Signup Error: $e');

        // Show an error dialog if signup fails
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Error"),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    } else {
      // Show an error dialog if passwords do not match
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Error"),
          content: const Text("Passwords do not match."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Sign Up',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 30,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 3.0),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 3.0),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: contactNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Contact Number',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 3.0),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  onChanged: (value) =>
                      setState(() {}), // Ensures backspace works
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 3.0),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  onChanged: (value) =>
                      setState(() {}), // Ensures backspace works
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 3.0),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: signup, // Call the signup function here
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6750A4),
                    padding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 50),
                    textStyle: const TextStyle(fontSize: 20),
                  ),
                  child: const Text(
                    'SIGN UP',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Already have an account?",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LoginScreen()),
                        );
                      },
                      child: const Text(
                        'Log In',
                        style: TextStyle(
                          color: Color(0xFF6750A4),
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
