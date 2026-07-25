import 'package:flutter/material.dart';
import 'package:beatrice/ui/core/theme.dart';

class AuthScreen extends StatefulWidget {
  final void Function(String email, String password) onSignIn;
  final void Function(String email, String password) onSignUp;
  final String? error;

  const AuthScreen({
    super.key,
    required this.onSignIn,
    required this.onSignUp,
    this.error,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignUp = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) return;

    if (_isSignUp) {
      if (password != _confirmController.text.trim()) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
        return;
      }
      if (password.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password must be at least 6 characters'),
          ),
        );
        return;
      }
      widget.onSignUp(email, password);
    } else {
      widget.onSignIn(email, password);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            _isSignUp ? 'Create your account' : 'Sign in to your account',
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          if (widget.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                widget.error!,
                style: const TextStyle(color: AppColors.red400, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          TextField(
            controller: _emailController,
            decoration: _inputDecoration('Email'),
            style: const TextStyle(color: AppColors.white, fontSize: 14),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            decoration: _inputDecoration('Password'),
            style: const TextStyle(color: AppColors.white, fontSize: 14),
            obscureText: true,
          ),
          if (_isSignUp) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              decoration: _inputDecoration('Confirm password'),
              style: const TextStyle(color: AppColors.white, fontSize: 14),
              obscureText: true,
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.black,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _isSignUp ? 'Create Account' : 'Sign In',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _isSignUp = !_isSignUp),
            child: Text(
              _isSignUp
                  ? 'Already have an account? Sign in'
                  : "Don't have an account? Create one",
              style: const TextStyle(color: AppColors.neutral400, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
    hintText: label,
    hintStyle: const TextStyle(color: AppColors.neutral400),
    filled: true,
    fillColor: AppColors.chip2121,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.divider),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.divider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.neutral600),
    ),
    contentPadding: const EdgeInsets.all(12),
  );
}
