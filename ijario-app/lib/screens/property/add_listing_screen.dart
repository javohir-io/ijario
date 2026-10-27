import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/property_store.dart';
import '../../models/picked_image.dart';
import '../../models/property.dart';
import '../../services/api_exception.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/formatters.dart';
import '../../utils/uz_data.dart';
import '../../utils/validators.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/buttons.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/option_sheet.dart';
import '../../widgets/pill_chip.dart';
import '../../widgets/pressable.dart';
import '../../widgets/segmented.dart';
import '../../widgets/toast.dart';

/// Posting (and editing) a listing, one small step at a time: place, price,
/// the flat itself, photos. Each step is validated before moving on, so
/// nobody finds out about a mistake on step one after finishing step four.
class AddListingScreen extends StatefulWidget {
  final Property? editing;

  const AddListingScreen({super.key, this.editing});

  @override
  State<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
  static const _stepTitles = ['Manzil', 'Narx', 'Uy haqida', 'Rasmlar'];
  static const _maxPhotos = 10;

  final _pages = PageController();
  final _formKeys = List<GlobalKey<FormState>>.generate(3, (_) => GlobalKey<FormState>());
  int _step = 0;
  bool _busy = false;

  final _title = TextEditingController();
  final _metro = TextEditingController();
  final _customLocation = TextEditingController();
  final _price = TextEditingController();
  final _deposit = TextEditingController();
  final _area = TextEditingController();
  final _description = TextEditingController();

  String _city = 'Toshkent';
  String? _district;
  bool _legacyLocation = false; // old listing whose area isn't in the district list
  String _ownerType = Property.ownerOwner;
  String _currency = 'UZS';
  String _unit = Property.unitMonth;
  bool _utilities = false;
  int _bedrooms = 1;
  int _bathrooms = 1;
  int _floor = 1;
  String _renovation = UzData.renovations[1];
  final Set<String> _amenities = {};
  bool _student = false;

  List<PropertyImage> _existing = [];
  final List<int> _removedImageIds = [];
  final List<PickedImage> _picked = [];

