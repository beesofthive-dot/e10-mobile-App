import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:e10/core/config/api_config.dart';
import '../auth.dart';
import '../models.dart';
import '../school_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'admin_forms.dart';
import '../widgets/popups.dart';
import 'select_child_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onLogin,
    this.initialRole = Role.parent,
    this.onRegisterSchool,
  });

  final Future<void> Function(AppUser user) onLogin;
  final Role initialRole;
  final VoidCallback? onRegisterSchool;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late Role _role;
  late final AnimationController _entrance;

  late final TextEditingController _email;
  late final TextEditingController _password;
  late final TextEditingController _phone;
  late final TextEditingController _code;

  bool _remember = true;
  bool _obscure = true;
  bool _busy = false;
  bool _codeSent = false;
  bool _staffUseOtc = false;

  String? _error;
  String? _info;

  bool get _isParent => _role == Role.parent;

  // ==============================================================
  // Shared API base for all login requests.
  // ==============================================================

  static Uri _api(String path) {
    return ApiConfig.endpoint(path);
  }

  // ==============================================================
  // ENDPOINT STRUCTURE
  // ==============================================================

  static Uri get _forgotPasswordUrl => _api('auth/password/forgot');

  static Uri get _resetPasswordUrl => _api('auth/password/reset');

  // ==============================================================
  // COMMON API HEADERS
  // ==============================================================

  static const Map<String, String> _jsonHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  // ==============================================================
  // ROLE
  // ==============================================================

  // Only two tabs are shown now — Parent and Staff. Staff covers both
  // teacher and admin: `_submitNow` already sends every non-parent login
  // through the exact same Auth.signIn/Auth.staffCode calls regardless of
  // which of the old three tabs was selected, and which dashboard opens
  // afterwards is decided from the authenticated user's real role
  // (Auth.roleFromApi), not from this tab. `Role.teacher` is kept as the
  // internal placeholder for "the Staff tab" purely so `_role` doesn't need
  // a new type — it has no effect on which endpoint gets called.
  static Role _loginTab(Role role) {
    return role == Role.parent ? Role.parent : Role.teacher;
  }

  static String _tabLabel(Role role) => switch (role) {
        Role.parent => 'PARENT LOGIN',
        _ => 'STAFF LOGIN',
      };

  // ==============================================================
  // INIT
  // ==============================================================

  @override
  void initState() {
    super.initState();

    _role = _loginTab(widget.initialRole);
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();

    _email = TextEditingController();
    _password = TextEditingController();
    _phone = TextEditingController();
    _code = TextEditingController();

    _checkApi();
  }

  // ==============================================================
  // API CHECK
  // ==============================================================

  Future<void> _checkApi() async {
    await ApiConfig.probe();

    if (!mounted) return;

    setState(() {});
  }

  // ==============================================================
  // DISPOSE
  // ==============================================================

  @override
  void dispose() {
    _entrance.dispose();
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _code.dispose();

    super.dispose();
  }

  // ==============================================================
  // ROLE SWITCH
  // ==============================================================

  void _selectRole(Role role) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _role = role;

      _error = null;
      _info = null;

      _codeSent = false;
      _code.clear();
    });
  }

  // ==============================================================
  // LOGIN CHECK
  // ==============================================================

  // Submitting a blank field used to go straight to the API and come back
  // as a 422 ("The email/password field is required.") — a real round trip
  // for something we already know client-side. Check first instead.
  String? _blankFieldError() {
    if (_isParent) {
      if (_codeSent) return _code.text.trim().isEmpty ? 'Enter the one-time code sent to your phone.' : null;
      return _phone.text.trim().isEmpty ? 'Enter the parent telephone number.' : null;
    }
    if (_staffUseOtc) {
      if (_codeSent) return _code.text.trim().isEmpty ? 'Enter the one-time code.' : null;
      return _email.text.trim().isEmpty ? 'Enter the staff email address.' : null;
    }
    if (_email.text.trim().isEmpty) return 'Enter the email address.';
    if (_password.text.isEmpty) return 'Enter the password.';
    return null;
  }

  Future<void> _submit() async {
    if (_busy) return;

    final blank = _blankFieldError();
    if (blank != null) {
      setState(() => _error = blank);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _submitNow();
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _error =
            'Login timed out. Check your school API connection.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // ==============================================================
  // MAIN LOGIN
  // ==============================================================
  //
  // IMPORTANT:
  //
  // Do not replace these Auth methods.
  //
  // They preserve your existing:
  // - staff password login
  // - guardian phone OTC
  // - session/token handling
  //
  // ==============================================================

  Future<void> _submitNow() async {
    if (_isParent) {
      await _submitParent();
      return;
    }

    if (_staffUseOtc) {
      if (!_codeSent) {
        final result = await Auth.staffCode(_email.text);
        if (!mounted) return;
        setState(() {
          _busy = false;
          if (result.error != null) {
            _error = result.error;
          } else {
            _codeSent = true;
            _info = result.info;
            if (result.otc != null && result.otc!.isNotEmpty) _code.text = result.otc!;
          }
        });
        return;
      }
      final result = await Auth.verifyStaff(
        email: _email.text,
        code: _code.text,
      );
      if (!mounted) return;
      if (!result.ok) {
        setState(() => _error = result.error);
        return;
      }
      setState(() => _info = 'Login successful.');
      await widget.onLogin(result.user!);
      return;
    }

    final result = await Auth.signIn(
      email: _email.text.trim(),
      password: _password.text,
    );

    if (!mounted) return;

    if (!result.ok) {
      setState(() {
        _error = result.error;
      });

      return;
    }

    setState(() => _info = 'Login successful.');
    await widget.onLogin(
      result.user!,
    );
  }

  // ==============================================================
  // PARENT OTC
  // ==============================================================
  //
  // Existing production flow:
  //
  // POST /auth/guardian/request-code
  //
  // POST /auth/guardian/verify-code
  //
  // We intentionally keep Auth.guardianCode and
  // Auth.verifyGuardian so the existing implementation is not
  // broken.
  // ==============================================================

  Future<void> _submitParent() async {
    if (!_codeSent) {
      final result =
          await Auth.guardianCode(
        _phone.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _busy = false;

        if (result.error != null) {
          _error = result.error;
        } else {
          _codeSent = true;
          _info = result.info;

          if (result.otc != null &&
              result.otc!.isNotEmpty) {
            _code.text = result.otc!;
          }
        }
      });

      return;
    }

    final result =
        await Auth.verifyGuardian(
      phone: _phone.text.trim(),
      code: _code.text.trim(),
    );

    if (!mounted) return;

    if (!result.ok) {
      setState(() {
        _error = result.error;
      });

      return;
    }

    setState(() => _info = 'Login successful.');

    // A guardian's phone number can be linked to more than one school
    // running e10 — each a fully separate account under the hood (see the
    // backend's GuardianAuthController::findActiveGuardianUser). The
    // verify-code response's `guardian_schools` lists every one of them
    // (confirmed live against the deployed API — just id/name, no
    // children: those only load once a specific school is entered). When
    // there's a real choice to make, ask which school to go in as before
    // landing on a dashboard; a phone linked to just one school skips
    // straight through like before.
    if (mounted) {
      final store = SchoolScope.of(context);
      final schools = store.guardianSchools();
      if (schools.length > 1) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => SelectChildScreen(
              schools: schools,
              initialUser: result.user!,
              onContinue: widget.onLogin,
            ),
          ),
        );
        return;
      }
    }

    await widget.onLogin(
      result.user!,
    );
  }

  // ==============================================================
  // FORGOT PASSWORD
  // ==============================================================
  //
  // POST:
  // /api/auth/password/forgot
  //
  // Body:
  // {
  //   "email": "user@example.com"
  // }
  //
  // ==============================================================

  Future<Map<String, dynamic>>
      _forgotPasswordRequest(
    String email,
  ) async {
    final response = await http.post(
      _forgotPasswordUrl,
      headers: _jsonHeaders,
      body: jsonEncode({
        'email': email,
      }),
    );

    dynamic decoded;

    try {
      decoded = jsonDecode(
        response.body,
      );
    } catch (_) {
      decoded = {
        'message': response.body,
      };
    }

    if (decoded is Map<String, dynamic>) {
      return {
        ...decoded,
        '_status': response.statusCode,
      };
    }

    return {
      'message': response.body,
      '_status': response.statusCode,
    };
  }

  // ==============================================================
  // RESET PASSWORD
  // ==============================================================
  //
  // POST:
  // /api/auth/password/reset
  //
  // Body:
  // {
  //   "email": "...",
  //   "token": "...",
  //   "password": "...",
  //   "password_confirmation": "..."
  // }
  //
  // ==============================================================

  Future<Map<String, dynamic>>
      _resetPasswordRequest({
    required String email,
    required String token,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await http.post(
      _resetPasswordUrl,
      headers: _jsonHeaders,
      body: jsonEncode({
        'email': email,
        'token': token,
        'password': password,
        'password_confirmation':
            passwordConfirmation,
      }),
    );

    dynamic decoded;

    try {
      decoded = jsonDecode(
        response.body,
      );
    } catch (_) {
      decoded = {
        'message': response.body,
      };
    }

    if (decoded is Map<String, dynamic>) {
      return {
        ...decoded,
        '_status': response.statusCode,
      };
    }

    return {
      'message': response.body,
      '_status': response.statusCode,
    };
  }

  // ==============================================================
  // FORGOT / RESET PASSWORD DIALOG
  // ==============================================================

  Future<void> _showForgotPasswordDialog() async {
    final emailController =
        TextEditingController(
      text: _email.text.trim(),
    );

    final tokenController =
        TextEditingController();

    final passwordController =
        TextEditingController();

    final confirmController =
        TextEditingController();

    final busy =
        ValueNotifier<bool>(false);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title:
              const Text('Reset password'),
          content:
              ValueListenableBuilder<bool>(
            valueListenable: busy,
            builder:
                (context, isBusy, child) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .stretch,
                  children: [
                    TextField(
                      controller:
                          emailController,
                      enabled: !isBusy,
                      keyboardType:
                          TextInputType
                              .emailAddress,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Email address',
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    TextField(
                      controller:
                          tokenController,
                      enabled: !isBusy,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Token / reset code',
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    TextField(
                      controller:
                          passwordController,
                      enabled: !isBusy,
                      obscureText: true,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'New password',
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    TextField(
                      controller:
                          confirmController,
                      enabled: !isBusy,
                      obscureText: true,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Confirm password',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                closeRoute(
                  dialogContext,
                );
              },
              child:
                  const Text('Close'),
            ),

            FilledButton(
              onPressed: () async {
                if (busy.value) {
                  return;
                }

                final messenger = ScaffoldMessenger.maybeOf(context);

                final email =
                    emailController.text
                        .trim();

                if (email.isEmpty) {
                  showSnack(context, 'Enter your email address.');

                  return;
                }

                busy.value = true;

                try {
                  // =================================================
                  // STEP 1
                  // SEND RESET REQUEST
                  // =================================================

                  final forgot =
                      await _forgotPasswordRequest(
                    email,
                  );

                  final forgotStatus =
                      forgot['_status']
                          as int? ??
                      0;

                  final forgotMessage =
                      forgot['message']
                          ?.toString() ??
                      forgot['info']
                          ?.toString();

                  if (forgotStatus < 200 ||
                      forgotStatus >= 300) {
                    if (!mounted || messenger == null || !messenger.mounted) return;

                    showSnack(context, forgotMessage ??
                              'Unable to request password reset.');

                    return;
                  }

                  if (!mounted || messenger == null || !messenger.mounted) return;

                  // =================================================
                  // STEP 2
                  // IF USER HAS NOT ENTERED RESET DETAILS YET,
                  // KEEP DIALOG OPEN SO THEY CAN ENTER TOKEN.
                  // =================================================

                  final token =
                      tokenController.text
                          .trim();

                  final password =
                      passwordController.text
                          .trim();

                  final confirm =
                      confirmController.text
                          .trim();

                  if (token.isEmpty &&
                      password.isEmpty &&
                      confirm.isEmpty) {
                    if (!mounted || !messenger.mounted) return;

                    showSnack(context, forgotMessage ??
                              'If that email exists, a reset code or link was sent.');

                    return;
                  }

                  // =================================================
                  // STEP 3
                  // VALIDATE PASSWORD
                  // =================================================

                  if (token.isEmpty) {
                    showSnack(context, 'Enter the reset token or code.');

                    return;
                  }

                  if (password.isEmpty ||
                      confirm.isEmpty) {
                    showSnack(context, 'Enter the new password and confirmation.');

                    return;
                  }

                  if (password !=
                      confirm) {
                    showSnack(context, 'Passwords do not match.');

                    return;
                  }

                  // =================================================
                  // STEP 4
                  // RESET PASSWORD
                  // =================================================

                  final reset =
                      await _resetPasswordRequest(
                    email: email,
                    token: token,
                    password: password,
                    passwordConfirmation:
                        confirm,
                  );

                  final resetStatus =
                      reset['_status']
                          as int? ??
                      0;

                  final resetMessage =
                      reset['message']
                          ?.toString() ??
                      reset['info']
                          ?.toString();

                  if (!mounted || !messenger.mounted || !dialogContext.mounted) return;

                  if (resetStatus >= 200 &&
                      resetStatus < 300) {
                    closeRoute(
                      dialogContext,
                    );

                    showSnack(context, resetMessage ??
                              'Password reset successfully.');
                  } else {
                    showSnack(context, resetMessage ??
                              'Password reset failed.');
                  }
                } finally {
                  busy.value = false;
                }
              },
              child:
                  const Text('Send'),
            ),
          ],
        );
      },
    );

    disposeAfterClose([emailController, tokenController, passwordController, confirmController, busy]);
  }

  // ==============================================================
  // INFORMATION DIALOG
  // ==============================================================

  void _showNote(
    String title,
    String body,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) =>
          AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () =>
                closeRoute(context),
            child:
                const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // BUTTON
  // ==============================================================

  String get _buttonLabel {
    if (_busy) {
      if (_isParent &&
          !_codeSent) {
        return 'Sending code...';
      }

      return 'Checking...';
    }

    if (_isParent) {
      return _codeSent
          ? 'Let’s go in'
          : 'Send my code';
    }

    return 'Let’s go in';
  }

  // ==============================================================
  // UI
  // ==============================================================

  @override
  Widget build(BuildContext context) {
    final bottom =
        MediaQuery.paddingOf(context)
            .bottom;

    // A one-shot fade + gentle rise on first appearance instead of the
    // sign-in screen simply snapping into view. Driven by `_entrance`
    // (an AnimationController played once in initState) rather than a
    // TweenAnimationBuilder — this screen's own field edits call setState
    // constantly, and a fresh Tween instance on every rebuild would restart
    // a TweenAnimationBuilder's animation each keystroke.
    return AnimatedBuilder(
      animation: _entrance,
      builder: (context, child) => Opacity(
        opacity: _entrance.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _entrance.value) * 16),
          child: child,
        ),
      ),
      child: Scaffold(
      backgroundColor:
          Colors.transparent,
      body: DecoratedBox(
        decoration:
            const BoxDecoration(
          gradient:
              AppGradients.chrome,
        ),
        // Always the phone layout — logo on top, form sheet below, one
        // column at phone width. On a short screen (phone turned sideways)
        // the whole page scrolls instead of splitting into two columns.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  24,
                  8,
                  24,
                  12,
                ),
                child: Column(
                  children: [
                    const AppLogo(size: 96),

                    const SizedBox(
                      height: 18,
                    ),

                    Text(
                      'Welcome back',
                      style:
                          AppText.display(
                        size: 28,
                        weight:
                            FontWeight.w800,
                        color:
                            Colors.white,
                      ),
                    ),

                    const SizedBox(
                      height: 6,
                    ),

                    Text(
                      _isParent
                          ? 'Secure parent access with your phone number and one-time code.'
                          : 'Professional school access for staff and administrators.',
                      textAlign:
                          TextAlign.center,
                      style:
                          AppText.body(
                        size: 13,
                        color: Colors.white
                            .withValues(
                          alpha: 0.72,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    Container(
                      padding:
                          const EdgeInsets.all(
                        4,
                      ),
                      decoration:
                          BoxDecoration(
                        color: Colors.white
                            .withValues(
                          alpha: 0.08,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(18),
                        border: Border.all(
                          color: Colors.white
                              .withValues(
                            alpha: 0.1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          for (final r in const [
                            Role.parent,
                            Role.teacher,
                          ])
                            Expanded(
                              child:
                                  GestureDetector(
                                onTap: () =>
                                    _selectRole(
                                  r,
                                ),
                                child:
                                    AnimatedContainer(
                                  duration:
                                      const Duration(
                                    milliseconds:
                                        180,
                                  ),
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                    vertical:
                                        11,
                                  ),
                                  decoration:
                                      BoxDecoration(
                                    gradient:
                                        _role == r
                                            ? AppGradients
                                                .honey
                                            : null,
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      12,
                                    ),
                                  ),
                                  child:
                                      Text(
                                    _tabLabel(r),
                                    textAlign:
                                        TextAlign
                                            .center,
                                    style:
                                        AppText.body(
                                      size: 12,
                                      weight:
                                          FontWeight
                                              .w800,
                                      letterSpacing:
                                          0.7,
                                      color:
                                          _role == r
                                              ? Colors
                                                  .white
                                              : Colors
                                                  .white
                                                  .withValues(
                                                  alpha:
                                                      0.6,
                                                ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: Container(
                width:
                    double.infinity,
                decoration:
                    BoxDecoration(
                  color:
                      AppSurface.card(
                    context,
                  ),
                  borderRadius: const BorderRadius
                          .vertical(
                    top: Radius.circular(
                      AppRadius.sheet,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors
                          .honey
                          .withValues(
                        alpha: 0.12,
                      ),
                      blurRadius: 20,
                      offset:
                          const Offset(
                        0,
                        -8,
                      ),
                    ),
                  ],
                ),
                child:
                    Padding(
                  padding:
                      EdgeInsets.fromLTRB(
                    24,
                    28,
                    24,
                    16 + bottom,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .stretch,
                    children: [
                      if (_isParent) ...[
                        _UnderlineField(
                          label:
                              'TELEPHONE NUMBER',
                          controller:
                              _phone,
                          keyboard:
                              TextInputType
                                  .phone,
                          enabled:
                              !_busy &&
                                  !_codeSent,
                        ),

                        if (_codeSent) ...[
                          const SizedBox(
                            height: 22,
                          ),

                          _UnderlineField(
                            label:
                                'ONE-TIME CODE (OTC)',
                            controller:
                                _code,
                            keyboard:
                                TextInputType
                                    .number,
                            enabled:
                                !_busy,
                          ),

                          Align(
                            alignment:
                                Alignment
                                    .centerRight,
                            child:
                                TextButton(
                              onPressed:
                                  _busy
                                      ? null
                                      : () {
                                          FocusManager.instance.primaryFocus?.unfocus();
                                          setState(
                                            () {
                                              _codeSent =
                                                  false;
                                              _code
                                                  .clear();
                                              _info =
                                                  null;
                                              _error =
                                                  null;
                                            },
                                          );
                                        },
                              child: Text(
                                'Use a different number',
                                style:
                                    AppText.body(
                                  size: 12,
                                  weight:
                                      FontWeight
                                          .w600,
                                  color:
                                      AppColors
                                          .honey,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: _TeacherKindChip(
                                label: 'Password',
                                selected: !_staffUseOtc,
                                onTap: _busy ? null : () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  setState(() {
                                    _staffUseOtc = false;
                                    _codeSent = false;
                                    _code.clear();
                                    _error = null;
                                    _info = null;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _TeacherKindChip(
                                label: 'Staff OTC',
                                selected: _staffUseOtc,
                                onTap: _busy ? null : () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  setState(() {
                                    _staffUseOtc = true;
                                    _codeSent = false;
                                    _code.clear();
                                    _error = null;
                                    _info = null;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),

                        _UnderlineField(
                          label:
                              'EMAIL ADDRESS',
                          controller:
                              _email,
                          keyboard:
                              TextInputType
                                  .emailAddress,
                          enabled:
                              !_busy,
                        ),

                        const SizedBox(
                          height: 22,
                        ),

                        if (_staffUseOtc && _codeSent) ...[
                          _UnderlineField(
                            label: 'ONE-TIME CODE (OTC)',
                            controller: _code,
                            keyboard: TextInputType.number,
                            enabled: !_busy,
                          ),
                        ] else if (!_staffUseOtc) ...[
                          _UnderlineField(
                            label: 'PASSWORD',
                            controller: _password,
                            obscure: _obscure,
                            enabled: !_busy,
                            suffix: IconButton(
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                size: 18,
                                color: AppColors.slate400,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Wraps "Forgot Password?" onto its own line when
                        // the form is too narrow for both.
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  Checkbox(
                                value:
                                    _remember,
                                activeColor:
                                    AppColors
                                        .honey,
                                side:
                                    const BorderSide(
                                  color:
                                      AppColors
                                          .slate300,
                                ),
                                onChanged:
                                    _busy
                                        ? null
                                        : (v) =>
                                            setState(
                                          () =>
                                              _remember =
                                                  v ??
                                                      false,
                                        ),
                              ),
                            ),

                            const SizedBox(
                              width: 8,
                            ),

                            Text(
                              'Remember me',
                              style:
                                  AppText.body(
                                size: 12,
                                color:
                                    AppColors
                                        .slate500,
                              ),
                            ),
                              ],
                            ),

                            TextButton(
                              onPressed: _staffUseOtc ? null : _showForgotPasswordDialog,
                              child: Text(
                                'Forgot Password?',
                                style:
                                    AppText.body(
                                  size: 12,
                                  weight:
                                      FontWeight
                                          .w600,
                                  color:
                                      AppColors
                                          .honey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(
                        height: 18,
                      ),

                      _LoginButton(
                        label:
                            _buttonLabel,
                        loading:
                            _busy,
                        onPressed:
                            _busy
                                ? null
                                : _submit,
                      ),

                      const SizedBox(
                        height: 14,
                      ),

                      Wrap(
                        alignment:
                            WrapAlignment
                                .center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _FooterLink(
                            'Privacy Policy',
                            onTap: () =>
                                _showNote(
                              'Privacy Policy',
                              'Your school data stays with your school. BeeSoft Hive does not sell personal information.',
                            ),
                          ),

                          Text(
                            '  |  ',
                            style:
                                AppText.body(
                              size: 11,
                              color:
                                  AppColors
                                      .slate300,
                            ),
                          ),

                          _FooterLink(
                            'Terms',
                            onTap: () =>
                                _showNote(
                              'Terms',
                              'Use of e10 School Systems is for authorised school staff, parents, and pupils only.',
                            ),
                          ),

                          Text(
                            '  |  ',
                            style:
                                AppText.body(
                              size: 11,
                              color:
                                  AppColors
                                      .slate300,
                            ),
                          ),

                          _FooterLink(
                            'Help',
                            onTap: () =>
                                _showNote(
                              'Help',
                              'Parents sign in with telephone number and one-time code (OTC). Teachers and admins use email and password.',
                            ),
                          ),
                        ],
                      ),

                      if (widget.onRegisterSchool != null) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: GestureDetector(
                            onTap: widget.onRegisterSchool,
                            child: Text(
                              'New school? Register here',
                              style: AppText.body(
                                size: 12,
                                weight: FontWeight.w700,
                                color: AppColors.honey,
                              ),
                            ),
                          ),
                        ),
                      ],

                      if (_error != null || _info != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error ?? _info!,
                          textAlign: TextAlign.center,
                          style: AppText.body(
                            size: 12,
                            weight: FontWeight.w600,
                            color: _error != null
                              ? AppColors.rose
                              : AppColors.honey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

// ================================================================
// LOGIN BUTTON
// ================================================================

class _LoginButton
    extends StatelessWidget {
  const _LoginButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap:
            loading ? null : onPressed,
        borderRadius:
            BorderRadius.circular(14),
        child: Ink(
          height: 52,
          decoration:
              BoxDecoration(
            gradient:
                AppGradients.honey,
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                      color:
                          Colors.white,
                    ),
                  )
                : Text(
                    label,
                    style:
                        AppType.button
                            .copyWith(
                      color:
                          Colors.white,
                      fontWeight:
                          FontWeight
                              .w700,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// FOOTER LINK
// ================================================================

class _FooterLink
    extends StatelessWidget {
  const _FooterLink(
    this.label, {
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: AppText.body(
          size: 12,
          color:
              AppColors.slate500,
        ),
      ),
    );
  }
}

// ================================================================
// UNDERLINE FIELD
// ================================================================

class _UnderlineField
    extends StatelessWidget {
  const _UnderlineField({
    required this.label,
    required this.controller,
    this.obscure = false,
    this.keyboard,
    this.suffix,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboard;
  final Widget? suffix;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppText.body(
            size: 12,
            weight:
                FontWeight.w600,
            color:
                AppColors.slate500,
            letterSpacing: 0.6,
          ),
        ),

        TextField(
          controller:
              controller,
          obscureText:
              obscure,
          enabled:
              enabled,
          keyboardType:
              keyboard,
          style: AppText.body(
            size: 14,
            weight:
                FontWeight.w500,
            color:
                AppColors.slate800,
          ),
          cursorColor:
              AppColors.honey,
          decoration:
              InputDecoration(
            filled: false,
            isDense: true,
            suffixIcon:
                suffix,
            contentPadding:
                const EdgeInsets
                    .fromLTRB(
              0,
              10,
              0,
              8,
            ),
            border:
                const UnderlineInputBorder(
              borderSide:
                  BorderSide(
                color:
                    AppColors
                        .border,
              ),
            ),
            enabledBorder:
                const UnderlineInputBorder(
              borderSide:
                  BorderSide(
                color:
                    AppColors
                        .border,
              ),
            ),
            focusedBorder:
                const UnderlineInputBorder(
              borderSide:
                  BorderSide(
                color:
                    AppColors
                        .honey,
                width: 1.4,
              ),
            ),
            disabledBorder:
                const UnderlineInputBorder(
              borderSide:
                  BorderSide(
                color:
                    AppColors
                        .border,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ================================================================
// TEACHER CHIP
// ================================================================

class _TeacherKindChip
    extends StatelessWidget {
  const _TeacherKindChip({
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child:
          AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 160,
        ),
        padding:
            const EdgeInsets
                .symmetric(
          vertical: 10,
        ),
        decoration:
            BoxDecoration(
          color: selected
              ? AppColors.honey
              : AppSurface.page(
                  context,
                ),
          borderRadius:
              BorderRadius.circular(
            10,
          ),
          border: Border.all(
            color: selected
                ? AppColors.honey
                : AppColors.border,
          ),
        ),
        child: Text(
          label,
          textAlign:
              TextAlign.center,
          style:
              AppText.body(
            size: 12,
            weight:
                FontWeight.w700,
            color: selected
                ? Colors.white
                : AppColors.slate600,
          ),
        ),
      ),
    );
  }
}
