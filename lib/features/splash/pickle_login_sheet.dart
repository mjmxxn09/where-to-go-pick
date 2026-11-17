import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/pickle/pickle_repository.dart';
import '../../core/theme/app_theme.dart';

/// "픽클 계정으로 시작하기" → 이메일·비밀번호 시트. 로그인되면 true로 닫힌다.
///
/// 픽클은 회원당 활성 모바일 세션이 하나뿐이다. 다른 기기(픽클 앱 포함)에서 쓰고 있으면 서버가 409를 주고,
/// 이 앱은 자동으로 교체하지 않고 사용자에게 묻는다(docs/architecture.md "세션 충돌").
Future<bool> showPickleLoginSheet(BuildContext context, PickleRepository pickle) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => _PickleLoginForm(pickle: pickle),
  );
  return ok ?? false;
}

class _PickleLoginForm extends StatefulWidget {
  const _PickleLoginForm({required this.pickle});

  final PickleRepository pickle;

  @override
  State<_PickleLoginForm> createState() => _PickleLoginFormState();
}

class _PickleLoginFormState extends State<_PickleLoginForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit({bool replace = false}) async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = '이메일과 비밀번호를 입력해 주세요.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.pickle.login(email: email, password: password, replaceExistingSession: replace);
      if (mounted) Navigator.of(context).pop(true);
    } on SessionConflictException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final where = e.activePlatformLabel ?? '다른 기기';
      final go = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('다른 곳에서 로그인 중이에요'),
          content: Text('$where에서 픽클 계정을 쓰고 있어요. 여기서 로그인하면 그쪽은 로그아웃돼요. 계속할까요?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('여기서 로그인')),
          ],
        ),
      );
      if (go == true && mounted) await _submit(replace: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.isUnauthorized ? '이메일 또는 비밀번호가 맞지 않아요.' : e.message;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '연결이 원활하지 않아요. 잠시 후 다시 시도해 주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('픽클 계정으로 로그인', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('픽클 앱과 같은 이메일·비밀번호를 써요.', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: '이메일', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(labelText: '비밀번호', border: OutlineInputBorder()),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.secondary)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _busy ? null : () => _submit(),
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                  : const Text('로그인'),
            ),
          ),
        ],
      ),
    );
  }
}
