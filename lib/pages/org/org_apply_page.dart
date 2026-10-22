import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/org_event_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/org_service.dart';
import '../../widgets/bubble_toast.dart';
import 'my_events_page.dart';

// สมัครเป็นองค์กร / ดูสถานะคำขอ (14 ต.ค. 2026) — เข้าจาก Settings → Organization
// none/rejected = ฟอร์มสมัคร, pending = รอแอดมิน, approved = ไปหน้า My Events + แก้ข้อมูลได้, suspended = ถูกปิด
// startEditing: เปิดมาที่ฟอร์มแก้ไขเลย (ปุ่มแก้ไขในหน้า My Events) — บันทึกแล้ว pop กลับพร้อมชื่อใหม่
class OrgApplyPage extends StatefulWidget {
  final bool startEditing;
  const OrgApplyPage({super.key, this.startEditing = false});

  @override
  State<OrgApplyPage> createState() => _OrgApplyPageState();
}

class _OrgApplyPageState extends State<OrgApplyPage> {
  final _service = OrgService();
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _email = TextEditingController();
  final _otp = TextEditingController();
  // ส่งคำขอ 2 ขั้น: กดครั้งแรก = ส่ง OTP ไปอีเมลบัญชี -> โชว์ช่องกรอกรหัส แล้วกดอีกครั้ง = ส่งคำขอจริง
  bool _otpSent = false;
  String _orgType = 'npo';
  OrgProfile? _org;
  bool _canApply = false;
  bool _loading = true;
  bool _saving = false;
  late bool _editing = widget.startEditing;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _email.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await _service.fetchMyOrg();
      if (!mounted) return;
      setState(() {
        _org = r.org;
        _canApply = r.canApply;
        _loading = false;
        _error = null;
        // สมัครใหม่หลังไม่ผ่าน — เติมข้อมูลเดิมให้แก้ต่อ
        if (_name.text.isEmpty) _name.text = r.org.name;
        if (_description.text.isEmpty) _description.text = r.org.description;
        // อีเมลติดต่อล็อกเป็นอีเมลบัญชี (แก้ไม่ได้) — backend ใช้อีเมลบัญชีเสมอ
        _email.text = r.email;
        if (orgTypeLabels.containsKey(r.org.orgType)) _orgType = r.org.orgType;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  // บันทึกการแก้ไข (องค์กรที่อนุมัติแล้ว)
  Future<void> _saveEdit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final org = await _service.updateOrg(
        name: _name.text.trim(),
        orgType: _orgType,
        description: _description.text.trim(),
      );
      if (!mounted) return;
      showBubbleToast(context, 'Saved');
      context.read<AuthProvider>().refreshProfile();
      if (widget.startEditing) {
        Navigator.pop(context, org.name);
        return;
      }
      setState(() {
        _org = org;
        _editing = false;
      });
    } catch (e) {
      if (mounted) showBubbleToast(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendOtp() async {
    setState(() => _saving = true);
    try {
      await _service.sendApplyOtp();
      if (!mounted) return;
      setState(() => _otpSent = true);
      showBubbleToast(context, 'We sent a 6-digit code to ${_email.text}');
    } catch (e) {
      if (mounted) showBubbleToast(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_otpSent) return _sendOtp();
    setState(() => _saving = true);
    try {
      final org = await _service.apply(
        name: _name.text.trim(),
        orgType: _orgType,
        description: _description.text.trim(),
        otp: _otp.text.trim(),
      );
      if (!mounted) return;
      setState(() => _org = org);
      showBubbleToast(context, 'Request sent');
      context.read<AuthProvider>().refreshProfile();
    } catch (e) {
      if (mounted) showBubbleToast(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.green),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: Text(_editing ? 'Edit organization' : 'Organization'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : _error != null
          ? Center(
              child: TextButton(
                onPressed: () {
                  setState(() => _loading = true);
                  _load();
                },
                child: Text('$_error\nTap to try again', textAlign: TextAlign.center),
              ),
            )
          : ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: _body()),
    );
  }

  List<Widget> _body() {
    final org = _org ?? const OrgProfile();
    switch (org.status) {
      case 'pending':
        return [
          _StatusCard(
            icon: Icons.hourglass_top_rounded,
            color: Colors.orange,
            title: 'Waiting for approval',
            message: 'The EcoQuest team is checking "${org.name}". You will get a notification when it is approved.',
          ),
        ];
      case 'approved':
        if (_editing) {
          return [
            Text('Changes are shown on your events right away.', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 16),
            _form('Save changes', _saveEdit),
          ];
        }
        return [
          _StatusCard(
            icon: Icons.verified_rounded,
            color: Colors.green,
            title: org.name,
            message: 'Your organization is approved. Create events and players can join them in Explore → Event.',
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () =>
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MyEventsPage(orgName: org.name))),
            icon: const Icon(Icons.event_note_rounded),
            label: const Text('Open My Events'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => setState(() => _editing = true),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit details'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green.shade800,
              side: BorderSide(color: Colors.green.shade300),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
          ),
        ];
      case 'suspended':
        return [
          _StatusCard(
            icon: Icons.block_rounded,
            color: Colors.redAccent,
            title: 'Organization suspended',
            message:
                '"${org.name}" was suspended by the EcoQuest team.'
                '${org.decisionNote.isNotEmpty ? '\nReason: ${org.decisionNote}' : ''}',
          ),
        ];
    }

    if (!_canApply) {
      return const [
        _StatusCard(
          icon: Icons.person_add_alt,
          color: Colors.blueGrey,
          title: 'Create an account first',
          message: 'Guest accounts cannot register an organization. Create an account with your email in Settings.',
        ),
      ];
    }

    return [
      if (org.status == 'rejected')
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _StatusCard(
            icon: Icons.info_outline,
            color: Colors.redAccent,
            title: 'Your last request was not approved',
            message: org.decisionNote.isNotEmpty
                ? 'Note: ${org.decisionNote}'
                : 'You can update the details and send it again.',
          ),
        ),
      Text(
        'Run eco events with EcoQuest',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade800),
      ),
      const SizedBox(height: 6),
      Text(
        'Organizations can create environmental events. Players join in the app, scan your QR code at the event, and get points.',
        style: TextStyle(color: Colors.grey.shade700, height: 1.4),
      ),
      const SizedBox(height: 18),
      _form(_otpSent ? 'Verify & send request' : 'Send verification code', _submit, withOtp: true),
    ];
  }

  // ฟอร์มข้อมูลองค์กร — ใช้ทั้งสมัครและแก้ไข (withOtp = ตอนสมัคร โชว์ช่องรหัสหลังขอ OTP แล้ว)
  Widget _form(String buttonLabel, VoidCallback onSubmit, {bool withOtp = false}) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            maxLength: 60,
            decoration: _decoration('Organization name'),
            validator: (v) => (v ?? '').trim().length < 2 ? 'Enter the name' : null,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _orgType,
            decoration: _decoration('Type'),
            items: [for (final e in orgTypeLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) => setState(() => _orgType = v ?? 'npo'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _description,
            maxLength: 500,
            maxLines: 4,
            decoration: _decoration('About your organization', hint: 'What you do, your website or social page'),
            validator: (v) => (v ?? '').trim().length < 10 ? 'At least 10 characters' : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _email,
            readOnly: true,
            decoration: _decoration('Contact email').copyWith(
              helperText: 'Your account email is used as the contact email',
              suffixIcon: const Icon(Icons.lock_outline, size: 18),
            ),
          ),
          if (withOtp && _otpSent) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _otp,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofillHints: const [AutofillHints.oneTimeCode],
              decoration: _decoration('6-digit code from your email'),
              validator: (v) => (v ?? '').trim().length == 6 ? null : 'Enter the 6-digit code',
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _saving ? null : _sendOtp,
                child: const Text('Resend code'),
              ),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(buttonLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  const _StatusCard({required this.icon, required this.color, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(message, style: TextStyle(color: Colors.grey.shade800, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
