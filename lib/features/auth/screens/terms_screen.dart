import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import '../../../core/app_colors.dart';
import '../../../core/widgets/epic_logo.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/services/api_service.dart';
class TermsScreen extends StatefulWidget {
  final String content;
  final Map<String, dynamic>? formData;
  const TermsScreen({
    super.key,
    required this.content,
    this.formData,
  });
  @override
  State<TermsScreen> createState() => _TermsScreenState();
}
class _TermsScreenState extends State<TermsScreen> {
  late final SignatureController _signatureController;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    _signatureController = SignatureController(
      penStrokeWidth: 2,
      penColor: AppColors.textDark,
    );
  }
  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }
  Future<void> _agree() async {
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please draw your signature before agreeing'),
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final Uint8List? bytes = await _signatureController.toPngBytes();
      if (bytes == null) throw Exception('Failed to capture signature');
      final base64Sig = 'data:image/png;base64,${base64Encode(bytes)}';
      if (widget.formData != null) {
        final body = Map<String, dynamic>.from(widget.formData!);
        body['signature'] = base64Sig;
        await ApiService.post(
          'v2/profile/setup/send-otp',
          body,
          withAuth: true,
        );
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      } else {
        if (!mounted) return;
        Navigator.pop(context, base64Sig);
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(child: Center(child: EpicLogo())),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Terms of Use',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.content.isNotEmpty
                          ? widget.content
                          : 'No terms content available.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textGrey,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Your Signature',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.inputBorder),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          children: [
                            Signature(
                              controller: _signatureController,
                              height: 160,
                              width: double.infinity,
                              backgroundColor: AppColors.white,
                            ),
                            if (_signatureController.isEmpty)
                              const Positioned.fill(
                                child: Center(
                                  child: Text(
                                    'Draw to sign here.',
                                    style: TextStyle(
                                      color: AppColors.textGrey,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          _signatureController.clear();
                          setState(() {});
                        },
                        child: const Text(
                          'Clear',
                          style: TextStyle(color: AppColors.textGrey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    PrimaryButton(
                      label: 'Agree',
                      onPressed: _agree,
                      isLoading: _loading,
                    ),
                    const SizedBox(height: 32),
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
