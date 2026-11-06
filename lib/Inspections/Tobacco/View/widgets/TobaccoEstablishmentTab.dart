import 'package:flutter/material.dart';
import 'package:quincy/Inspections/Tobacco/Model/TobaccoInspectionModel.dart';
import 'package:quincy/Inspections/Tobacco/Model/TobaccoJson.dart';
import 'package:quincy/Inspections/Tobacco/View/widgets/TobaccoTheme.dart';
import 'package:quincy/Inspections/Tobacco/View/widgets/TobaccoUi.dart';
import 'package:quincy/Inspections/Tobacco/ViewModel/TobaccoInspectionViewModel.dart';

/// Step 1 – Establishment (same fields as the web form).
///
/// Path: lib/Inspections/Tobacco/View/widgets/TobaccoEstablishmentTab.dart
class TobaccoEstablishmentTab extends StatefulWidget {
  const TobaccoEstablishmentTab({super.key, required this.vm});
  final TobaccoInspectionViewModel vm;

  @override
  State<TobaccoEstablishmentTab> createState() =>
      _TobaccoEstablishmentTabState();
}

class _TobaccoEstablishmentTabState extends State<TobaccoEstablishmentTab> {
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _permitNo = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _owner = TextEditingController();
  final _pic = TextEditingController();

  String _date = '';
  TimeOfDay? _timeIn;
  TimeOfDay? _timeOut;
  int? _inspectorId;
  bool _saving = false;
  String? _lastError;

  /// Show red "is required" texts after the first Next.
  bool _submitted = false;

  /// Permit fields that came pre-filled are locked (like Food).
  final Set<TextEditingController> _locked = {};
  String? _loadedFor;

  @override
  void initState() {
    super.initState();
    _fill();
    // AI Guide: "next" saves this tab, "time in now" etc. fill fields.
    widget.vm.onVoiceSaveEstablishment = _voiceSave;
    widget.vm.onVoiceSetField = _voiceSetField;
  }

  Future<String?> _voiceSave() async {
    await _saveAndNext(showError: false);
    return _lastError;
  }

  /// Fields the AI Guide can fill. Returns false for an unknown field.
  bool _voiceSetField(String field, String value) {
    if (!mounted) return false;
    final now = TimeOfDay.now();
    setState(() {
      switch (field) {
        case 'time_in':
          _timeIn = now;
          break;
        case 'time_out':
          _timeOut = now;
          break;
        case 'date_today':
          _date = tbDateOnly(DateTime.now());
          break;
        case 'person_in_charge':
          _pic.text = value;
          break;
        case 'owner':
          _owner.text = value;
          break;
        case 'contact':
          _contact.text = value;
          break;
        case 'telephone':
          _phone.text = value;
          break;
        case 'address':
          _address.text = value;
          break;
        case 'business_name':
          _name.text = value;
          break;
      }
    });
    return const {
      'time_in', 'time_out', 'date_today', 'person_in_charge', 'owner',
      'contact', 'telephone', 'address', 'business_name',
    }.contains(field);
  }

  @override
  void didUpdateWidget(covariant TobaccoEstablishmentTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fill();
  }

  /// Copies the inspection into the fields once per inspection id.
  void _fill() {
    final ins = widget.vm.inspection;
    if (ins == null || _loadedFor == ins.inspectionId) return;
    _loadedFor = ins.inspectionId;
    _name.text = ins.businessName;
    _contact.text = ins.contactName ?? '';
    _permitNo.text = ins.permitNumber ?? '';
    _address.text = ins.address ?? '';
    _phone.text = ins.telephone ?? '';
    _owner.text = ins.owner ?? '';
    _pic.text = ins.personInCharge ?? '';
    _date = ins.inspectionDate;
    _timeIn = _parseTime(ins.timeIn);
    _timeOut = _parseTime(ins.timeOut);
    _inspectorId = ins.inspectorId;
    _locked
      ..clear()
      ..addAll([_name, _contact, _permitNo, _address, _phone, _owner]
          .where((c) => c.text.trim().isNotEmpty));
  }

  List<String> _missingRequired() => [
        if (_name.text.trim().isEmpty) 'Establishment Name',
        if (_date.isEmpty) 'Inspection Date',
        if (_timeIn == null) 'Time In',
        if (_timeOut == null) 'Time Out',
        if (_inspectorId == null) 'Inspector',
      ];

  String? _err(bool missing, String label) =>
      _submitted && missing ? '$label is required' : null;

  @override
  void dispose() {
    if (widget.vm.onVoiceSaveEstablishment == _voiceSave) {
      widget.vm.onVoiceSaveEstablishment = null;
      widget.vm.onVoiceSetField = null;
    }
    for (final c in [_name, _contact, _permitNo, _address, _phone, _owner, _pic]) {
      c.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------ helpers

  static TimeOfDay? _parseTime(String? v) {
    if (v == null || !v.contains(':')) return null;
    final parts = v.split(':');
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  static String? _timeToString(TimeOfDay? t) => t == null
      ? null
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_date) ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _date = tbDateOnly(picked));
  }

