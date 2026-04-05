// lib/features/students/presentation/add_student_sheet.dart
// Bottom sheet form for student enrollment with all required fields.
// Dev: rahulpr2000 | RAHUL PR | Marrty LLC

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../data/student_repository.dart';

class AddStudentSheet extends StatefulWidget {
  const AddStudentSheet({super.key});
  @override State<AddStudentSheet> createState() => _AddStudentSheetState();
}

class _AddStudentSheetState extends State<AddStudentSheet> {
  final _form     = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _rollCtrl  = TextEditingController();
  final _pnrCtrl   = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String  _batch    = AppConstants.batchYears[2]; // 2024-27
  String  _semester = AppConstants.semesters[2];  // S3
  String  _gender   = 'Male';
  DateTime? _dob;
  bool    _loading  = false;

  @override
  void dispose() {
    for (final c in [_nameCtrl, _rollCtrl, _pnrCtrl, _phoneCtrl, _emailCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Submit enrollment form to backend
  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final body = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'rollNo': _rollCtrl.text.trim(),
        'pnr': _pnrCtrl.text.trim(),
        'batchYear': _batch,
        'semester': _semester,
        'gender': _gender,
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim().toLowerCase(),
      };
      // Include DOB only if selected
      if (_dob != null) {
        body['dob'] = _dob!.toIso8601String().split('T').first;
      }
      await StudentRepository().create(body);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  /// Open date picker for DOB
  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2005, 1, 1),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottom + 24),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Handle bar
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.dividerLight,
                borderRadius: BorderRadius.circular(2),
              ),
            )),
            const SizedBox(height: 20),
            Text('Add Student', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),

            // ── Name ──────────────────────────────────────
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            // ── Roll No + PNR ─────────────────────────────
            Row(children: [
              Expanded(child: TextFormField(
                controller: _rollCtrl,
                decoration: const InputDecoration(labelText: 'Roll No'),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              )),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(
                controller: _pnrCtrl,
                decoration: const InputDecoration(labelText: 'PNR'),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              )),
            ]),
            const SizedBox(height: 12),

            // ── Batch + Semester ──────────────────────────
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                value: _batch,
                decoration: const InputDecoration(labelText: 'Batch Year'),
                items: AppConstants.batchYears.map((b) =>
                    DropdownMenuItem(value: b, child: Text(b))).toList(),
                onChanged: (v) => setState(() => _batch = v!),
              )),
              const SizedBox(width: 12),
              Expanded(child: DropdownButtonFormField<String>(
                value: _semester,
                decoration: const InputDecoration(labelText: 'Semester'),
                items: AppConstants.semesters.map((s) =>
                    DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _semester = v!),
              )),
            ]),
            const SizedBox(height: 12),

            // ── Gender + DOB ──────────────────────────────
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: ['Male', 'Female', 'Other'].map((g) =>
                    DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (v) => setState(() => _gender = v!),
              )),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton.icon(
                onPressed: _pickDob,
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(
                  _dob != null
                      ? '${_dob!.day}/${_dob!.month}/${_dob!.year}'
                      : 'DOB (Optional)',
                  style: const TextStyle(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                ),
              )),
            ]),
            const SizedBox(height: 12),

            // ── Phone ─────────────────────────────────────
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: const InputDecoration(
                labelText: 'Phone',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.length != 10) return '10 digits required';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // ── Email ─────────────────────────────────────
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (!v.contains('@')) return 'Invalid email';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ── Submit ────────────────────────────────────
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 22, width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Add Student'),
            ),
          ]),
        ),
      ),
    );
  }
}
