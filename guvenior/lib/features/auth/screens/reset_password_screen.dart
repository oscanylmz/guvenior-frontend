import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../services/auth_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? email;
  final String? token;

  const ResetPasswordScreen({
    super.key,
    required this.email,
    required this.token,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with TickerProviderStateMixin {
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  late AnimationController _bgController;
  late AnimationController _cardController;
  late Animation<double> _cardAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email ?? '');

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);

    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _cardAnimation = CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOutCubic,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeIn,
    );

    Future.delayed(const Duration(milliseconds: 200), () {
      _cardController.forward();
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _cardController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final token = widget.token;
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (token == null || token.isEmpty || email.isEmpty) {
      _showError('Bağlantı geçersiz. Lütfen e-postadaki linki yeniden açın.');
      return;
    }
    if (password.isEmpty || confirm.isEmpty) {
      _showError('Lütfen yeni şifreyi girin.');
      return;
    }
    if (password != confirm) {
      _showError('Şifreler aynı değil.');
      return;
    }
    if (password.length < 6) {
      _showError('Şifre en az 6 karakter olmalı.');
      return;
    }

    setState(() => _isLoading = true);
    final error = await AuthService.resetPassword(
      email: email,
      token: token,
      password: password,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Şifreniz güncellendi. Giriş yapabilirsiniz.'),
          backgroundColor: const Color(0xFF00E5A0),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      return;
    }

    _showError(error);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.moodStressed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasToken = (widget.token ?? '').isNotEmpty;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, child) {
          final t = _bgController.value;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1 + t * 0.6, -1),
                end: Alignment(1 - t * 0.6, 1),
                colors: [
                  Color.lerp(
                    const Color(0xFF0D1117),
                    const Color(0xFF1A1225),
                    t,
                  )!,
                  Color.lerp(
                    const Color(0xFF111827),
                    const Color(0xFF0D1A2E),
                    t,
                  )!,
                  Color.lerp(
                    const Color(0xFF0D1117),
                    const Color(0xFF1A1225),
                    t,
                  )!,
                ],
              ),
            ),
            child: child,
          );
        },
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -80,
              child: AnimatedBuilder(
                animation: _bgController,
                builder: (context, _) => Transform.scale(
                  scale: 1 + _bgController.value * 0.2,
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.peach.withOpacity(0.18),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 80,
              left: -80,
              child: AnimatedBuilder(
                animation: _bgController,
                builder: (context, _) => Transform.scale(
                  scale: 1 + (1 - _bgController.value) * 0.2,
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.sky.withOpacity(0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 70),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                AppColors.peachSkyGradient.createShader(bounds),
                            child: Text(
                              'Şifre Sıfırlama',
                              style: GoogleFonts.inter(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            hasToken
                                ? 'Yeni şifreni belirle'
                                : 'Bağlantı doğrulanamadı',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 13,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    AnimatedBuilder(
                      animation: _cardAnimation,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(0, 80 * (1 - _cardAnimation.value)),
                        child: Opacity(
                          opacity: _cardAnimation.value,
                          child: child,
                        ),
                      ),
                      child: GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildField(
                              controller: _emailController,
                              label: 'E-posta',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              enabled: widget.email == null,
                            ),
                            const SizedBox(height: 16),
                            _buildField(
                              controller: _passwordController,
                              label: 'Yeni şifre',
                              icon: Icons.lock_outline,
                              obscure: _obscure1,
                              enabled: hasToken,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscure1
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.white38,
                                  size: 20,
                                ),
                                onPressed: hasToken
                                    ? () => setState(() => _obscure1 = !_obscure1)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildField(
                              controller: _confirmController,
                              label: 'Yeni şifre (tekrar)',
                              icon: Icons.lock_outline,
                              obscure: _obscure2,
                              enabled: hasToken,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscure2
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.white38,
                                  size: 20,
                                ),
                                onPressed: hasToken
                                    ? () => setState(() => _obscure2 = !_obscure2)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 22),
                            GradientButton(
                              text: 'Şifreyi Güncelle',
                              onPressed: hasToken ? _submit : () {},
                              gradient: AppColors.peachSkyGradient,
                              isLoading: _isLoading,
                            ),
                            const SizedBox(height: 10),
                            Center(
                              child: TextButton(
                                onPressed: () => Navigator.of(context)
                                    .pushNamedAndRemoveUntil('/', (r) => false),
                                child: Text(
                                  'Giriş sayfasına dön',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.45),
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withOpacity(enabled ? 0.06 : 0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.peach, width: 1.5),
        ),
      ),
    );
  }
}

