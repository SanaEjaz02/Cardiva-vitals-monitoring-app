import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../router/app_router.dart';

// Returns 0 (empty) to 5 (very strong)
int _calcStrength(String p) {
  if (p.isEmpty) return 0;
  int s = 0;
  if (p.length >= 6) s++;
  if (p.length >= 10) s++;
  if (p.contains(RegExp(r'[A-Z]'))) s++;
  if (p.contains(RegExp(r'[0-9]'))) s++;
  if (p.contains(RegExp(r'[^A-Za-z0-9]'))) s++;
  return s;
}

// Maps score → label
String _strengthLabel(int s) {
  switch (s) {
    case 1:
      return 'Weak';
    case 2:
      return 'Fair';
    case 3:
      return 'Good';
    case 4:
      return 'Strong';
    case 5:
      return 'Very Strong';
    default:
      return '';
  }
}

// Maps score → colour
Color _strengthColor(int s) {
  switch (s) {
    case 1:
      return AppColors.danger;
    case 2:
      return AppColors.warning;
    case 3:
      return AppColors.warning;
    case 4:
      return AppColors.primary;
    case 5:
      return AppColors.success;
    default:
      return AppColors.divider;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool _isLogin = true;
  late AnimationController _switchController;

  // Login fields
  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmail = TextEditingController();
  final _loginPass = TextEditingController();
  bool _loginPassVisible = false;

  // Register fields
  final _registerFormKey = GlobalKey<FormState>();
  final _registerName = TextEditingController();
  final _registerEmail = TextEditingController();
  final _registerPass = TextEditingController();
  final _registerConfirm = TextEditingController();
  bool _registerPassVisible = false;
  bool _registerConfirmVisible = false;

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _switchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _switchController.dispose();
    _loginEmail.dispose();
    _loginPass.dispose();
    _registerName.dispose();
    _registerEmail.dispose();
    _registerPass.dispose();
    _registerConfirm.dispose();
    super.dispose();
  }

  void _toggle(bool login) {
    if (_isLogin == login) return;
    setState(() => _isLogin = login);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submit() async {
    final valid = _isLogin
        ? _loginFormKey.currentState!.validate()
        : _registerFormKey.currentState!.validate();
    if (!valid) return;

    setState(() => _loading = true);
    try {
      if (_isLogin) {
        await AuthService.signInWithEmail(
          email: _loginEmail.text.trim(),
          password: _loginPass.text,
        );
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRouter.dashboard);
        return; // skip finally setState — widget is gone
      } else {
        final cred = await AuthService.signUpWithEmail(
          email: _registerEmail.text.trim(),
          password: _registerPass.text,
        );
        await cred.user?.updateDisplayName(_registerName.text.trim());
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRouter.setupProfile);
        return; // skip finally setState — widget is gone
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    try {
      final result = await AuthService.signInWithGoogle();
      if (result == null) {
        // user cancelled — just stop loading
        if (mounted) setState(() => _loading = false);
        return;
      }
      if (!mounted) return;
      final email = result.user?.email ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Signed in as $email'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1800),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 1800));
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRouter.dashboard);
      // widget is disposed after this — do not setState in finally
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(AuthService.friendlyError(e));
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) _showError('Google sign-in failed. Please try again.');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _appleSignIn() async {
    setState(() => _loading = true);
    try {
      final result = await AuthService.signInWithApple();
      if (!mounted) return;
      final email = result.user?.email ?? '';
      if (email.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Signed in as $email'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(milliseconds: 1800),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 1800));
        if (!mounted) return;
      }
      Navigator.pushReplacementNamed(context, AppRouter.dashboard);
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(AuthService.friendlyError(e));
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) _showError('Apple sign-in failed. Please try again.');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showForgotDialog() async {
    final ctrl = TextEditingController(text: _loginEmail.text.trim());
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ForgotDialog(emailController: ctrl),
    );
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              // Logo + brand
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      gradient: AppColors.heroCard,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.monitor_heart_outlined,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text('Cardiva',
                      style: AppTextStyles.h1.copyWith(fontSize: 20)),
                ],
              ),
              const SizedBox(height: 32),
              // Toggle pill
              _TogglePill(isLogin: _isLogin, onToggle: _toggle),
              const SizedBox(height: 32),
              // Form
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _isLogin
                    ? _LoginForm(
                        key: const ValueKey('login'),
                        formKey: _loginFormKey,
                        email: _loginEmail,
                        password: _loginPass,
                        showPass: _loginPassVisible,
                        onTogglePass: () => setState(
                            () => _loginPassVisible = !_loginPassVisible),
                        onForgot: _showForgotDialog,
                      )
                    : _RegisterForm(
                        key: const ValueKey('register'),
                        formKey: _registerFormKey,
                        name: _registerName,
                        email: _registerEmail,
                        password: _registerPass,
                        confirm: _registerConfirm,
                        showPass: _registerPassVisible,
                        showConfirm: _registerConfirmVisible,
                        onTogglePass: () => setState(
                            () => _registerPassVisible = !_registerPassVisible),
                        onToggleConfirm: () => setState(() =>
                            _registerConfirmVisible = !_registerConfirmVisible),
                      ),
              ),
              const SizedBox(height: 20),
              // CTA button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(_isLogin ? 'Continue' : 'Create Account'),
                ),
              ),
              const SizedBox(height: 20),
              // Divider
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or', style: AppTextStyles.caption),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),
              // Google — shown on all mobile platforms
              _SocialButton(
                assetLogo: _SocialLogo.google,
                label: 'Continue with Google',
                onTap: _loading ? null : _googleSignIn,
              ),
              // Apple — iOS only
              if (Platform.isIOS) ...[
                const SizedBox(height: 12),
                _SocialButton(
                  assetLogo: _SocialLogo.apple,
                  label: 'Continue with Apple',
                  onTap: _loading ? null : _appleSignIn,
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'By signing up you agree to our Terms and Privacy Policy',
                style: AppTextStyles.caption.copyWith(fontSize: 11),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Forgot password dialog ───────────────────────────────────────────────────

class _ForgotDialog extends StatefulWidget {
  final TextEditingController emailController;
  const _ForgotDialog({required this.emailController});

  @override
  State<_ForgotDialog> createState() => _ForgotDialogState();
}

class _ForgotDialogState extends State<_ForgotDialog> {
  bool _loading = false;
  bool _sent = false;
  String? _error;

  Future<void> _send() async {
    final email = widget.emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email address.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.sendPasswordReset(email);
      if (mounted) setState(() => _sent = true);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset Password'),
      content: _sent
          ? Text(
              'A reset link has been sent to ${widget.emailController.text.trim()}.\n\nCheck your inbox and follow the link.',
              style: AppTextStyles.body,
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Enter your email and we'll send a reset link.",
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: widget.emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Email address',
                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(
                        color: AppColors.danger, fontSize: 12),
                  ),
                ],
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_sent ? 'Done' : 'Cancel'),
        ),
        if (!_sent)
          TextButton(
            onPressed: _loading ? null : _send,
            child: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send'),
          ),
      ],
    );
  }
}

