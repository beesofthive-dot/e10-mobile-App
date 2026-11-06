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

  /// Seconds until "Resend code" can be tapped again (0 = ready).
  int _resendIn = 0;
  Timer? _resendTimer;
  // Staff sign in with a one-time code by default, same as the website;
  // password stays one tap away.
  bool _staffUseOtc = true;

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
    _resendTimer?.cancel();
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
      return _email.text.trim().isEmpty ? 'Enter your email or phone number.' : null;
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
            _startResendCooldown();
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
  // RESEND CODE
  // ==============================================================
  //
  // Asks the same request-code endpoint again (guardian phone or staff
  // email/phone), keeping what the person typed. A 30 s wait between sends
  // stops repeated taps from flooding their phone or hitting the server's
  // rate limit.

  void _startResendCooldown() {
    _resendTimer?.cancel();
    _resendIn = 30;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _resendIn = _resendIn > 0 ? _resendIn - 1 : 0);
      if (_resendIn == 0) t.cancel();
    });
  }

  void _stopResendCooldown() {
    _resendTimer?.cancel();
    _resendIn = 0;
  }

  Future<void> _resendCode() async {
    if (_busy || _resendIn > 0) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final result = _isParent ? await Auth.guardianCode(_phone.text.trim()) : await Auth.staffCode(_email.text);
      if (!mounted) return;
      setState(() {
        if (result.error != null) {
          _error = result.error;
        } else {
          _code.clear();
          _info = (result.info == null || result.info!.isEmpty) ? 'A new code has been sent.' : result.info;
          if (result.otc != null && result.otc!.isNotEmpty) _code.text = result.otc!;
          _startResendCooldown();
        }
      });
    } on TimeoutException {
      if (mounted) setState(() => _error = 'Could not send a new code. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _codeActions(String differentLabel) => Row(
        children: [
          TextButton(
            onPressed: _busy || _resendIn > 0 ? null : _resendCode,
            child: Text(
              _resendIn > 0 ? 'Resend code in ${_resendIn}s' : 'Resend code',
              style: AppText.body(
                size: 12,
                weight: FontWeight.w600,
                color: _busy || _resendIn > 0 ? AppColors.slate400 : AppColors.honey,
              ),
            ),
          ),
          const Spacer(),
          Flexible(
            child: TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      setState(() {
                        _codeSent = false;
                        _stopResendCooldown();
                        _code.clear();
                        _info = null;
                        _error = null;
                      });
                    },
              child: Text(
                differentLabel,
                textAlign: TextAlign.end,
                style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.honey),
              ),
            ),
          ),
        ],
      );

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
          _startResendCooldown();

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
  // FORGOT / RESET PASSWORD
  // ==============================================================
  //
  // Same two steps as the website:
  //   1. POST /auth/password/forgot {email}            → a 6-digit code
  //   2. POST /auth/password/reset  {email, code,
  //        password, password_confirmation}
  // The old dialog sent `token` (the server wants `code`) and asked for a
  // fresh code on every tap, replacing the one the user had just typed.

  static Future<Map<String, dynamic>> _postJson(Uri url, Map<String, dynamic> body) async {
    final response = await http
        .post(url, headers: _jsonHeaders, body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }
    return {
      if (decoded is Map) ...Map<String, dynamic>.from(decoded),
      '_status': response.statusCode,
    };
  }

  /// The server's first field error, else its message.
  static String? _apiError(Map<String, dynamic> body) {
    final errors = body['errors'];
    if (errors is Map) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty) return '${value.first}';
        if (value is String && value.isNotEmpty) return value;
      }
    }
    final message = body['message']?.toString();
    return message == null || message.isEmpty ? null : message;
  }

  Future<void> _showForgotPasswordDialog() async {
    final email = await showDialog<String>(
      context: context,
      builder: (_) => _ResetPasswordDialog(
        initialEmail: _email.text.trim().contains('@') ? _email.text.trim() : '',
        forgotUrl: _forgotPasswordUrl,
        resetUrl: _resetPasswordUrl,
        post: _postJson,
        errorOf: _apiError,
      ),
    );
    if (!mounted || email == null) return;
    // Password changed: put them on the password form with their email filled.
    setState(() {
      _staffUseOtc = false;
      _codeSent = false;
      _email.text = email;
      _password.clear();
      _error = null;
      _info = 'Password reset. Sign in with your new password.';
    });
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
      if ((_isParent || _staffUseOtc) &&
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

    if (_staffUseOtc && !_codeSent) return 'Send my code';

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

                          _codeActions('Use a different number'),
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
                          label: _staffUseOtc ? 'EMAIL OR PHONE' : 'EMAIL ADDRESS',
                          controller: _email,
                          keyboard: _staffUseOtc ? TextInputType.text : TextInputType.emailAddress,
                          enabled: !_busy && !(_staffUseOtc && _codeSent),
                        ),
                        if (_staffUseOtc && !_codeSent) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Enter the phone or email the school has for you, and we’ll send it a one-time code.',
                            style: AppText.body(size: 11, color: AppColors.slate500),
                          ),
                        ],

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
                          _codeActions('Use a different email or phone'),
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
                              onPressed: _busy ? null : _showForgotPasswordDialog,
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
                              'Parents sign in with telephone number and one-time code (OTC). Staff sign in with email or phone and a one-time code, or email and password.',
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

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({
    required this.initialEmail,
    required this.forgotUrl,
    required this.resetUrl,
    required this.post,
    required this.errorOf,
  });

  final String initialEmail;
  final Uri forgotUrl;
  final Uri resetUrl;
  final Future<Map<String, dynamic>> Function(Uri, Map<String, dynamic>) post;
  final String? Function(Map<String, dynamic>) errorOf;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _emailOk => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  Future<void> _sendCode() async {
    if (!_emailOk) {
      setState(() => _error = 'Enter the email address on your account.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final body = await widget.post(widget.forgotUrl, {'email': _email.text.trim()});
      if (!mounted) return;
      final status = body['_status'] as int? ?? 0;
      if (status < 200 || status >= 300) {
        setState(() => _error = widget.errorOf(body) ?? 'Could not send a reset code.');
        return;
      }
      // When the school has no email delivery yet, the server returns the
      // code itself (the website shows it as a "dev code").
      final data = body['data'];
      final otc = (data is Map ? data['otc'] : body['otc'])?.toString().replaceAll(RegExp(r'\D'), '') ?? '';
      setState(() {
        _codeSent = true;
        _code.text = otc.length == 6 ? otc : '';
        _info = otc.length == 6
            ? 'Email delivery is not connected yet, so your code is $otc. Choose a new password below.'
            : (body['message']?.toString() ?? 'A 6-digit reset code has been sent to ${_email.text.trim()}.');
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Cannot reach the school server. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final code = _code.text.replaceAll(RegExp(r'\D'), '');
    final password = _password.text;
    String? problem;
    if (code.length != 6) {
      problem = 'Enter the 6-digit code from your email.';
    } else if (password.length < 8) {
      problem = 'Use at least 8 characters for the new password.';
    } else if (password != _confirm.text) {
      problem = 'The two passwords do not match.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final body = await widget.post(widget.resetUrl, {
        'email': _email.text.trim(),
        'code': code,
        'password': password,
        'password_confirmation': _confirm.text,
      });
      if (!mounted) return;
      final status = body['_status'] as int? ?? 0;
      if (status >= 200 && status < 300) {
        Navigator.of(context).pop(_email.text.trim());
        return;
      }
      setState(() => _error = widget.errorOf(body) ?? 'That code is invalid or has expired.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Cannot reach the school server. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label, {Widget? suffix}) => InputDecoration(labelText: label, suffixIcon: suffix);
    return AlertDialog(
      title: const Text('Reset your password'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _codeSent
                  ? 'Enter the 6-digit code sent to ${_email.text.trim()}, and choose a new password.'
                  : "Enter the email on your account and we'll send you a code to reset your password.",
              style: AppText.body(size: 13, color: AppColors.slate500),
            ),
            const SizedBox(height: 12),
            if (_error != null) ...[
              Text(_error!, style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.rose)),
              const SizedBox(height: 8),
            ],
            if (_info != null && _codeSent) ...[
              Text(_info!, style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.emerald)),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _email,
              enabled: !_busy && !_codeSent,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: deco('Email address'),
              onSubmitted: (_) => _codeSent ? null : _sendCode(),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _code,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: 6,
                decoration: deco('6-digit code'),
              ),
              TextField(
                controller: _password,
                enabled: !_busy,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.newPassword],
                decoration: deco(
                  'New password (at least 8 characters)',
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirm,
                enabled: !_busy,
                obscureText: _obscure,
                decoration: deco('Confirm new password'),
                onSubmitted: (_) => _reset(),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _codeSent = false;
                            _code.clear();
                            _error = null;
                            _info = null;
                          }),
                  child: const Text('Use a different email or send a new code'),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : (_codeSent ? _reset : _sendCode),
          child: Text(_busy ? (_codeSent ? 'Resetting…' : 'Sending…') : (_codeSent ? 'Reset password' : 'Send reset code')),
        ),
      ],
    );
  }
}
