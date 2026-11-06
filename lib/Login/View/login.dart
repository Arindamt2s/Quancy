import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:provider/provider.dart';
import 'package:quincy/Dashboard/View/DashboardScreen.dart';
import 'package:quincy/Dashboard/View/ModeSelectionDialog.dart';
import 'package:quincy/Login/ViewModel/LoginViewModel.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  String kAppVersion = '1.0.0';
  String kAppDate = '10/31/2026';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final viewModel = context.read<LoginViewModel>();
    if (viewModel.isLoading) return; // prevent double submit

    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final success = await viewModel.login(
      _emailController.text,
      _passwordController.text,
    );

    if (!mounted) return;

    //For AI unblock this code
    //     if (success) {
    //   final mode = await showModeSelectionDialog(context);
    //   if (!mounted || mode == null) return;
    // await viewModel.saveAppMode(mode.name);
    //   Navigator.pushReplacement(
    //     context,
    //     MaterialPageRoute(builder: (_) => DashboardScreen(mode: mode)),
    //   );
    // } else {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(
    //       content: Text(viewModel.errorMessage ?? 'Login failed'),
    //       backgroundColor: Colors.red,
    //     ),
    //   );
    // }

    if (success) {
      // --- Mode selection dialog disabled ---
      // final mode = await showModeSelectionDialog(context);
      // if (!mounted || mode == null) return;

      const mode = AppMode.online; // TODO: replace with your default mode
      await viewModel.saveAppMode(mode.name);
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => DashboardScreen(mode: mode)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(viewModel.errorMessage ?? 'Login failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter email';
    }

    final emailRegex = RegExp(r'^[\w.\-]+@([\w\-]+\.)+[\w\-]{2,}$');

    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter password';
    }

    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }

    return null;
  }

  OutlineInputBorder _border({double width = 1}) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(width: width),
  );

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LoginViewModel>();
    final emailServerError = viewModel.fieldErrors['email']?.first;
    final passwordServerError = viewModel.fieldErrors['password']?.first;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Center(
                    child: Image.asset(
                      'assets/images/newlogo.png',
                      height: 120,
                      width: 120,
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 35),

                  const Text(
                    'Welcome to Quincy',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Please login to your account',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey),
                  ),

                  const SizedBox(height: 35),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    enabled: !viewModel.isLoading,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    onChanged: (_) => viewModel.clearFieldError('email'),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter your email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      errorText: emailServerError,
                      border: _border(),
                      enabledBorder: _border(),
                      focusedBorder: _border(width: 2),
                    ),
                    validator: _validateEmail,
                  ),

                  const SizedBox(height: 20),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    enabled: !viewModel.isLoading,
                    obscureText: !_isPasswordVisible,
                    textInputAction: TextInputAction.done,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    onChanged: (_) => viewModel.clearFieldError('password'),
                    onFieldSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      errorText: passwordServerError,

                      // Show / Hide password
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),

                      border: _border(),
                      enabledBorder: _border(),
                      focusedBorder: _border(width: 2),
                    ),
                    validator: _validatePassword,
                  ),

                  const SizedBox(height: 30),

                  // Login Button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: viewModel.isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.blue.shade300,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: viewModel.isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'Login',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 25),

                  // Version & Date
                  Text(
                    'Version $kAppVersion',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    kAppDate,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
