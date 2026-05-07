import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/common_widgets.dart';

const _kPrimary = Color(0xFF1B3A27);
const _kAccent = Color(0xFF2E7D52);
const _kBg = Color(0xFFF4F6F8);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController(text: 'arun.kumar@example.com');
  final _passCtrl = TextEditingController(text: 'password123');
  bool _obscure = true;
  bool _loading = false;
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final res = await context
        .read<AuthService>()
        .login(_emailCtrl.text.trim(), _passCtrl.text.trim());
    if (mounted && res['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Login failed'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = constraints.maxWidth >= 860;
      return Scaffold(
        backgroundColor: _kBg,
        body: isDesktop ? _buildDesktop() : _buildMobile(),
      );
    });
  }

  // ── Desktop: split panel ──────────────────────────────────────────────────

  Widget _buildDesktop() {
    return Row(children: [
      const Expanded(flex: 5, child: _BrandPanel()),
      Expanded(
        flex: 4,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: _buildFormCard(),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  // ── Mobile: green gradient + card ─────────────────────────────────────────

  Widget _buildMobile() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kPrimary, Color(0xFF2A5940)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              FadeTransition(
                opacity: _fade,
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.grid_view_rounded,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 12),
                  const Text('MMS',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2)),
                  const SizedBox(height: 4),
                  const Text('Material Management System',
                      style: TextStyle(color: Colors.white60, fontSize: 13)),
                ]),
              ),
              const SizedBox(height: 28),
              FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                    position: _slide, child: _buildFormCard()),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Shared form card ──────────────────────────────────────────────────────

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.09),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card header
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _kAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.grid_view_rounded, color: _kAccent, size: 22),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MMS',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E))),
                  Text('Sign in to your account',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ]),

            const SizedBox(height: 30),

            _fieldLabel('Email'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontSize: 14),
              decoration: _inputDeco(
                hint: 'Enter your email',
                icon: Icons.email_outlined,
              ),
              validator: (v) => v!.isEmpty ? 'Email is required' : null,
            ),

            const SizedBox(height: 18),

            _fieldLabel('Password'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passCtrl,
              obscureText: _obscure,
              style: const TextStyle(fontSize: 14),
              decoration: _inputDeco(
                hint: 'Enter your password',
                icon: Icons.lock_outline,
                suffix: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey.shade400,
                    size: 18,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => v!.isEmpty ? 'Password is required' : null,
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const ButtonLoader()
                    : const Text('Sign In',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),

            const SizedBox(height: 20),

            Center(
              child: Text(
                'v1.0.0',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A2E)));

  InputDecoration _inputDeco({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 18),
      suffixIcon: suffix,
      filled: true,
      fillColor: _kBg,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kAccent, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 1)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 1.5)),
    );
  }
}

// ── Brand panel (desktop left side) ──────────────────────────────────────────

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kPrimary, Color(0xFF2A5940)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(children: [
        // Decorative circles
        const Positioned(
          top: -70,
          right: -70,
          child: _Circle(280, 0.04),
        ),
        const Positioned(
          bottom: 50,
          left: -90,
          child: _Circle(330, 0.04),
        ),
        const Positioned(
          bottom: -50,
          right: 60,
          child: _Circle(190, 0.05),
        ),

        // Content
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand mark
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.grid_view_rounded,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  const Text('MMS',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5)),
                ]),

                const Spacer(),

                // Headline
                const Text('Manage materials,\nsmarter.',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        height: 1.25)),
                const SizedBox(height: 14),
                const Text(
                  'From godown to dispatch — every unit tracked,\nevery movement recorded.',
                  style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.6),
                ),

                const SizedBox(height: 40),

                // Feature tiles
                const _FeatureTile(
                  icon: Icons.inventory_2_outlined,
                  title: 'Inventory Control',
                  subtitle: 'Real-time stock tracking across all locations',
                ),
                const SizedBox(height: 18),
                const _FeatureTile(
                  icon: Icons.location_on_outlined,
                  title: 'Multi-Location',
                  subtitle: 'Centralized godown & warehouse management',
                ),
                const SizedBox(height: 18),
                const _FeatureTile(
                  icon: Icons.bar_chart_outlined,
                  title: 'Analytics & Reports',
                  subtitle: 'Live insights into inward, outward & expenses',
                ),

                const Spacer(),

                // Trust badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12), width: 1),
                  ),
                  child: const Row(children: [
                    Icon(Icons.verified_outlined,
                        color: Color(0xFF81C784), size: 15),
                    SizedBox(width: 8),
                    Text('Secure · Role-based access · Enterprise ready',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class _Circle extends StatelessWidget {
  final double size;
  final double opacity;
  const _Circle(this.size, this.opacity);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _FeatureTile(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF81C784), size: 18),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(subtitle,
                style:
                    const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    ]);
  }
}
