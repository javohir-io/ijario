import 'package:flutter/material.dart';

import '../../data/property_store.dart';
import '../../models/filter_criteria.dart';
import '../../models/property.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/formatters.dart';
import '../../utils/uz_data.dart';
import '../../widgets/buttons.dart';
import '../../widgets/pill_chip.dart';
import '../../widgets/segmented.dart';
import '../../widgets/sheet.dart';

/// Opens the full filter sheet. Resolves to the new criteria when the
/// person taps the result button, or null if they dismiss it.
Future<FilterCriteria?> showFilterSheet(BuildContext context, FilterCriteria initial) {
  return showIjarioSheet<FilterCriteria>(
    context,
    fullHeight: true,
    builder: (_) => _FilterSheet(initial: initial),
  );
}

class _FilterSheet extends StatefulWidget {
  final FilterCriteria initial;

  const _FilterSheet({required this.initial});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late FilterCriteria _draft = widget.initial;

  int get _resultCount => PropertyStore.instance.all.where(_draft.matches).length;

  String _priceLabel() {
    final r = _draft.price;
    final lo = r.start <= FilterCriteria.priceMin ? 'Eng arzon' : formatMoneyShort(r.start, 'UZS');
    final hi = r.end >= FilterCriteria.priceMax
        ? '${formatMoneyShort(FilterCriteria.priceMax, 'UZS')}+'
        : formatMoneyShort(r.end, 'UZS');
    return '$lo – $hi';
  }

  String _areaLabel() {
    final r = _draft.area;
    final hi = r.end >= FilterCriteria.areaMax ? '${FilterCriteria.areaMax.round()}+' : '${r.end.round()}';
    return '${r.start.round()} – $hi m²';
  }

  Widget _section(String title, Widget child, {String? trailing}) {
    final p = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: BType.title(p.ink))),
              if (trailing != null)
                Text(trailing, style: BType.label(p.brand).copyWith(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) {
    final p = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: BType.body(p.ink).copyWith(fontWeight: FontWeight.w600))),
          Switch(
            value: value,
            onChanged: onChanged,
            trackOutlineColor: WidgetStateProperty.all<Color>(Colors.transparent),
            trackColor: WidgetStateProperty.resolveWith<Color>(
              (states) => states.contains(WidgetState.selected) ? p.selectedFill : p.surfaceAlt,
            ),
            thumbColor: WidgetStateProperty.resolveWith<Color>(
              (states) => states.contains(WidgetState.selected) ? BColors.rawOak : p.inkFaint,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    final d = _draft;
    final unitIndex = d.unit == null ? 0 : (d.unit == Property.unitMonth ? 1 : 2);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(BSpace.page, 12, 8, 4),
          child: Row(
            children: [
              Expanded(child: Text('Filtrlar', style: BType.display(p.ink).copyWith(fontSize: 32))),
              TextAction(
                label: 'Tozalash',
                onTap: () => setState(() => _draft = d.clearedSheetFilters()),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(BSpace.page, 12, BSpace.page, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _section(
                  'Ijara turi',
                  Segmented(
                    options: const ['Hammasi', 'Oylik', 'Kunlik'],
                    index: unitIndex,
                    onChanged: (i) => setState(() {
                      _draft = i == 0
                          ? d.copyWith(clearUnit: true)
                          : d.copyWith(unit: i == 1 ? Property.unitMonth : Property.unitDay);
                    }),
                  ),
                ),
                _section(
                  'Narx',
                  RangeSlider(
                    values: d.price,
                    min: FilterCriteria.priceMin,
                    max: FilterCriteria.priceMax,
                    divisions: 120,
                    activeColor: p.brand,
                    inactiveColor: p.surfaceAlt,
                    onChanged: (v) => setState(() => _draft = d.copyWith(price: v)),
                  ),
                  trailing: _priceLabel(),
                ),
                _section(
                  'Xonalar soni',
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final n in const [0, 1, 2, 3, 4])
                        PillChip(
                          label: n == 0 ? 'Farqi yo\'q' : (n == 4 ? '4+' : '$n'),
                          selected: d.minRooms == n,
                          onTap: () => setState(() => _draft = d.copyWith(minRooms: n)),
                        ),
                    ],
                  ),
                ),
                _section(
                  'Maydon',
                  RangeSlider(
                    values: d.area,
                    min: FilterCriteria.areaMin,
                    max: FilterCriteria.areaMax,
                    divisions: 19,
                    activeColor: p.brand,
                    inactiveColor: p.surfaceAlt,
                    onChanged: (v) => setState(() => _draft = d.copyWith(area: v)),
                  ),
                  trailing: _areaLabel(),
                ),
                _section(
                  "Ta'mir",
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      PillChip(
                        label: 'Farqi yo\'q',
                        selected: d.renovation == null,
                        onTap: () => setState(() => _draft = d.copyWith(clearRenovation: true)),
                      ),
                      for (final r in UzData.renovations)
                        PillChip(
                          label: r,
                          selected: d.renovation == r,
                          onTap: () => setState(() => _draft = d.copyWith(renovation: r)),
                        ),
                    ],
                  ),
                ),
                _section(
                  'Qulayliklar',
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final a in UzData.amenities)
                        PillChip(
                          label: a,
                          selected: d.amenities.contains(a),
                          onTap: () {
                            final next = Set<String>.of(d.amenities);
                            if (!next.remove(a)) next.add(a);
                            setState(() => _draft = d.copyWith(amenities: next));
                          },
                        ),
                    ],
                  ),
                ),
                _section(
                  "Qo'shimcha",
                  Column(
                    children: [
                      _toggle("Faqat egasidan (vositachisiz)", d.ownerOnly,
                          (v) => setState(() => _draft = d.copyWith(ownerOnly: v))),
                      _toggle('Talabalarga mos', d.studentOnly,
                          (v) => setState(() => _draft = d.copyWith(studentOnly: v))),
                      _toggle('Metro yaqinida', d.nearMetro,
                          (v) => setState(() => _draft = d.copyWith(nearMetro: v))),
                      _toggle("Kommunal to'lovlar narxga kiritilgan", d.utilitiesIncluded,
                          (v) => setState(() => _draft = d.copyWith(utilitiesIncluded: v))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(BSpace.page, 12, BSpace.page, 12),
          decoration: BoxDecoration(
            color: p.bg,
            border: Border(top: BorderSide(color: p.line)),
          ),
          child: SafeArea(
            top: false,
            child: PrimaryButton(
              label: _resultCount == 0 ? "E'lon topilmadi" : "$_resultCount ta e'lonni ko'rsatish",
              onPressed: _resultCount == 0 ? null : () => Navigator.of(context).pop(_draft),
            ),
          ),
        ),
      ],
    );
  }
}
