import '../../widgets/clinic_feedback.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/clinic_loader.dart';
import 'google_auth.dart';
import 'field_colors.dart';
import 'login_page.dart';
import 'register_page.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool open = false;
  double downwardDrag = 0;

  void trackCloseDrag(double delta) {
    downwardDrag = (downwardDrag + delta).clamp(0, 64).toDouble();
    if (open && !busy && downwardDrag >= 64) closeSheet();
  }

  late final motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      motion.stop();
      motion.value = 0;
    } else if (!motion.isAnimating) {
      motion.repeat(reverse: true);
    }
  }

  void closeSheet() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      open = false;
      showPassword = false;
    });
  }

  final form = GlobalKey<FormState>();
  final email = TextEditingController(), password = TextEditingController();
  final first = TextEditingController(), last = TextEditingController();
  final confirmPassword = TextEditingController();
  bool register = false, busy = false;
  bool showPassword = false;
  void showNotice(String message) {
    showClinicToast(context, message);
  }

  @override
  void dispose() {
    motion.dispose();
    for (final c in [email, password, first, last, confirmPassword]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> continueWithGoogle() async {
    if (busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => busy = true);
    try {
      final message = await startGoogleAuth();
      if (mounted && message != null) showNotice(message);
    } catch (_) {
      if (mounted) {
        showNotice('Could not open Google sign-in. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    setState(() => busy = true);
    try {
      if (register) {
        final result = await RegisterPage.signUp(
          email.text,
          password.text,
          first.text,
          last.text,
        );
        if (mounted && result.session == null) {
          setState(() => register = false);
          showNotice(
            'Check your email to confirm your account, then return here to log in.',
          );
        }
      } else {
        await LoginPage.signIn(email.text, password.text);
      }
    } on AuthException catch (e) {
      if (mounted) showNotice(e.message);
    } catch (_) {
      if (mounted) {
        showNotice('Unable to connect. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> sendPasswordReset() async {
    if (email.text.trim().isEmpty) {
      showNotice('Enter your email first.');
      return;
    }
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    setState(() => busy = true);
    try {
      await LoginPage.resetPassword(email.text);
      if (mounted) {
        showNotice('Password reset instructions sent to your email.');
      }
    } on AuthException catch (e) {
      if (mounted) showNotice(e.message);
    } catch (_) {
      if (mounted) {
        showNotice('Unable to send a reset email. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool secret = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ExcludeSemantics(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            height: 1.3,
            fontWeight: FontWeight.w600,
            color: charcoal,
          ),
        ),
      ),
      const SizedBox(height: 6),
      Semantics(
        label: label,
        child: TextFormField(
          autovalidateMode: AutovalidateMode.onUserInteractionIfError,
          controller: controller,
          style: const TextStyle(color: charcoal, fontSize: 16),
          obscureText: secret && (register || !showPassword),
          keyboardType: controller == email
              ? TextInputType.emailAddress
              : TextInputType.text,
          textInputAction: controller == (register ? confirmPassword : password)
              ? TextInputAction.done
              : TextInputAction.next,
          onFieldSubmitted:
              controller == (register ? confirmPassword : password)
              ? (_) => submit()
              : null,
          autofillHints: controller == email
              ? const [AutofillHints.email]
              : secret
              ? [register ? AutofillHints.newPassword : AutofillHints.password]
              : null,
          autocorrect: false,
          enableSuggestions: !secret,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            hintText: hint,
            filled: true,
            hintStyle: const TextStyle(color: Color(0xFF5D5A62)),
            fillColor: authFieldFill,
            errorStyle: authErrorStyle,
            errorBorder: authErrorBorder,
            focusedErrorBorder: authErrorBorder,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF5B3F91)),
            ),
            suffixIcon: secret && !register
                ? IconButton(
                    tooltip: showPassword ? 'Hide password' : 'Show password',
                    onPressed: () =>
                        setState(() => showPassword = !showPassword),
                    icon: Icon(
                      showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  )
                : null,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Enter your ${label.toLowerCase()}';
            }
            if (controller == email &&
                !RegExp(r'^.+@.+\..+$').hasMatch(value.trim())) {
              return 'Enter a valid email';
            }
            if (register && secret && value.length < 8) {
              return 'Use at least 8 characters';
            }
            if (controller == confirmPassword && value != password.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
      ),
    ],
  );

  static const charcoal = Color(0xFF30313A);
  static const lavender = Color(0xFFCAB7E0);

  Widget get handle => Container(
    width: 48,
    height: 4,
    decoration: BoxDecoration(
      color: const Color(0xFF53179C),
      borderRadius: BorderRadius.circular(4),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: lavender,
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: LayoutBuilder(
          builder: (context, bounds) {
            final height = bounds.maxHeight;
            final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
            final sheetHeight = keyboard
                ? height
                : (height * .5).clamp(
                    ((register ? 668.0 : 508.0) +
                            MediaQuery.paddingOf(context).bottom)
                        .clamp(0.0, height),
                    height,
                  );
            final heroHeight = open ? height - sheetHeight : height * .5;
            final duration = Duration(
              milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 280,
            );
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: height * .68,
                  child: AnimatedBuilder(
                    animation: motion,
                    child: Image.asset(
                      'assets/login-purple-field.png',
                      fit: BoxFit.fill,
                    ),
                    builder: (context, child) => Transform.scale(
                      alignment: Alignment.topCenter,
                      scaleX: 1,
                      scaleY:
                          1 + .03 * Curves.easeInOut.transform(motion.value),
                      child: child,
                    ),
                  ),
                ),
                if (heroHeight > 60)
                  Positioned(
                    left: 20,
                    right: 20,
                    top: 0,
                    height: heroHeight,
                    child: SafeArea(
                      bottom: false,
                      child: Align(
                        alignment: const Alignment(0, .75),
                        child: FractionallySizedBox(
                          heightFactor: .53,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/skills-clinic-mark.png',
                                  width: 88,
                                  height: 88,
                                ),
                                const SizedBox(height: 22),
                                const Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'SKILLS ',
                                        style: TextStyle(
                                          color: Color(0xFFFFDE59),
                                        ),
                                      ),
                                      TextSpan(text: 'CLINIC'),
                                    ],
                                  ),
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                const Text(
                                  'We Learn. We Share.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (!open)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => setState(() => open = true),
                      onVerticalDragUpdate: (details) {
                        if (details.delta.dy < 0) setState(() => open = true);
                      },
                      child: SafeArea(
                        child: Align(
                          alignment: const Alignment(0, .88),
                          child: TextButton(
                            onPressed: () => setState(() => open = true),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                handle,
                                const SizedBox(height: 16),
                                const Text('Swipe up or tap to sign in'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                AnimatedPositioned(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  left: 0,
                  right: 0,
                  height: sheetHeight,
                  bottom: open ? 0 : -sheetHeight,
                  child: Material(
                    color: lavender,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: open
                        ? SafeArea(
                            top: keyboard || heroHeight < 40,
                            child: Column(
                              children: [
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onVerticalDragStart: (_) => downwardDrag = 0,
                                  onVerticalDragUpdate: (d) =>
                                      trackCloseDrag(d.delta.dy),
                                  child: SizedBox(
                                    height: 52,
                                    child: Stack(
                                      children: [
                                        Align(
                                          alignment: const Alignment(0, -.45),
                                          child: handle,
                                        ),
                                        Positioned(
                                          right: 12,
                                          top: 2,
                                          child: IconButton(
                                            style: ButtonStyle(
                                              overlayColor:
                                                  WidgetStateProperty.resolveWith(
                                                    (states) =>
                                                        states.contains(
                                                              WidgetState
                                                                  .hovered,
                                                            ) &&
                                                            !states.contains(
                                                              WidgetState
                                                                  .focused,
                                                            ) &&
                                                            !states.contains(
                                                              WidgetState
                                                                  .pressed,
                                                            )
                                                        ? Colors.transparent
                                                        : null,
                                                  ),
                                            ),
                                            onPressed: busy ? null : closeSheet,
                                            icon: Image.asset(
                                              'assets/login-close.png',
                                              semanticLabel: 'Close sign in',
                                              width: 24,
                                              height: 24,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child:
                                      NotificationListener<ScrollNotification>(
                                        onNotification: (event) {
                                          if (event
                                                  is ScrollStartNotification ||
                                              event
                                                  is ScrollUpdateNotification) {
                                            downwardDrag = 0;
                                          }
                                          if (event is OverscrollNotification &&
                                              event.dragDetails != null &&
                                              event.overscroll < 0) {
                                            trackCloseDrag(-event.overscroll);
                                          }
                                          return false;
                                        },
                                        child: _formContent(),
                                      ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                if (busy)
                  const Positioned.fill(
                    child: Stack(
                      children: [
                        ModalBarrier(
                          dismissible: false,
                          color: Color(0x5530313A),
                        ),
                        Center(child: ClinicLoader()),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );

  Widget _formContent() => AutofillGroup(
    child: Form(
      key: form,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (register)
              RegisterPage(
                first: first,
                last: last,
                email: email,
                password: password,
                confirmPassword: confirmPassword,
                field: _field,
              )
            else
              LoginPage(
                email: email,
                password: password,
                field: _field,
                onReset: busy ? null : sendPasswordReset,
              ),
            SizedBox(height: register ? 24 : 8),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: busy ? null : submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF5B3F91),
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  register ? 'Sign up' : 'Log In',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      register = !register;
                      showPassword = false;
                      ScaffoldMessenger.of(context).removeCurrentSnackBar();
                      form.currentState?.reset();
                    }),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                foregroundColor: const Color(0xFF493077),
                side: const BorderSide(color: Color(0xFF68508F)),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: Text(
                register ? 'Back to sign in' : 'Sign up',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (supportsGoogleAuth) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: busy ? null : continueWithGoogle,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1F1F1F),
                  side: const BorderSide(color: Color(0xFF747775)),
                ),
                icon: Image.asset(
                  'assets/google-g.png',
                  width: 20,
                  height: 20,
                  excludeFromSemantics: true,
                ),
                label: const Text('Continue with Google'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
