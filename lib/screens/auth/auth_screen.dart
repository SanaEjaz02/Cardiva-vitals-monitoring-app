import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../router/app_router.dart';

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

  Future<void> _submit() async {
    final valid = _isLogin
        ? _loginFormKey.currentState!.validate()
        : _registerFormKey.currentState!.validate();
    if (!valid) return;

    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _loading = false);

    final dest = _isLogin ? AppRouter.dashboard : AppRouter.setupProfile;
    Navigator.pushReplacementNamed(context, dest);
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
              _TogglePill(
                isLogin: _isLogin,
                onToggle: _toggle,
              ),
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
                        onForgot: () {},
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
              // Social buttons
              _SocialButton(
                icon: Icons.g_mobiledata_rounded,
                label: 'Continue with Google',
                onTap: () {},
              ),
              const SizedBox(height: 12),
              _SocialButton(
                icon: Icons.apple_rounded,
                label: 'Continue with Apple',
                onTap: () {},
              ),
              const SizedBox(height: 24),
              // Terms
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
          Expanded(child: _PillTab('Register', !isLogin, () => onToggle(false))),
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
              final re = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}$');
              if (!re.hasMatch(v)) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: password,
            obscureText: !showPass,
            decoration: InputDecoration(
              hintText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                ),
                onPressed: onTogglePass,
              ),
            ),
            validator: (v) {
              if (v == null || v.length < 8) return 'Password must be 8+ characters';
              return null;
            },
          ),
          const SizedBox(height: 8),
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

class _RegisterForm extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          TextFormField(
            controller: name,
            decoration: const InputDecoration(
              hintText: 'Full name',
              prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'Email address',
              prefixIcon: Icon(Icons.email_outlined, size: 20),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Email is required';
              final re = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}$');
              if (!re.hasMatch(v)) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: password,
            obscureText: !showPass,
            decoration: InputDecoration(
              hintText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                ),
                onPressed: onTogglePass,
              ),
            ),
            validator: (v) {
              if (v == null || v.length < 8) return 'Password must be 8+ characters';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: confirm,
            obscureText: !showConfirm,
            decoration: InputDecoration(
              hintText: 'Confirm password',
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  showConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                ),
                onPressed: onToggleConfirm,
              ),
            ),
            validator: (v) {
              if (v != password.text) return 'Passwords do not match';
              return null;
            },
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
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
          Icon(icon, size: 22, color: AppColors.primary),
          const SizedBox(width: 10),
          Text(label, style: AppTextStyles.body),
        ],
      ),
    );
  }
}
