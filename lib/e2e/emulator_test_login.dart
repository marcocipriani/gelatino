import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/auth_redirect.dart';
import 'e2e_config.dart';

final class EmulatorTestLogin extends ConsumerStatefulWidget {
  const EmulatorTestLogin({
    required this.auth,
    required this.redirect,
    required this.onSignedIn,
    super.key,
  });

  final FirebaseAuth auth;
  final String? redirect;
  final ValueChanged<String> onSignedIn;

  @override
  ConsumerState<EmulatorTestLogin> createState() => _EmulatorTestLoginState();
}

final class _EmulatorTestLoginState extends ConsumerState<EmulatorTestLogin> {
  static const _alice = (
    label: 'Accedi come Alice E2E',
    email: 'e2e-alice@example.test',
    password: 'gelatino-e2e-alice',
  );
  static const _bob = (
    label: 'Accedi come Bob E2E',
    email: 'e2e-bob@example.test',
    password: 'gelatino-e2e-bob',
  );
  static const _safeError = 'Accesso E2E non riuscito.';

  bool _busy = false;
  String? _error;

  Future<void> _signIn(
    ({String label, String email, String password}) credential,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.signInWithEmailAndPassword(
        email: credential.email,
        password: credential.password,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onSignedIn(safeInternalRedirect(widget.redirect) ?? '/collection');
    } on Object {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _safeError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!e2eControlsEnabled) {
      throw StateError('EmulatorTestLogin requires guarded E2E emulators.');
    }
    return Card(
      key: const ValueKey('e2e-emulator-login'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final credential in [_alice, _bob])
              OutlinedButton(
                onPressed: _busy ? null : () => _signIn(credential),
                child: Text(credential.label),
              ),
            if (_busy)
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            if (_error case final error?) Text(error),
          ],
        ),
      ),
    );
  }
}
