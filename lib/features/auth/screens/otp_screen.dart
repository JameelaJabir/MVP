import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/app_colors.dart';
import '../../../core/widgets/epic_logo.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/services/api_service.dart';
import 'login_info_screen.dart';
class OtpScreen extends StatefulWidget {
  final String email;
  final String? phone;
  final String? country;
  final int? countryId;
  final bool isPhoneVerification;
  const OtpScreen({
    super.key,
    required this.email,
    this.phone,
    this.country,
    this.countryId,
    this.isPhoneVerification = false,
  });
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}
class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  bool _loading = false;
  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }
  String get _otp => _controllers.map((c) => c.text).join();
  Future<void> _verify() async {
    if (_otp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 4-digit code')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      if (widget.isPhoneVerification) {
        await ApiService.post(
          'v2/profile/setup/verify-otp',
          {
            'phone': widget.phone,
            'country': widget.country,
            'country_id': widget.countryId,
            'otp': _otp,
          },
          withAuth: true,
        );
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      } else {
        final res = await ApiService.post('public/auth/verifyEmailOTPV1', {
          'email': widget.email,
          'otp': _otp,
        });
        final token =
            res['data']?['token']?.toString() ?? res['token']?.toString();
        if (token != null) await StorageService.saveToken(token);
        final autoRes =
            await ApiService.get('mob_app/auth/autoLogin', withAuth: true);
        final user = autoRes['data'] ?? autoRes['user'] ?? autoRes;
        final isNew = user['is_new_user'] == true;
        if (!mounted) return;
        if (isNew) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginInfoScreen()),
            (_) => false,
          );
        } else {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  Future<void> _resend() async {
    try {
      await ApiService.post('public/auth/loginWithEmail', {
        'email': widget.email,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code resent')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    const Center(child: EpicLogo()),
                    const SizedBox(height: 48),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textGrey,
                        ),
                        children: [
                          const TextSpan(text: 'Enter the code we sent to '),
                          TextSpan(
                            text: widget.isPhoneVerification
                                ? '${widget.country ?? ''} ${widget.phone ?? ''}'
                                : widget.email,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        4,
                        (i) => _OtpBox(
                          controller: _controllers[i],
                          focusNode: _focusNodes[i],
                          onChanged: (v) {
                            if (v.isNotEmpty && i < 3) {
                              _focusNodes[i + 1].requestFocus();
                            }
                          },
                          onBackspace: () {
                            if (_controllers[i].text.isEmpty && i > 0) {
                              _focusNodes[i - 1].requestFocus();
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    PrimaryButton(
                      label: 'Continue',
                      onPressed: _verify,
                      isLoading: _loading,
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: GestureDetector(
                        onTap: _resend,
                        child: const Text(
                          "Didn't receive a code? Resend",
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onBackspace,
  });
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      height: 68,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              controller.text.isEmpty) {
            onBackspace();
          }
        },
        child: TextFormField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
