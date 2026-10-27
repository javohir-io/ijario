import 'package:flutter/material.dart';

import '../../services/auth_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/phone_formatter.dart';
import '../../utils/validators.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/aurora_background.dart';
import '../../widgets/buttons.dart';
import '../../widgets/glass.dart';
import '../../widgets/ijario_mark.dart';
import '../../widgets/reveal.dart';
import '../../widgets/routes.dart';
import '../../widgets/toast.dart';
import '../main_shell.dart';

enum AuthMode { login, register }

/// Sign in and sign up share one screen, so switching between them keeps the
/// aurora running and (when opened from an action like "save") the result
/// still returns to whoever asked.
///
/// [popOnSuccess] = true: close with `true` once signed in (opened by
/// `requireLogin`). Otherwise replace the stack with the app.
class AuthScreen extends StatefulWidget {
  final AuthMode initialMode;
  final bool popOnSuccess;

  const AuthScreen({super.key, this.initialMode = AuthMode.login, this.popOnSuccess = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late AuthMode _mode = widget.initialMode;
  final _loginKey = GlobalKey<FormState>();
  final _registerKey = GlobalKey<FormState>();

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();

  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _switchMode() {
    setState(() => _mode = _mode == AuthMode.login ? AuthMode.register : AuthMode.login);
  }

  Future<void> _submit() async {
    final key = _mode == AuthMode.login ? _loginKey : _registerKey;
    if (!(key.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);

    final String? error;
    if (_mode == AuthMode.login) {
      error = await AuthStore.instance.login(
        email: _email.text.trim(),
        password: _password.text,
      );
    } else {
      error = await AuthStore.instance.register(
        fullName: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        phone: fieldToPhone(_phone.text),
      );
    }

    if (!mounted) return;
    setState(() => _busy = false);

    if (error != null) {
      showToast(context, error, error: true);
      return;
    }
    if (widget.popOnSuccess) {
      Navigator.of(context).pop(true);
    } else {
      Navigator.of(context).pushAndRemoveUntil(fadeRoute(const MainShell()), (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final isLogin = _mode == AuthMode.login;
    final topInset = MediaQuery.of(context).padding.top;
    final height = MediaQuery.of(context).size.height;
    const headerHeight = 230.0;

    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraBackground()),
          SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              children: [
                SizedBox(
                  height: headerHeight + topInset * 0.5,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(BSpace.page + 4, topInset + 64, BSpace.page, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const IjarioMark(size: 44),
                          const SizedBox(height: 14),
                          AnimatedSwitcher(
                            duration: BMotion.state,
                            child: Text(
                              isLogin ? 'Xush kelibsiz' : 'Hisob yarating',
                              key: ValueKey<bool>(isLogin),
                              style: BType.display(BColors.plaster),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  constraints: BoxConstraints(minHeight: height - headerHeight - topInset * 0.5),
                  padding: const EdgeInsets.fromLTRB(BSpace.page + 4, 28, BSpace.page + 4, 40),
                  decoration: BoxDecoration(
                    color: p.bg,
                    borderRadius: BRadius.top(BRadius.sheet),
                  ),
                  // Top-aligned: centering left a big empty gap above the form.
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Reveal(
                        child: AnimatedSwitcher(
                          duration: BMotion.state,
                          switchInCurve: BMotion.ease,
                          child: isLogin ? _loginForm(p) : _registerForm(p),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: topInset + 8,
            left: 12,
            child: GlassIconButton(
              icon: widget.popOnSuccess ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded,
              semanticLabel: 'Orqaga',
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordField({required TextInputAction action}) {
    final p = context.c;
    return AppTextField(
      controller: _password,
      label: 'Parol',
      hint: isLoginMode ? 'Parolingiz' : 'Kamida 6 ta belgi',
      obscureText: _obscure,
      textInputAction: action,
      autofillHints: [isLoginMode ? AutofillHints.password : AutofillHints.newPassword],
      validator: isLoginMode
          ? (v) => (v == null || v.isEmpty) ? 'Parolni kiriting' : null
          : Validators.password,
      onSubmitted: (_) => _submit(),
      suffix: IconButton(
        tooltip: _obscure ? "Parolni ko'rsatish" : 'Parolni yashirish',
        onPressed: () => setState(() => _obscure = !_obscure),
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: p.inkMuted,
        ),
      ),
    );
  }

  bool get isLoginMode => _mode == AuthMode.login;

  Widget _loginForm(BPalette p) {
    return Form(
      key: _loginKey,
      child: AutofillGroup(
        child: Column(
          key: const ValueKey<String>('login'),
          children: [
            AppTextField(
              controller: _email,
              label: 'Elektron pochta',
              hint: 'ism@mail.com',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: Validators.email,
            ),
            const SizedBox(height: 18),
            _passwordField(action: TextInputAction.done),
            const SizedBox(height: 28),
            PrimaryButton(label: 'Kirish', onPressed: _submit, loading: _busy),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Hisobingiz yo'qmi?", style: BType.small(p.inkMuted)),
                const SizedBox(width: 6),
                TextAction(label: "Ro'yxatdan o'tish", onTap: _switchMode),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _registerForm(BPalette p) {
    return Form(
      key: _registerKey,
      child: AutofillGroup(
        child: Column(
          key: const ValueKey<String>('register'),
          children: [
            AppTextField(
              controller: _name,
              label: 'Ism va familiya',
              hint: 'Aziza Karimova',
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              validator: Validators.name,
            ),
            const SizedBox(height: 18),
            AppTextField(
              controller: _phone,
              label: 'Telefon raqami',
              hint: '90 123 45 67',
              helper: "E'lon egalari va ijarachilar siz bilan shu raqam orqali bog'lanadi.",
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [UzPhoneFormatter()],
              autofillHints: const [AutofillHints.telephoneNumberNational],
              prefix: Text('+998', style: BType.body(p.ink).copyWith(fontWeight: FontWeight.w700)),
              validator: Validators.phone,
            ),
            const SizedBox(height: 18),
            AppTextField(
              controller: _email,
              label: 'Elektron pochta',
              hint: 'ism@mail.com',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: Validators.email,
            ),
            const SizedBox(height: 18),
            _passwordField(action: TextInputAction.done),
            const SizedBox(height: 28),
            PrimaryButton(label: "Ro'yxatdan o'tish", onPressed: _submit, loading: _busy),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Hisobingiz bormi?', style: BType.small(p.inkMuted)),
                const SizedBox(width: 6),
                TextAction(label: 'Kirish', onTap: _switchMode),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
