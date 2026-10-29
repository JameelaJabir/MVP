import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/services/api_service.dart';
class LoginOptionScreen extends StatefulWidget {
  const LoginOptionScreen({super.key});
  @override
  State<LoginOptionScreen> createState() => _LoginOptionScreenState();
}
class _LoginOptionScreenState extends State<LoginOptionScreen> {
  bool _loadingGoogle = false;
  Future<void> _handleGoogleLogin() async {
    setState(() => _loadingGoogle = true);
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email']);
      final account = await googleSignIn.signIn();
      if (account == null) return;
      final auth = await account.authentication;
      final res = await ApiService.post('public/auth/social/google', {
        'auth_code': auth.accessToken,
      });
      await _handlePostLogin(res);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
    }
  }
  Future<void> _handlePostLogin(Map<String, dynamic> res) async {
    final token =
        res['data']?['token']?.toString() ?? res['token']?.toString();
    if (token != null) await StorageService.saveToken(token);
    final autoRes =
        await ApiService.get('mob_app/auth/autoLogin', withAuth: true);
    final user = autoRes['data'] ?? autoRes['user'] ?? autoRes;
    final isNew = user['is_new_user'] == true;
    if (!mounted) return;
    if (isNew) {
      Navigator.pushNamed(context, '/login-info');
    } else {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    }
  }
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/login_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0A1F15), Color(0xFF1A3A28)],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.35)),
          ),
          SafeArea(
            child: Column(
              children: [
                const Expanded(child: SizedBox()),
                _BottomSheet(
                  onGoogle: _handleGoogleLogin,
                  loadingGoogle: _loadingGoogle,
                  onRequestCode: () => Navigator.pushNamed(context, '/login'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class _BottomSheet extends StatelessWidget {
  final VoidCallback onGoogle;
  final VoidCallback onRequestCode;
  final bool loadingGoogle;
  const _BottomSheet({
    required this.onGoogle,
    required this.onRequestCode,
    required this.loadingGoogle,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
      decoration: const BoxDecoration(
        color: Color(0xFF0D2118),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            label: 'Continue with Apple',
            backgroundColor: AppColors.white,
            textColor: AppColors.textDark,
            onPressed: () {},
            leading: const Icon(Icons.apple, size: 22, color: Colors.black),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Continue with Google',
            isLoading: loadingGoogle,
            onPressed: onGoogle,
            leading: _GoogleIcon(),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Continue with phone',
            onPressed: () {},
            leading:
                const Icon(Icons.phone, size: 20, color: AppColors.white),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Request Code',
            onPressed: onRequestCode,
            contentRightPadding: 30,
            leading: const SizedBox(
              width: 22,
              height: 22,
              child: Icon(Icons.key, size: 20, color: AppColors.white),
            ),
          ),
        ],
      ),
    );
  }
}
class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/google_logo.svg',
      width: 22,
      height: 22,
    );
  }
}
