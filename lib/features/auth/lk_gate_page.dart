// lib/features/auth/lk_gate_page.dart
// #/lk 入口：預設為自動註冊表單（姓名/單位/員編），另提供「使用授權碼登入」備用路徑

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/lk_auth_service.dart';
import '../../core/services/study_logger.dart';

class LkGatePage extends StatefulWidget {
  const LkGatePage({super.key});

  @override
  State<LkGatePage> createState() => _LkGatePageState();
}

class _LkGatePageState extends State<LkGatePage> {
  // 授權碼登入（備用路徑）
  final _codeCtrl = TextEditingController();

  // 自動註冊表單
  final _nameCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _employeeIdCtrl = TextEditingController();

  bool _showKeyLogin = false;
  bool _loading = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _employeeIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkExistingSession() async {
    final session = await LkAuthService.getSession();
    if (session != null && mounted) {
      context.go('/');
    }
  }

  Future<void> _submitRegister() async {
    final name = _nameCtrl.text.trim();
    final unitName = _unitCtrl.text.trim();
    final employeeId = _employeeIdCtrl.text.trim();

    if (name.isEmpty) {
      setState(() => _errorMsg = '請填寫姓名');
      return;
    }
    if (unitName.isEmpty) {
      setState(() => _errorMsg = '請填寫單位');
      return;
    }
    if (employeeId.isEmpty) {
      setState(() => _errorMsg = '請填寫員編');
      return;
    }

    setState(() { _loading = true; _errorMsg = null; });

    final res = await LkAuthService.autoRegister(
      name: name,
      unitName: unitName,
      employeeId: employeeId,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (res.result == LkLoginResult.success) {
      StudyLogger.login(res.keyCode ?? '');
      context.go('/');
    } else {
      setState(() => _errorMsg = res.error ?? '註冊失敗，請稍後再試');
    }
  }

  Future<void> _loginWithCode() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _errorMsg = '請輸入授權碼');
      return;
    }
    if (!RegExp(r'^SK-\d{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$').hasMatch(code)) {
      setState(() => _errorMsg = '授權碼格式不正確\n範例：SK-2026-ABCD-1234');
      return;
    }

    setState(() { _loading = true; _errorMsg = null; });

    final res = await LkAuthService.login(code);

    if (!mounted) return;
    setState(() => _loading = false);

    switch (res.result) {
      case LkLoginResult.success:
        StudyLogger.login(res.keyCode ?? code);
        context.go('/');
      case LkLoginResult.notFound:
        setState(() => _errorMsg = '找不到此授權碼，請確認後重試');
      case LkLoginResult.expired:
        setState(() => _errorMsg = '此授權碼已於 ${res.expiresAt?.toLocal().toString().substring(0,10)} 到期');
      case LkLoginResult.maxUsed:
        setState(() => _errorMsg = '此授權碼使用名額已滿，請洽管理人員');
      case LkLoginResult.disabled:
        setState(() => _errorMsg = '此授權碼已停用，請洽管理人員');
      case LkLoginResult.error:
        setState(() => _errorMsg = '驗證失敗：${res.error}');
    }
  }

  void _toggleMode() {
    setState(() {
      _showKeyLogin = !_showKeyLogin;
      _errorMsg = null;
    });
  }

  InputDecoration _fieldDecoration(String label, {bool required = false}) {
    return InputDecoration(
      labelText: required ? '$label *' : label,
      labelStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: const Color(0xFF16213E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 88, height: 88,
            decoration: BoxDecoration(color: Colors.teal.shade700, shape: BoxShape.circle),
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 44),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '外幣保險資格測驗',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        const Text(
          '填寫以下資料即可自動取得 60 天使用權限',
          style: TextStyle(color: Colors.white60, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nameCtrl,
          enabled: !_loading,
          style: const TextStyle(color: Colors.white),
          decoration: _fieldDecoration('姓名', required: true),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _unitCtrl,
          enabled: !_loading,
          style: const TextStyle(color: Colors.white),
          decoration: _fieldDecoration('單位', required: true),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _employeeIdCtrl,
          enabled: !_loading,
          style: const TextStyle(color: Colors.white),
          decoration: _fieldDecoration('員編', required: true),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _submitRegister,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            child: _loading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text('送出並開始學習'),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _loading ? null : _toggleMode,
          child: const Text('改用授權碼登入', style: TextStyle(color: Colors.white38)),
        ),
      ],
    );
  }

  Widget _buildKeyLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 88, height: 88,
            decoration: BoxDecoration(color: Colors.teal.shade700, shape: BoxShape.circle),
            child: const Icon(Icons.vpn_key_rounded, color: Colors.white, size: 44),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '外幣保險資格測驗',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        const Text(
          '請輸入課程授權碼以開始學習',
          style: TextStyle(color: Colors.white60, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 36),
        const Text('授權碼', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _errorMsg != null ? Colors.red.shade400 : Colors.white24),
          ),
          child: TextField(
            controller: _codeCtrl,
            enabled: !_loading,
            style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 18, letterSpacing: 2),
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              hintText: 'SK-2026-ABCD-1234',
              hintStyle: TextStyle(color: Colors.white30, fontSize: 14),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
              LengthLimitingTextInputFormatter(17),
              _LkFormatter(),
            ],
            onSubmitted: (_) => _loginWithCode(),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '授權碼由教育訓練單位提供，格式為 SK-YYYY-XXXX-NNNN',
          style: TextStyle(color: Colors.white38, fontSize: 11),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _loginWithCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            child: _loading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text('驗證授權碼並進入'),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _loading ? null : _toggleMode,
          child: const Text('改用學員報名表單', style: TextStyle(color: Colors.white38)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _showKeyLogin ? _buildKeyLoginForm() : _buildRegisterForm(),
                  if (_errorMsg != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_errorMsg!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 自動格式化：SK-XXXX-XXXX-XXXX ────────────
class _LkFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.toUpperCase().replaceAll('-', '');
    final buf = StringBuffer();
    for (int i = 0; i < text.length && i < 14; i++) {
      if (i == 2 || i == 6 || i == 10) buf.write('-');
      buf.write(text[i]);
    }
    final result = buf.toString();
    return newValue.copyWith(text: result, selection: TextSelection.collapsed(offset: result.length));
  }
}