// ─── Toggle pill ─────────────────────────────────────────────────────────────

class _TogglePill extends StatelessWidget {
  final bool isLogin;
  final ValueChanged<bool> onToggle;

  const _TogglePill({required this.isLogin, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(child: _PillTab('Login', isLogin, () => onToggle(true))),
          Expanded(
              child: _PillTab('Register', !isLogin, () => onToggle(false))),
        ],
      ),
    );
  }
}

class _PillTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _PillTab(this.label, this.active, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: active ? AppColors.bgWhite : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: AppColors.shadowSm,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(
              color: active ? AppColors.primary : AppColors.textSecondary,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Login form ───────────────────────────────────────────────────────────────

class _LoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final bool showPass;
  final VoidCallback onTogglePass;
  final VoidCallback onForgot;

  const _LoginForm({
    super.key,
    required this.formKey,
    required this.email,
    required this.password,
    required this.showPass,
    required this.onTogglePass,
    required this.onForgot,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          TextFormField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'Email address',
              prefixIcon: Icon(Icons.email_outlined, size: 20),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Email is required';
              if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(v)) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: password,
            obscureText: !showPass,
            decoration: InputDecoration(
              hintText: 'Password',
              prefixIcon:
                  const Icon(Icons.lock_outline_rounded, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  showPass
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                ),
                onPressed: onTogglePass,
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              return null;
            },
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onForgot,
              child: Text(
                'Forgot password?',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Register form (StatefulWidget for password strength) ────────────────────

class _RegisterForm extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController name;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController confirm;
  final bool showPass;
  final bool showConfirm;
  final VoidCallback onTogglePass;
  final VoidCallback onToggleConfirm;

  const _RegisterForm({
    super.key,
    required this.formKey,
    required this.name,
    required this.email,
    required this.password,
    required this.confirm,
    required this.showPass,
    required this.showConfirm,
    required this.onTogglePass,
    required this.onToggleConfirm,
  });

  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  int _strength = 0;

  @override
  void initState() {
    super.initState();
    widget.password.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    if (!mounted) return;
    setState(() => _strength = _calcStrength(widget.password.text));
  }

  @override
  void dispose() {
    widget.password.removeListener(_onPasswordChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: widget.name,
            decoration: const InputDecoration(
              hintText: 'Full name',
              prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: widget.email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'Email address',
              prefixIcon: Icon(Icons.email_outlined, size: 20),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Email is required';
              if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(v)) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: widget.password,
            obscureText: !widget.showPass,
            decoration: InputDecoration(
              hintText: 'Password',
              prefixIcon:
                  const Icon(Icons.lock_outline_rounded, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  widget.showPass
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                ),
                onPressed: widget.onTogglePass,
              ),
            ),
            validator: (v) {
              if (v == null || v.length < 8) {
                return 'Password must be at least 8 characters';
              }
              return null;
            },
          ),
          // Password strength bar — only shown when user has typed something
          if (_strength > 0) ...[
            const SizedBox(height: 8),
            _PasswordStrengthBar(strength: _strength),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: widget.confirm,
            obscureText: !widget.showConfirm,
            decoration: InputDecoration(
              hintText: 'Confirm password',
              prefixIcon:
                  const Icon(Icons.lock_outline_rounded, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  widget.showConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                ),
                onPressed: widget.onToggleConfirm,
              ),
            ),
            validator: (v) {
              if (v != widget.password.text) return 'Passwords do not match';
              return null;
            },
          ),
        ],
      ),
    );
  }
}

