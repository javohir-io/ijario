import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/picked_image.dart';
import '../../services/auth_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/phone_formatter.dart';
import '../../utils/validators.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/avatar.dart';
import '../../widgets/buttons.dart';
import '../../widgets/pressable.dart';
import '../../widgets/toast.dart';
import '../../widgets/app_backdrop.dart';
import '../../widgets/routes.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _telegram;
  final _password = TextEditingController();
  bool _busy = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final u = AuthStore.instance.currentUser!;
    _name = TextEditingController(text: u.fullName);
    _email = TextEditingController(text: u.email);
    _phone = TextEditingController(text: phoneToField(u.phone));
    _telegram = TextEditingController(text: u.telegram == null ? '' : '@${u.telegram}');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _telegram.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final file = result?.files.single;
    if (file == null || file.bytes == null) return;
    setState(() => _uploading = true);
    final error = await AuthStore.instance.uploadAvatar(PickedImage(bytes: file.bytes!, filename: file.name));
    if (!mounted) return;
    setState(() => _uploading = false);
    showToast(context, error ?? 'Rasm yangilandi', error: error != null);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final error = await AuthStore.instance.updateProfile(
      fullName: _name.text.trim(),
      email: _email.text.trim(),
      phone: fieldToPhone(_phone.text), // empty string clears it
      telegram: _telegram.text.trim().replaceFirst('@', ''),
      password: _password.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      showToast(context, error, error: true);
      return;
    }
    showToast(context, 'Saqlandi');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final user = AuthStore.instance.currentUser!;
    return BackdropScaffold(
      title: 'Profilni tahrirlash',
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.symmetric(horizontal: pageMargin(MediaQuery.of(context).size.width, maxContent: 560), vertical: 12),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Pressable(
                onTap: _uploading ? null : _pickAvatar,
                semanticLabel: "Rasmni o'zgartirish",
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Avatar(name: user.fullName, url: user.avatarUrl, size: 104),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: p.primaryFill,
                        border: Border.all(color: p.bg, width: 3),
                      ),
                      child: _uploading
                          ? Padding(
                              padding: const EdgeInsets.all(9),
                              child: CircularProgressIndicator(strokeWidth: 2, color: p.onPrimary),
                            )
                          : Icon(Icons.photo_camera_outlined, size: 18, color: p.onPrimary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              AppTextField(
                controller: _name,
                label: 'Ism va familiya',
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: Validators.name,
              ),
              const SizedBox(height: 18),
              AppTextField(
                controller: _phone,
                label: 'Telefon raqami',
                hint: '90 123 45 67',
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                inputFormatters: [UzPhoneFormatter()],
                prefix: Text('+998', style: BType.body(p.ink).copyWith(fontWeight: FontWeight.w700)),
                validator: Validators.optionalPhone,
              ),
              const SizedBox(height: 18),
              AppTextField(
                controller: _telegram,
                label: 'Telegram (ixtiyoriy)',
                hint: '@foydalanuvchi',
                textInputAction: TextInputAction.next,
                validator: Validators.optionalTelegram,
              ),
              const SizedBox(height: 18),
              AppTextField(
                controller: _email,
                label: 'Elektron pochta',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: Validators.email,
              ),
              const SizedBox(height: 18),
              AppTextField(
                controller: _password,
                label: 'Yangi parol (ixtiyoriy)',
                hint: "O'zgartirmasangiz bo'sh qoldiring",
                obscureText: true,
                textInputAction: TextInputAction.done,
                validator: (v) => (v == null || v.isEmpty) ? null : Validators.password(v),
              ),
              const SizedBox(height: 32),
              PrimaryButton(label: 'Saqlash', onPressed: _save, loading: _busy),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
