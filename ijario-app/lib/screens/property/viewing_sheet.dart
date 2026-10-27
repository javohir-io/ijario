import 'package:flutter/material.dart';

import '../../data/viewing_store.dart';
import '../../models/property.dart';
import '../../services/api_exception.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/formatters.dart';
import '../../utils/uz_data.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/buttons.dart';
import '../../widgets/pill_chip.dart';
import '../../widgets/pressable.dart';
import '../../widgets/sheet.dart';
import '../../widgets/toast.dart';

/// "Ko'rishga yozilish": pick a day and an hour, add a note, send. The
/// owner gets a request (and a chat message) and answers yes or no.
/// Resolves to true if a request was sent.
Future<bool?> showViewingSheet(BuildContext context, Property property) {
  return showIjarioSheet<bool>(context, builder: (_) => _ViewingSheet(property: property));
}

class _ViewingSheet extends StatefulWidget {
  final Property property;

  const _ViewingSheet({required this.property});

  @override
  State<_ViewingSheet> createState() => _ViewingSheetState();
}

class _ViewingSheetState extends State<_ViewingSheet> {
  late final List<DateTime> _days;
  int _dayIndex = 0;
  int? _hour;
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _days = List<DateTime>.generate(14, (i) => DateTime(now.year, now.month, now.day + i));
    // Start on the first day that still has a free slot.
    for (var i = 0; i < _days.length; i++) {
      if (UzData.viewingHours.any((h) => _slotAvailable(i, h))) {
        _dayIndex = i;
        break;
      }
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool _slotAvailable(int dayIndex, int hour) {
    final d = _days[dayIndex];
    final slot = DateTime(d.year, d.month, d.day, hour);
    return slot.isAfter(DateTime.now().add(const Duration(minutes: 30)));
  }

  String _dayLabel(int i) {
    if (i == 0) return 'Bugun';
    if (i == 1) return 'Ertaga';
    return weekdayShort(_days[i]);
  }

  Future<void> _submit() async {
    final hour = _hour;
    if (hour == null) return;
    final d = _days[_dayIndex];
    final when = DateTime(d.year, d.month, d.day, hour);
    setState(() => _busy = true);
    try {
      await ViewingStore.instance.create(
        propertyId: widget.property.id,
        when: when,
        note: _note.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
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
          Text("Ko'rishga yozilish", style: BType.display(p.ink).copyWith(fontSize: 32)),
          const SizedBox(height: 4),
          Text(widget.property.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: BType.small(p.inkMuted)),
          const SizedBox(height: 22),
          Text('Kun', style: BType.title(p.ink)),
          const SizedBox(height: 10),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _days.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final selected = i == _dayIndex;
                final hasSlots = UzData.viewingHours.any((h) => _slotAvailable(i, h));
                final fg = selected ? p.onSelected : p.ink;
                return Opacity(
                  opacity: hasSlots ? 1 : 0.35,
                  child: Pressable(
                    onTap: hasSlots
                        ? () => setState(() {
                              _dayIndex = i;
                              if (_hour != null && !_slotAvailable(i, _hour!)) _hour = null;
                            })
                        : null,
                    haptic: true,
                    semanticLabel: formatDayMonth(_days[i]),
                    child: AnimatedContainer(
                      duration: BMotion.state,
                      curve: BMotion.ease,
                      width: 68,
                      decoration: BoxDecoration(
                        color: selected ? p.selectedFill : p.surface,
                        borderRadius: BRadius.all(BRadius.field),
                        border: Border.all(color: selected ? p.selectedBorder : p.line, width: 1.2),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_dayLabel(i), style: BType.small(fg).copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text('${_days[i].day}', style: BType.title(fg).copyWith(fontSize: 22, fontWeight: FontWeight.w800)),
                          Text(
                            formatDayMonth(_days[i]).split('-').last,
                            style: BType.small(fg.withValues(alpha: 0.8)).copyWith(fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 22),
          Text('Soat', style: BType.title(p.ink)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final h in UzData.viewingHours)
                Opacity(
                  opacity: _slotAvailable(_dayIndex, h) ? 1 : 0.35,
                  child: IgnorePointer(
                    ignoring: !_slotAvailable(_dayIndex, h),
                    child: PillChip(
                      label: '${h.toString().padLeft(2, '0')}:00',
                      selected: _hour == h,
                      onTap: () => setState(() => _hour = h),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          AppTextField(
            controller: _note,
            label: 'Egasiga izoh (ixtiyoriy)',
            hint: 'Masalan: ikki kishi kelamiz',
            maxLines: 2,
            minLines: 2,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: _hour == null ? 'Soatni tanlang' : "So'rov yuborish",
            loading: _busy,
            onPressed: _hour == null ? null : _submit,
          ),
        ],
      ),
    );
  }
}