// ─── Password strength bar ────────────────────────────────────────────────────

class _PasswordStrengthBar extends StatelessWidget {
  final int strength; // 1–5

  const _PasswordStrengthBar({required this.strength});

  @override
  Widget build(BuildContext context) {
    // Map score 1-5 → 1-4 filled bars
    final filledBars = (strength / 5 * 4).ceil().clamp(1, 4);
    final color = _strengthColor(strength);
    final label = _strengthLabel(strength);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: i < filledBars ? color : AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─── Social button ────────────────────────────────────────────────────────────

enum _SocialLogo { google, apple }

class _SocialButton extends StatelessWidget {
  final _SocialLogo assetLogo;
  final String label;
  final VoidCallback? onTap;

  const _SocialButton({
    required this.assetLogo,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: AppColors.accentTint),
        foregroundColor: AppColors.textPrimary,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (assetLogo == _SocialLogo.google)
            _GoogleG()
          else
            const Icon(Icons.apple_rounded, size: 22,
                color: AppColors.textPrimary),
          const SizedBox(width: 10),
          Text(label, style: AppTextStyles.body),
        ],
      ),
    );
  }
}

// Draws the Google "G" lettermark using coloured text (no asset needed)
class _GoogleG extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4285F4),
          ),
        ),
      ),
    );
  }
}