  bool get _isEditing => widget.editing != null;
  bool get _useChips => UzData.districtsOf(_city).isNotEmpty && !_legacyLocation;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e == null) return;
    _title.text = e.title;
    _metro.text = e.metro ?? '';
    _city = e.city;
    final districts = UzData.districtsOf(_city);
    if (districts.isNotEmpty) {
      if (districts.contains(e.location)) {
        _district = e.location;
      } else {
        _legacyLocation = true;
        _customLocation.text = e.location;
      }
    } else {
      _customLocation.text = e.location;
    }
    _ownerType = e.ownerType;
    _currency = e.currency;
    _unit = e.priceUnit;
    _price.text = e.price.round().toString();
    _deposit.text = e.deposit > 0 ? e.deposit.round().toString() : '';
    _utilities = e.utilitiesIncluded;
    _bedrooms = e.bedrooms < 1 ? 1 : e.bedrooms;
    _bathrooms = e.bathrooms;
    _floor = e.floor;
    _area.text = e.area > 0 ? e.area.round().toString() : '';
    _renovation = e.renovation;
    _amenities.addAll(e.amenities);
    _student = e.studentFriendly;
    _description.text = e.description;
    _existing = List<PropertyImage>.of(e.images);
  }

  @override
  void dispose() {
    _pages.dispose();
    _title.dispose();
    _metro.dispose();
    _customLocation.dispose();
    _price.dispose();
    _deposit.dispose();
    _area.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _hasChanges =>
      _title.text.trim().isNotEmpty || _price.text.trim().isNotEmpty || _picked.isNotEmpty;

  // --- navigation ------------------------------------------------------------

  bool _validateStep() {
    if (_step < 3 && !(_formKeys[_step].currentState?.validate() ?? false)) return false;
    if (_step == 0 && _useChips && _district == null) {
      showToast(context, 'Tumanni tanlang', error: true);
      return false;
    }
    return true;
  }

  void _goTo(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    _pages.animateToPage(step, duration: BMotion.page, curve: BMotion.ease);
  }

  void _next() {
    if (!_validateStep()) return;
    if (_step == 3) {
      _submit();
    } else {
      _goTo(_step + 1);
    }
  }

  Future<void> _close() async {
    if (_isEditing || !_hasChanges) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await confirmDialog(
      context,
      title: "E'lonni bekor qilasizmi?",
      message: "Kiritilgan ma'lumotlar saqlanmaydi.",
      confirmLabel: 'Bekor qilish',
      cancelLabel: 'Davom etish',
      destructive: true,
    );
    if (discard && mounted) Navigator.of(context).pop();
  }

  // --- data --------------------------------------------------------------------

  Future<void> _pickCity() async {
    final choice = await showOptionSheet<String>(
      context,
      title: 'Shahar',
      selected: _city,
      hasSelection: true,
      options: [for (final c in UzData.cities) OptionItem<String>(c, c)],
    );
    if (choice == null || choice.value == _city) return;
    setState(() {
      _city = choice.value;
      _district = null;
      _legacyLocation = false;
      _customLocation.clear();
    });
  }

  Future<void> _pickPhotos() async {
    final room = _maxPhotos - _existing.length - _picked.length;
    if (room <= 0) {
      showToast(context, "Ko'pi bilan $_maxPhotos ta rasm qo'shish mumkin", error: true);
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;
    var skipped = 0;
    setState(() {
      for (final f in result.files) {
        if (f.bytes == null) continue;
        if (_picked.length >= _maxPhotos - _existing.length) {
          skipped++;
          continue;
        }
        _picked.add(PickedImage(bytes: f.bytes!, filename: f.name));
      }
    });
    if (skipped > 0 && mounted) {
      showToast(context, "Ko'pi bilan $_maxPhotos ta rasm olinadi", error: true);
    }
  }

  String get _location => _useChips ? (_district ?? '') : _customLocation.text.trim();

  Map<String, dynamic> _payload() {
    return {
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'city': _city,
      'location': _location,
      'metro': _metro.text.trim(),
      'price': Validators.parseNumber(_price.text) ?? 0,
      'currency': _currency,
      'price_unit': _unit,
      'deposit': Validators.parseNumber(_deposit.text) ?? 0,
      'utilities_included': _utilities,
      'bedrooms': _bedrooms,
      'bathrooms': _bathrooms,
      'floor': _floor,
      'area': Validators.parseNumber(_area.text) ?? 0,
      'renovation': _renovation,
      'amenities': _amenities.toList(),
      'student_friendly': _student,
      'owner_type': _ownerType,
    };
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final store = PropertyStore.instance;
    String? photoProblem;
    try {
      final Property saved = _isEditing
          ? await store.updateProperty(widget.editing!.id, _payload())
          : await store.addProperty(_payload());

      for (final id in _removedImageIds) {
        try {
          await store.deleteImage(saved.id, id);
        } on ApiException {
          // A photo that can't be removed shouldn't block saving the rest.
        }
      }
      if (_picked.isNotEmpty) {
        try {
          await store.uploadImages(saved.id, _picked);
        } on ApiException catch (e) {
          photoProblem = e.message;
        }
      }
      store.fetchMine();

      if (!mounted) return;
      if (photoProblem != null) {
        showToast(context, "E'lon saqlandi, lekin rasmlar yuklanmadi: $photoProblem", error: true);
      } else {
        showToast(context, _isEditing ? "O'zgarishlar saqlandi" : "E'lon joylandi");
      }
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(context, e.message, error: true);
    }
  }

  // --- build -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: p.bg,
        body: SafeArea(
          child: Column(
            children: [
              _header(p),
              Expanded(
                child: PageView(
                  controller: _pages,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _page(Form(key: _formKeys[0], child: _stepPlace(p))),
                    _page(Form(key: _formKeys[1], child: _stepPrice(p))),
                    _page(Form(key: _formKeys[2], child: _stepFlat(p))),
                    _page(_stepPhotos(p)),
                  ],
                ),
              ),
              _footer(p),
            ],
          ),
        ),
      ),
    );
  }

  Widget _page(Widget child) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(BSpace.page + 4, 8, BSpace.page + 4, 32),
      child: Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: child),
      ),
    );
  }

  Widget _header(BPalette p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, BSpace.page + 4, 6),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Yopish',
                onPressed: _close,
                icon: Icon(Icons.close_rounded, color: p.ink),
              ),
              Expanded(
                child: Text(
                  _isEditing ? "E'lonni tahrirlash" : "Yangi e'lon",
                  style: BType.title(p.ink),
                ),
              ),
              Text('${_step + 1} / 4', style: BType.label(p.inkMuted).copyWith(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: AnimatedContainer(
                      duration: BMotion.state,
                      curve: BMotion.ease,
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= _step ? p.brand : p.line,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(BPalette p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(BSpace.page + 4, 12, BSpace.page + 4, 14),
      decoration: BoxDecoration(color: p.bg, border: Border(top: BorderSide(color: p.line))),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Row(
            children: [
              if (_step > 0) ...[
                Expanded(
                  flex: 2,
                  child: SecondaryButton(label: 'Orqaga', onPressed: _busy ? null : () => _goTo(_step - 1)),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 3,
                child: PrimaryButton(
                  label: _step == 3 ? (_isEditing ? 'Saqlash' : "E'lonni joylash") : 'Davom etish',
                  loading: _busy,
                  onPressed: _next,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(BPalette p, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: BType.display(p.ink)),
          const SizedBox(height: 6),
          Text(subtitle, style: BType.body(p.inkMuted)),
        ],
      ),
    );
  }

  // --- step 1: place --------------------------------------------------------------

  Widget _stepPlace(BPalette p) {
    final districts = UzData.districtsOf(_city);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(p, _stepTitles[0], "E'lon qayerda va kim tomonidan joylanyapti?"),
        Segmented(
          options: const ['Egasiman', 'Rieltorman'],
          index: _ownerType == Property.ownerOwner ? 0 : 1,
          onChanged: (i) => setState(() => _ownerType = i == 0 ? Property.ownerOwner : Property.ownerAgent),
        ),
        const SizedBox(height: 22),
        AppTextField(
          controller: _title,
          label: "E'lon sarlavhasi",
          hint: "Yorug' 2 xonali kvartira",
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          validator: (v) => (v == null || v.trim().length < 5) ? "Sarlavha kamida 5 ta belgidan iborat bo'lsin" : null,
        ),
        const SizedBox(height: 18),
        _PickerField(label: 'Shahar', value: _city, onTap: _pickCity),
        const SizedBox(height: 18),
        if (_useChips) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text('Tuman', style: BType.label(p.ink).copyWith(fontSize: 13.5)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in districts)
                PillChip(label: d, selected: _district == d, onTap: () => setState(() => _district = d)),
            ],
          ),
        ] else
          AppTextField(
            controller: _customLocation,
            label: 'Hudud yoki mahalla',
            hint: 'Masalan: Registon yaqinida',
            textCapitalization: TextCapitalization.words,
            validator: (v) => Validators.required(v, 'Hududni kiriting'),
          ),
        const SizedBox(height: 18),
        AppTextField(
          controller: _metro,
          label: 'Eng yaqin metro bekati (ixtiyoriy)',
          hint: 'Masalan: Novza',
          textCapitalization: TextCapitalization.words,
          maxLength: 60,
        ),
      ],
    );
  }

  // --- step 2: price -----------------------------------------------------------------

  Widget _stepPrice(BPalette p) {
    final price = Validators.parseNumber(_price.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(p, _stepTitles[1], "Aniq narx ishonchni oshiradi. Yashirin to'lovlarni ham yozing."),
        Segmented(
          options: const ['Oylik', 'Kunlik'],
          index: _unit == Property.unitMonth ? 0 : 1,
          onChanged: (i) => setState(() => _unit = i == 0 ? Property.unitMonth : Property.unitDay),
        ),
        const SizedBox(height: 14),
        Segmented(
          options: const ["So'm", 'USD'],
          index: _currency == 'UZS' ? 0 : 1,
          onChanged: (i) => setState(() => _currency = i == 0 ? 'UZS' : 'USD'),
        ),
        const SizedBox(height: 22),
        AppTextField(
          controller: _price,
          label: 'Narx',
          hint: _currency == 'UZS' ? '4000000' : '350',
          helper: (price != null && price > 0)
              ? '${formatMoney(price, _currency)} / ${unitLabel(_unit)}'
              : null,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 12,
          onChanged: (_) => setState(() {}),
          validator: (v) => Validators.positiveNumber(v, 'Narxni kiriting'),
        ),
        const SizedBox(height: 18),
        AppTextField(
          controller: _deposit,
          label: 'Garov / depozit (ixtiyoriy)',
          hint: '0',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 12,
        ),
        const SizedBox(height: 8),
        _ToggleRow(
          label: "Kommunal to'lovlar narxga kiritilgan",
          value: _utilities,
          onChanged: (v) => setState(() => _utilities = v),
        ),
      ],
    );
  }

  // --- step 3: the flat -----------------------------------------------------------------

  Widget _stepFlat(BPalette p) {
    final renovations = UzData.renovations.contains(_renovation)
        ? UzData.renovations
        : [...UzData.renovations, _renovation];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(p, _stepTitles[2], "Qancha ko'p aniq ma'lumot, shuncha kam savol."),
        _StepperRow(label: 'Xonalar', value: _bedrooms, min: 1, max: 10, onChanged: (v) => setState(() => _bedrooms = v)),
        _StepperRow(label: 'Vannaxonalar', value: _bathrooms, min: 0, max: 6, onChanged: (v) => setState(() => _bathrooms = v)),
        _StepperRow(label: 'Qavat', value: _floor, min: 0, max: 60, onChanged: (v) => setState(() => _floor = v)),
        const SizedBox(height: 14),
        AppTextField(
          controller: _area,
          label: 'Maydon (m²)',
          hint: '65',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 4,
          validator: (v) => Validators.positiveNumber(v, 'Maydonni kiriting'),
        ),
        const SizedBox(height: 22),
        Text("Ta'mir", style: BType.title(p.ink)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in renovations)
              PillChip(label: r, selected: _renovation == r, onTap: () => setState(() => _renovation = r)),
          ],
        ),
        const SizedBox(height: 22),
        Text('Qulayliklar', style: BType.title(p.ink)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in UzData.amenities)
              PillChip(
                label: a,
                selected: _amenities.contains(a),
                onTap: () => setState(() {
                  if (!_amenities.remove(a)) _amenities.add(a);
                }),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _ToggleRow(
          label: 'Talabalarga mos',
          value: _student,
          onChanged: (v) => setState(() => _student = v),
        ),
        const SizedBox(height: 14),
        AppTextField(
          controller: _description,
          label: 'Tavsif (ixtiyoriy)',
          hint: "Qo'shnilar, transport, shartlar...",
          maxLines: 5,
          minLines: 4,
          maxLength: 1500,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }

  // --- step 4: photos -----------------------------------------------------------------

  Widget _stepPhotos(BPalette p) {
    final total = _existing.length + _picked.length;
    final tiles = <Widget>[
      for (var i = 0; i < _existing.length; i++)
        _PhotoTile(
          isCover: i == 0,
          onRemove: () => setState(() {
            _removedImageIds.add(_existing[i].id);
            _existing.removeAt(i);
          }),
          child: Image.network(_existing[i].url, fit: BoxFit.cover),
        ),
      for (var i = 0; i < _picked.length; i++)
        _PhotoTile(
          isCover: _existing.isEmpty && i == 0,
          onRemove: () => setState(() => _picked.removeAt(i)),
          child: Image.memory(_picked[i].bytes, fit: BoxFit.cover),
        ),
      if (total < _maxPhotos) _AddPhotoTile(onTap: _pickPhotos),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(p, _stepTitles[3], "Birinchi rasm e'lonning asosiy rasmi bo'ladi. Yorug' va aniq suratlarni tanlang."),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: tiles,
        ),
        const SizedBox(height: 14),
        Text('$total / $_maxPhotos rasm', style: BType.small(p.inkMuted)),
      ],
    );
  }
}

