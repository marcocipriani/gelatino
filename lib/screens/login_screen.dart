import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_tokens.dart';
import '../design/responsive.dart';
import '../e2e/e2e_config.dart';
import '../e2e/emulator_test_login.dart';
import '../firebase/firebase_providers.dart';
import '../providers/router_auth_provider.dart';
import '../utils/auth_redirect.dart';
import '../widgets/access_brand_panel.dart';
import '../widgets/access_photo_panel.dart';
import '../constants/app_strings.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _safeAuthError = AppStrings.loginFailed;

  var _isSigningIn = false;
  String? _authError;

  Future<void> _signInWithGoogle() async {
    if (_isSigningIn) return;

    final redirect = safeInternalRedirect(
      GoRouterState.of(context).uri.queryParameters['redirect'],
    );
    setState(() {
      _isSigningIn = true;
      _authError = null;
    });

    try {
      await ref.read(routerAuthSessionProvider).signInWithGoogle();
      if (!mounted) return;
      context.go(redirect ?? '/collection');
    } on Object {
      if (!mounted) return;
      setState(() {
        _isSigningIn = false;
        _authError = _safeAuthError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final responsive = ResponsiveClass.fromWidth(
                  constraints.maxWidth,
                );
                final brand = AccessBrandPanel(
                  key: const ValueKey('access-brand-panel'),
                  isLoading: _isSigningIn,
                  errorMessage: _authError,
                  onSignIn: _isSigningIn ? null : _signInWithGoogle,
                  contentPadding: responsive == ResponsiveClass.wide
                      ? const EdgeInsets.all(AppSpacing.xl)
                      : EdgeInsets.zero,
                  titleFontSize: responsive == ResponsiveClass.wide ? 52 : 42,
                  maxContentWidth: responsive == ResponsiveClass.wide
                      ? 520
                      : double.infinity,
                  independentlyScrollable: responsive == ResponsiveClass.wide,
                );

                if (responsive == ResponsiveClass.wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 48, child: brand),
                      const Expanded(
                        flex: 52,
                        child: AccessPhotoPanel(
                          key: ValueKey('access-artwork-panel'),
                          borderRadius: 0,
                        ),
                      ),
                    ],
                  );
                }

                return SafeArea(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      responsive.horizontalPadding,
                      AppSpacing.xl,
                      responsive.horizontalPadding,
                      AppSpacing.xxl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        brand,
                        const SizedBox(height: AppSpacing.xl),
                        const AspectRatio(
                          aspectRatio: 4 / 3,
                          child: AccessPhotoPanel(
                            key: ValueKey('access-artwork-panel'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (e2eControlsEnabled)
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: SafeArea(
                child: EmulatorTestLogin(
                  auth: ref.watch(firebaseAuthProvider),
                  redirect: GoRouterState.of(
                    context,
                  ).uri.queryParameters['redirect'],
                  onSignedIn: context.go,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