  Future<void> _pickTime(bool isIn) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isIn ? _timeIn : _timeOut) ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isIn) {
        _timeIn = picked;
      } else {
        _timeOut = picked;
      }
    });
  }

  Future<void> _saveAndNext({bool showError = true}) async {
    final ins = widget.vm.inspection;
    if (ins == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitted = true);
    final missing = _missingRequired();
    if (missing.isNotEmpty) {
      _lastError = '${missing.join(', ')} ${missing.length == 1 ? 'is' : 'are'} required.';
      if (showError) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_lastError!)));
      }
      return;
    }
    setState(() => _saving = true);
    String v(TextEditingController c) => c.text.trim();
    final updated = TobaccoInspectionModel(
      inspectionId: ins.inspectionId,
      userId: ins.userId,
      permitId: ins.permitId,
      scheduleId: ins.scheduleId,
      serverInspectionId: ins.serverInspectionId,
      businessName: _name.text.trim(),
      contactName: v(_contact),
      permitNumber: v(_permitNo),
      address: v(_address),
      telephone: v(_phone),
      owner: v(_owner),
      personInCharge: v(_pic),
      inspectionDate: _date,
      timeIn: _timeToString(_timeIn),
      timeOut: _timeToString(_timeOut),
      inspector: ins.inspector,
      inspectorId: _inspectorId,
      status: ins.status,
      currentStep: ins.currentStep,
      createdAt: ins.createdAt,
      updatedAt: ins.updatedAt,
    );
    final err = await widget.vm.saveEstablishment(updated);
    if (!mounted) return;
    setState(() => _saving = false);
    _lastError = err;
    if (err != null && showError) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
    }
  }

  // ----------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final inspectors = widget.vm.inspectors;
    final hasSelected = inspectors.any((i) => i.id == _inspectorId);

    Widget field(String label, TextEditingController c,
        {String? hint, bool required = false, TextInputType? keyboard}) {
      final locked = _locked.contains(c);
      final error = required ? _err(c.text.trim().isEmpty, label) : null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TbLabel(label, required: required),
          TextField(
            controller: c,
            readOnly: locked,
            keyboardType: keyboard,
            onChanged: (_) {
              if (_submitted) setState(() {});
            },
            style: TextStyle(
                fontSize: 14,
                color: locked ? TbColors.textMuted : TbColors.textDark),
            decoration: tbInputDecoration(
                hint: hint ?? label, locked: locked, hasError: error != null),
          ),
          TbErrorText(error),
        ],
      );
    }

    Widget picker(String label, IconData icon, String value, String hint,
        VoidCallback onTap, String? error) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TbLabel(label, required: true),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: InputDecorator(
              decoration: tbInputDecoration(
                hasError: error != null,
                prefix: Icon(icon, size: 18, color: TbColors.brand),
                suffix: const Icon(Icons.arrow_drop_down,
                    color: TbColors.textMuted),
              ),
              child: Text(
                value.isEmpty ? hint : value,
                style: TextStyle(
                    fontSize: 14,
                    color: value.isEmpty
                        ? const Color(0xFF9AA5B4)
                        : TbColors.textDark),
              ),
            ),
          ),
          TbErrorText(error),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 16),
            children: [
              TbCard(
                icon: Icons.storefront_outlined,
                title: 'Establishment Details',
                subtitle: 'Pre-filled from the permit record',
                child: Column(
                  children: [
                    TbGrid(spans: const [3, 3, 2], children: [
                      field('Establishment Name', _name, required: true),
                      field('Contact/Owner Name', _contact),
                      field('Permit Number', _permitNo),
                    ]),
                    const SizedBox(height: 12),
                    TbGrid(spans: const [2, 1], children: [
                      field('Address', _address),
                      field('Telephone', _phone, keyboard: TextInputType.phone),
                    ]),
                    const SizedBox(height: 12),
                    TbGrid(children: [
                      field('Owner', _owner),
                      field('Person-in-charge', _pic,
                          hint: 'Enter person in charge'),
                    ]),
                  ],
                ),
              ),
              TbCard(
                icon: Icons.event_available_outlined,
                title: 'Inspection Visit',
                subtitle: 'Required before you can continue',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TbGrid(children: [
                      picker('Inspection Date', Icons.calendar_month_outlined,
                          tbFormatDateUs(_date), 'MM-DD-YYYY', _pickDate,
                          _err(_date.isEmpty, 'Inspection Date')),
                      picker('Time In', Icons.login, _timeIn?.format(context) ?? '',
                          '--:-- --', () => _pickTime(true),
                          _err(_timeIn == null, 'Time In')),
                      picker('Time Out', Icons.logout,
                          _timeOut?.format(context) ?? '', '--:-- --',
                          () => _pickTime(false), _err(_timeOut == null, 'Time Out')),
                    ]),
                    const SizedBox(height: 12),
                    const TbLabel('Inspector', required: true),
                    DropdownButtonFormField<int>(
                      value: hasSelected ? _inspectorId : null,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down,
                          color: TbColors.brand),
                      decoration: tbInputDecoration(
                        hasError: _err(_inspectorId == null, 'Inspector') != null,
                        prefix: const Icon(Icons.badge_outlined,
                            size: 18, color: TbColors.brand),
                      ),
                      hint: const Text('Select inspector',
                          style: TextStyle(fontSize: 14)),
                      items: [
                        for (final i in inspectors)
                          DropdownMenuItem(value: i.id, child: Text(i.name)),
                      ],
                      onChanged: (v) => setState(() => _inspectorId = v),
                    ),
                    TbErrorText(_err(_inspectorId == null, 'Inspector')),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          color: Colors.white,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  style: tbPrimaryButton(),
                  onPressed: _saving ? null : () => _saveAndNext(),
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('Next'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