// --- small form pieces ------------------------------------------------------------------

class _PickerField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _PickerField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(label, style: BType.label(p.ink).copyWith(fontSize: 13.5)),
        ),
        Pressable(
          onTap: onTap,
          semanticLabel: label,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BDeco.card(p, radius: BRadius.field),
            child: Row(
              children: [
                Expanded(child: Text(value, style: BType.body(p.ink).copyWith(fontWeight: FontWeight.w600))),
                Icon(Icons.expand_more_rounded, color: p.inkMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Row(
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
    );
  }
}

class _StepperRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _StepperRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  Widget _button(BuildContext context, IconData icon, String semantic, VoidCallback? onTap) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      haptic: true,
      semanticLabel: semantic,
      child: Opacity(
        opacity: onTap == null ? 0.35 : 1,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: p.surface,
            border: Border.all(color: p.line, width: 1.2),
          ),
          child: Icon(icon, size: 22, color: p.ink),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: BType.body(p.ink).copyWith(fontWeight: FontWeight.w600))),
          _button(context, Icons.remove_rounded, '$label: kamaytirish', value > min ? () => onChanged(value - 1) : null),
          SizedBox(
            width: 48,
            child: Text('$value', textAlign: TextAlign.center, style: BType.title(p.ink).copyWith(fontSize: 19)),
          ),
          _button(context, Icons.add_rounded, '$label: ko\'paytirish', value < max ? () => onChanged(value + 1) : null),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final Widget child;
  final bool isCover;
  final VoidCallback onRemove;

  const _PhotoTile({required this.child, required this.isCover, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return ClipRRect(
      borderRadius: BRadius.all(BRadius.field),
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (isCover)
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: BColors.rawOak, borderRadius: BorderRadius.circular(10)),
                child: Text('Asosiy', style: BType.label(BColors.obsidian).copyWith(fontSize: 11.5)),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: Pressable(
              onTap: onRemove,
              semanticLabel: "Rasmni o'chirish",
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
                child: Icon(Icons.close_rounded, size: 18, color: p.isDark ? BColors.plaster : Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddPhotoTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    return Pressable(
      onTap: onTap,
      haptic: true,
      semanticLabel: "Rasm qo'shish",
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BRadius.all(BRadius.field),
          border: Border.all(color: p.brand.withValues(alpha: 0.5), width: 1.4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, size: 30, color: p.brand),
            const SizedBox(height: 6),
            Text("Qo'shish", style: BType.label(p.brand)),
          ],
        ),
      ),
    );
  }
}
