import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/date_field.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        context.go('/login'); // router redirects logged-in users home
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.primary,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.medical_services_rounded,
                  size: 64, color: AppTheme.primary),
            ),
            const SizedBox(height: 24),
            const Text(AppConstants.appName,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(AppConstants.tagline,
                style: TextStyle(color: Colors.white70, fontSize: 16)),
          ]),
        ),
      );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false, _hide = true;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _login({String? email, String? pass, UserRole? role}) async {
    if (email == null && !_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final user = await context
          .read<AppState>()
          .login(email ?? _email.text, pass ?? _pass.text, role: role);
      if (mounted) {
        context.go(
          user.role == UserRole.doctor ? '/doctor/home' : '/patient/home',
        );
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, e.toString().replaceFirst('Exception: ', ''),
            error: true);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _form,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.medical_services_rounded,
                            size: 56, color: AppTheme.primary),
                        const SizedBox(height: 12),
                        Text('Welcome back'.localized(context),
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text('Sign in to your E-Clinic Book'.localized(context),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600)),
                        const SizedBox(height: 6),
                        Text(
                          'Doctors must use an approved account.'
                              .localized(context),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 28),
                        CustomTextField(
                            controller: _email,
                            label: 'Email',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: validateEmail),
                        CustomTextField(
                          controller: _pass,
                          label: 'Password',
                          icon: Icons.lock_outline,
                          obscure: _hide,
                          validator: validatePassword,
                          suffix: IconButton(
                              icon: Icon(_hide
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () => setState(() => _hide = !_hide)),
                        ),
                        Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                                onPressed: () => context.push('/forgot'),
                                child: const Text('Forgot Password?'))),
                        CustomButton(
                            label: 'Login',
                            loading: _loading,
                            onPressed: _login),
                        const SizedBox(height: 12),
                        CustomButton(
                            label: 'Create Account',
                            outlined: true,
                            onPressed: () => context.push('/register')),
                      ]),
                ),
              ),
            ),
          ),
        ),
      );
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _nic = TextEditingController(),
      _phone = TextEditingController();
  final _email = TextEditingController(),
      _pass = TextEditingController(),
      _confirm = TextEditingController(),
      _address = TextEditingController();
  DateTime? _dob;
  String? _gender;
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_name, _nic, _phone, _email, _pass, _confirm, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    final state = context.read<AppState>();
    try {
      await state.register(
        name: _name.text.trim(),
        email: _email.text,
        password: _pass.text,
        role: UserRole.patient,
        patient: Patient(
            id: '',
            name: _name.text.trim(),
            nic: _nic.text.trim(),
            dob: _dob!,
            gender: _gender!,
            phone: _phone.text.trim(),
            email: _email.text.trim(),
            address: _address.text.trim()),
      );
    } catch (e) {
      if (mounted) {
        showSnack(context, e.toString().replaceFirst('Exception: ', ''),
            error: true);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Create Account')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _form,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CustomTextField(
                        controller: _name,
                        label: 'Full Name',
                        icon: Icons.badge_outlined,
                        validator: (v) => requiredField(v, 'Full name')),
                    CustomTextField(
                      controller: _nic,
                      label: 'NIC / National ID',
                      icon: Icons.credit_card,
                      validator: (v) {
                        final e = requiredField(v, 'NIC');
                        if (e != null) return e;
                        return RegExp(r'^(\d{9}[VvXx]|\d{12})$')
                                .hasMatch(v!.trim())
                            ? null
                            : 'Enter a valid NIC (9 digits + V, or 12 digits)';
                      },
                    ),
                    DateField(
                        label: 'Date of Birth',
                        value: _dob,
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                        onChanged: (d) => _dob = d),
                    DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: const InputDecoration(
                          labelText: 'Gender', prefixIcon: Icon(Icons.wc)),
                      items: [
                        for (final g in AppConstants.genders)
                          DropdownMenuItem(value: g, child: Text(g))
                      ],
                      validator: (v) => v == null ? 'Select gender' : null,
                      onChanged: (v) => _gender = v,
                    ),
                    const SizedBox(height: 14),
                    CustomTextField(
                      controller: _phone,
                      label: 'Phone Number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          RegExp(r'^\+?\d{9,12}$').hasMatch((v ?? '').trim())
                              ? null
                              : 'Enter a valid phone number',
                    ),
                    CustomTextField(
                        controller: _email,
                        label: 'Email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: validateEmail),
                    CustomTextField(
                        controller: _pass,
                        label: 'Password',
                        icon: Icons.lock_outline,
                        obscure: true,
                        validator: validatePassword),
                    CustomTextField(
                        controller: _confirm,
                        label: 'Confirm Password',
                        icon: Icons.lock_outline,
                        obscure: true,
                        validator: (v) =>
                            v != _pass.text ? 'Passwords do not match' : null),
                    CustomTextField(
                        controller: _address,
                        label: 'Address',
                        icon: Icons.home_outlined,
                        maxLines: 2,
                        validator: (v) => requiredField(v, 'Address')),
                    const SizedBox(height: 6),
                    CustomButton(
                        label: 'Register',
                        loading: _loading,
                        onPressed: _submit),
                  ]),
            ),
          ),
        ),
      );
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<AppState>().auth.resetPassword(_email.text);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        error: true,
      );
      return;
    }
    if (!mounted) return;
    setState(() => _loading = false);
    showSnack(context, 'Password reset link sent to ${_email.text.trim()}');
    context.pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Forgot Password')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_reset,
                      size: 64, color: AppTheme.primary),
                  const SizedBox(height: 16),
                  const Text(
                      'Enter your email and we will send you a link to reset your password.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  CustomTextField(
                      controller: _email,
                      label: 'Email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: validateEmail),
                  CustomButton(
                      label: 'Send Reset Link',
                      loading: _loading,
                      onPressed: _send),
                ]),
          ),
        ),
      );
}
