import 'package:flutter/material.dart';

import '../../models/property.dart';
import '../../services/api_client.dart';
import '../../services/api_exception.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/uz_data.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/buttons.dart';
import '../../widgets/pressable.dart';
import '../../widgets/sheet.dart';
import '../../widgets/toast.dart';

/// Lets a signed-in person flag a listing (fake photos, wrong price, already
/// rented). Resolves to true when the report was sent.
Future<bool?> showReportSheet(BuildContext context, Property property) {
  return showIjarioSheet<bool>(context, builder: (_) => _ReportSheet(property: property));
}

class _ReportSheet extends StatefulWidget {
  final Property property;

  const _ReportSheet({required this.property});

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _reason;
  final _details = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) return;
    setState(() => _busy = true);
    try {
      await ApiClient.instance.reportProperty(
        widget.property.id,
        reason: reason,
        details: _details.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(BSpace.page, 12, BSpace.page, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Shikoyat qilish', style: BType.display(p.ink).copyWith(fontSize: 32)),
          const SizedBox(height: 6),
          Text(
            "Nima noto'g'ri? Shikoyatni moderatorlar ko'rib chiqadi.",
            style: BType.body(p.inkMuted),
          ),
          const SizedBox(height: 14),
          for (final key in UzData.reportReasons)
            Pressable(
              onTap: () => setState(() => _reason = key),
              haptic: true,
              semanticLabel: UzData.reportReasonLabel(key),
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                child: Row(
                  children: [
                    Icon(
                      _reason == key ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                      color: _reason == key ? p.brand : p.inkFaint,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        UzData.reportReasonLabel(key),
                        style: BType.body(p.ink).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          AppTextField(
            controller: _details,
            label: "Qo'shimcha izoh (ixtiyoriy)",
            maxLines: 3,
            minLines: 3,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            label: _reason == null ? 'Sababni tanlang' : 'Yuborish',
            loading: _busy,
            onPressed: _reason == null ? null : _submit,
          ),
        ],
      ),
    );
  }
}
