import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/auth/auth_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/auth/auth_event.dart';
import 'package:AccessAbility/accessability/logic/bloc/auth/auth_state.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_event.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_state.dart';
import 'package:AccessAbility/accessability/presentation/screens/authScreens/forgot_password_screen.dart';
import 'package:AccessAbility/accessability/presentation/screens/authScreens/signup_screen.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  _LoginFormState createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _hasNavigated = false;
  bool isBiometricEnabled = false;
  late final LocalAuthentication _localAuth;
  bool _supportState = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _deviceId; // Add this field

  @override
  void initState() {
    super.initState();
    _localAuth = LocalAuthentication();
    _localAuth.isDeviceSupported().then(
          (bool isSupported) => setState(
            () {
              _supportState = isSupported;
            },
          ),
        );

    // Check if biometric authentication is available
    _checkBiometricAvailability();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _getDeviceId(); // Fetch the device ID here
  }

  Future<void> _getDeviceId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Theme.of(context).platform == TargetPlatform.android) {
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      setState(() {
        _deviceId = androidInfo.id;
      });
    } else if (Theme.of(context).platform == TargetPlatform.iOS) {
      final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      setState(() {
        _deviceId = iosInfo.identifierForVendor;
      });
    }
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      isBiometricEnabled = await _localAuth.canCheckBiometrics;
      setState(() {}); // Update the UI
    } on PlatformException catch (e) {
      print('Error checking biometric availability: $e');
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login(BuildContext context) async {
    final email = emailController.text;
    final password = passwordController.text;

    try {
      // Authenticate the user
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Fetch user data from Firestore
        final userDoc = await _firestore.collection('Users').doc(userCredential.user!.uid).get();
        if (userDoc.exists) {
          final biometricEnabled = userDoc.data()?['biometricEnabled'] ?? false;
          final storedDeviceId = userDoc.data()?['deviceId'];
          print("biometricEnabled = ${biometricEnabled}");
          print("StoredDeviceId = ${storedDeviceId}");
          print("Current Device Id = ${_deviceId}");

          // Check if biometric is enabled and the device ID matches
          if (biometricEnabled && storedDeviceId == _deviceId) {
            // Save email and password in SharedPreferences
            print('Saving Credentials');
            final prefs = await SharedPreferences.getInstance();
            prefs.setString('biometric_email', email);
            prefs.setString('biometric_password', password);
          }
        }

        // Trigger login success
        context.read<AuthBloc>().add(LoginEvent(email: email, password: password));
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: ${e.message}')),
      );
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      bool isAvailable = await _localAuth.canCheckBiometrics;
      bool didAuthenticate = false;

      if (isAvailable) {
        didAuthenticate = await _localAuth.authenticate(
          localizedReason: 'Authenticate to login',
          options: const AuthenticationOptions(
            biometricOnly: true,
            useErrorDialogs: true,
            stickyAuth: true,
          ),
        );

        if (didAuthenticate) {
          // Retrieve saved email and password from SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          final email = prefs.getString('biometric_email');
          final password = prefs.getString('biometric_password');

          print('email fetched: ${email}');
          print('password fetched: ${password}');

          if (email != null && password != null) {
            // Log in using the saved credentials
            context.read<AuthBloc>().add(LoginEvent(email: email, password: password));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No saved credentials found')),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric authentication not available')),
        );
      }
    } catch (e) {
      print('Error using biometrics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthenticatedLogin) {
              context.read<UserBloc>().add(FetchUserData());
            } else if (state is AuthError) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Login Failed'),
                  content: Text(state.message),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            }
          },
        ),
        BlocListener<UserBloc, UserState>(
          listener: (context, userState) {
            if (userState is UserLoaded) {
              final authState = context.read<AuthBloc>().state;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted &&
                    authState is AuthenticatedLogin &&
                    !_hasNavigated) {
                  _hasNavigated = true;
                  if (authState.hasCompletedOnboarding) {
                    Navigator.pushReplacementNamed(context, '/homescreen');
                  } else {
                    Navigator.pushReplacementNamed(context, '/onboarding');
                  }
                }
              });
            }
          },
        ),
      ],
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Login',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 30,
                        fontFamily: 'Inter'),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.8,
                    ),
                    child: TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.8,
                    ),
                    child: TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordScreen(),
                        ),
                      ),
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                            color: Color(0xFF6750A4),
                            fontSize: 17,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  ElevatedButton(
                    onPressed: () => _login(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6750A4),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      minimumSize: const Size(250, 50),
                      textStyle: const TextStyle(fontSize: 20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      const Text("Don't have an account?",
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SignupScreen()),
                        ),
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(
                              color: Color(0xFF6750A4),
                              fontWeight: FontWeight.w800,
                              fontSize: 17),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 50),
                  GestureDetector(
                    onTap: _authenticateWithBiometrics,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Icon(Icons.fingerprint,
                            size: 30, color: Color(0xFF6750A4)),
                        const SizedBox(width: 8),
                        Text(
                          isBiometricEnabled
                              ? 'Login with Biometrics Enabled'
                              : 'Biometric login disabled',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}