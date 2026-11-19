import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nabila_food/bahan_baku_screen.dart';
import 'package:nabila_food/data/app_repository.dart';
import 'package:nabila_food/data/supabase_config.dart';
import 'package:nabila_food/produk_screen.dart';
import 'package:nabila_food/produksi_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _green = Color(0xFF07551C);
const _deepGreen = Color(0xFF00410F);
const _pageColor = Color(0xFFF8F9F3);
const _amber = Color(0xFFFFB900);
const _ink = Color(0xFF172117);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.projectUrl,
    publishableKey: SupabaseConfig.publishableKey,
  );
  runApp(const NabilaFoodApp());
}

class NabilaFoodApp extends StatelessWidget {
  const NabilaFoodApp({super.key, this.repository});

  final AppRepository? repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nabila Food',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _pageColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _green,
          primary: _green,
          surface: Colors.white,
        ),
        fontFamily: 'Roboto',
      ),
      home: LoginScreen(repository: repository ?? SupabaseAppRepository()),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.repository});

  final AppRepository repository;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSigningIn = false;
  String? _signInError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSigningIn = true;
      _signInError = null;
    });
    try {
      await widget.repository.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSigningIn = false;
        _signInError = error.message;
      });
      return;
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSigningIn = false;
        _signInError = 'Gagal masuk: $error';
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => DashboardScreen(repository: widget.repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AspectRatio(
                        aspectRatio: 441 / 355,
                        child: Image.asset(
                          'assets/hero.png',
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 17, 18, 36),
                        child: Column(
                          children: [
                            Text(
                              'Selamat Datang!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _ink,
                                fontSize: constraints.maxWidth < 360 ? 27 : 31,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Masuk untuk mengelola operasional toko Nabila Food & '
                              'produksi Nabila Food harian',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF4C554A),
                                fontSize: 16,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 34),
                            Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'Email',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  _LoginInput(
                                    controller: _emailController,
                                    icon: Icons.mail_outline,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (value) {
                                      final email = value?.trim() ?? '';
                                      if (email.isEmpty ||
                                          !email.contains('@') ||
                                          !email.contains('.')) {
                                        return 'Masukkan alamat email yang valid';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      const Text(
                                        'Kata Sandi',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const Spacer(),
                                      TextButton(
                                        onPressed: () {
                                          ScaffoldMessenger.of(context)
                                            ..hideCurrentSnackBar()
                                            ..showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Fitur lupa sandi belum terhubung.',
                                                ),
                                              ),
                                            );
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor: _green,
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text(
                                          'Lupa Sandi?',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 7),
                                  _LoginInput(
                                    controller: _passwordController,
                                    icon: Icons.lock_outline,
                                    obscureText: _obscurePassword,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Kata sandi wajib diisi';
                                      }
                                      return null;
                                    },
                                    suffix: IconButton(
                                      tooltip: _obscurePassword
                                          ? 'Tampilkan kata sandi'
                                          : 'Sembunyikan kata sandi',
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: const Color(0xFF778174),
                                        size: 21,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  if (_signInError != null) ...[
                                    Text(
                                      _signInError!,
                                      style: const TextStyle(
                                        color: Color(0xFFB3261E),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  SizedBox(
                                    height: 60,
                                    child: FilledButton(
                                      onPressed: _isSigningIn ? null : _signIn,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: _amber,
                                        foregroundColor: const Color(
                                          0xFF664600,
                                        ),
                                        elevation: 2,
                                        shape: const StadiumBorder(),
                                        textStyle: const TextStyle(
                                          fontSize: 21,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          if (_isSigningIn)
                                            const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          else ...[
                                            const Flexible(
                                              child: Text(
                                                'Masuk Sekarang',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(
                                              Icons.arrow_forward,
                                              size: 21,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginInput extends StatelessWidget {
  const _LoginInput({
    required this.controller,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.suffix,
  });

  final TextEditingController controller;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: _green, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: Color(0xFFD8DFD4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: Color(0xFF668B63), width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFB3261E)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xFFB3261E), width: 1.4),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.repository});

  final AppRepository repository;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _scrollController = ScrollController();
  final _dashboardKey = GlobalKey();
  final _ingredientsKey = GlobalKey();
  final _productionKey = GlobalKey();
  int _selectedTab = 0;
  int _materialsRefreshVersion = 0;
  int _productsRefreshVersion = 0;
  String _adminName = 'Nurvi Fuad';
  Uint8List? _adminPhoto;
  String? _profileError;
  int _materialCount = 0;
  int _productCount = 0;
  int _productionCount = 0;
  int _activityLogsRequestVersion = 0;
  List<Map<String, dynamic>> _activityLogs = [];
  List<_ActivityData> _productionActivities = [];

  @override
  void initState() {
    super.initState();
    _loadAdminProfile();
    _loadDashboardCounts();
    _loadActivityLogs();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    setState(() => _selectedTab = index);
    if (index == 0) _loadDashboardCounts();
    if (index == 4) _onActivityChanged();
    if (index == 1 || index == 2 || index == 3 || index == 4) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetContext = _dashboardKey.currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: index == 0 ? 0 : 0.05,
        );
      }
    });
  }

  Future<void> _loadDashboardCounts() async {
    try {
      final results = await Future.wait([
        widget.repository.getMaterials(),
        widget.repository.getProducts(),
        widget.repository.getProductionBatches(),
      ]);
      if (!mounted) return;
      setState(() {
        final productionBatches = results[2];
        _materialCount = results[0].length;
        _productCount = results[1].length;
        _productionCount = productionBatches.fold<int>(
          0,
          (total, batch) =>
              total + ((batch['batch_count'] as num?)?.toInt() ?? 1),
        );
        _productionActivities = _buildProductionActivities(productionBatches);
      });
    } catch (error) {
      if (mounted) _showMessage('Ringkasan dashboard gagal dimuat: $error');
    }
  }

  List<_ActivityData> _buildProductionActivities(
    List<Map<String, dynamic>> batches,
  ) {
    return batches.reversed.take(4).map((batch) {
      final batchCount = (batch['batch_count'] as num?)?.toInt() ?? 1;
      final produced = (batch['produced'] as num?)?.toInt() ?? 0;
      final date = DateTime.tryParse(batch['produced_on'] as String? ?? '');
      final dateLabel = date == null
          ? ''
          : '${date.day.toString().padLeft(2, '0')}-'
                '${date.month.toString().padLeft(2, '0')}-'
                '${date.year}';
      return _ActivityData(
        title: batch['name'] as String? ?? 'Produksi',
        detail:
            '${batch['station'] as String? ?? 'Lokasi tidak ditentukan'} • '
            '$batchCount batch • $produced pcs',
        time: dateLabel,
        done: true,
      );
    }).toList();
  }

  Future<void> _loadActivityLogs() async {
    final requestVersion = ++_activityLogsRequestVersion;
    try {
      final logs = await widget.repository.getActivityLogs();
      if (!mounted || requestVersion != _activityLogsRequestVersion) return;
      setState(() => _activityLogs = logs);
    } catch (error) {
      if (mounted && requestVersion == _activityLogsRequestVersion) {
        _showMessage('Log aktivitas gagal dimuat: $error');
      }
    }
  }

  void _onActivityChanged() {
    unawaited(_loadActivityLogs());
  }

  Future<void> _clearActivityLogs() async {
    ++_activityLogsRequestVersion;
    try {
      await widget.repository.clearActivityLogs();
      if (!mounted) return;
      setState(() => _activityLogs = []);
      _showMessage('Semua log aktivitas berhasil dihapus.');
    } catch (error) {
      if (mounted) _showMessage('Log aktivitas gagal dihapus: $error');
    }
  }

  Future<void> _signOut() async {
    try {
      await widget.repository.signOut();
    } catch (error) {
      if (mounted) _showMessage('Gagal keluar: $error');
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(repository: widget.repository),
      ),
      (_) => false,
    );
  }

  void _onProductionStockChanged() {
    setState(() {
      _materialsRefreshVersion++;
      _productsRefreshVersion++;
    });
    unawaited(_loadDashboardCounts());
    _onActivityChanged();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editAdminProfile() async {
    final profile = await showDialog<_AdminProfileUpdate>(
      context: context,
      builder: (_) =>
          _EditAdminProfileDialog(name: _adminName, photo: _adminPhoto),
    );
    if (profile == null || !mounted) return;
    try {
      await widget.repository.saveAdminProfile(
        name: profile.name,
        photoBase64: profile.photo == null
            ? null
            : base64Encode(profile.photo!),
      );
      _onActivityChanged();
      if (!mounted) return;
      setState(() {
        _adminName = profile.name;
        _adminPhoto = profile.photo;
      });
    } catch (error) {
      if (!mounted) return;
      _showMessage('Profil tidak dapat disimpan: $error');
    }
  }

  Future<void> _loadAdminProfile() async {
    try {
      final profile = await widget.repository.getAdminProfile();
      if (profile == null || !mounted) return;
      final photoBase64 = profile['photo_base64'] as String?;
      setState(() {
        _adminName = profile['name'] as String? ?? _adminName;
        _adminPhoto = photoBase64 == null ? null : base64Decode(photoBase64);
        _profileError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _profileError = 'Profil admin gagal dimuat: $error');
      _showMessage(_profileError!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageColor,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                _DashboardHeader(
                  adminName: _adminName,
                  adminPhoto: _adminPhoto,
                  onNotificationsTap: () {
                    _showMessage('Tidak ada notifikasi baru.');
                  },
                ),
                Expanded(
                  child: IndexedStack(
                    index: _selectedTab == 1
                        ? 1
                        : _selectedTab == 2
                        ? 2
                        : _selectedTab == 3
                        ? 3
                        : _selectedTab == 4
                        ? 4
                        : 0,
                    children: [
                      SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 13, 12, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            KeyedSubtree(
                              key: _dashboardKey,
                              child: _GreetingRow(adminName: _adminName),
                            ),
                            const SizedBox(height: 10),
                            const _TargetCard(),
                            const SizedBox(height: 14),
                            _SectionHeading(
                              title: 'Aksi Cepat',
                              trailing: 'Semua Aksi',
                              onTap: () => _selectTab(4),
                            ),
                            const SizedBox(height: 6),
                            _QuickActions(
                              onProductionTap: () => _selectTab(3),
                              onIngredientsTap: () => _selectTab(1),
                              onProductsTap: () => _selectTab(2),
                            ),
                            const SizedBox(height: 14),
                            const _SectionHeading(title: 'Ringkasan Hari Ini'),
                            const SizedBox(height: 6),
                            _MetricGrid(
                              ingredientsKey: _ingredientsKey,
                              productionKey: _productionKey,
                              materialCount: _materialCount,
                              productCount: _productCount,
                              productionCount: _productionCount,
                            ),
                            const SizedBox(height: 14),
                            _SectionHeading(
                              title: 'Aktivitas Produksi & Pengemasan',
                              trailing: 'Realtime',
                              trailingColor: const Color(0xFF677164),
                            ),
                            const SizedBox(height: 6),
                            _ActivityList(items: _productionActivities),
                          ],
                        ),
                      ),
                      BahanBakuScreen(
                        repository: widget.repository,
                        refreshVersion: _materialsRefreshVersion,
                      ),
                      ProdukScreen(
                        repository: widget.repository,
                        onStartBatch: () => _selectTab(3),
                        refreshVersion: _productsRefreshVersion,
                      ),
                      ProduksiScreen(
                        repository: widget.repository,
                        onStockChanged: _onProductionStockChanged,
                      ),
                      ActivityScreen(
                        adminName: _adminName,
                        adminPhoto: _adminPhoto,
                        onEditAdmin: _editAdminProfile,
                        activityLogs: _activityLogs,
                        onClearLogs: _clearActivityLogs,
                        onLogout: _signOut,
                      ),
                    ],
                  ),
                ),
                _BottomNavigation(
                  selectedIndex: _selectedTab,
                  onSelected: _selectTab,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({
    super.key,
    required this.adminName,
    required this.adminPhoto,
    required this.onEditAdmin,
    required this.activityLogs,
    required this.onClearLogs,
    required this.onLogout,
  });

  final String adminName;
  final Uint8List? adminPhoto;
  final VoidCallback onEditAdmin;
  final List<Map<String, dynamic>> activityLogs;
  final Future<void> Function() onClearLogs;
  final Future<void> Function() onLogout;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  static const _filters = ['Semua', 'INSERT', 'UPDATE', 'DELETE'];
  String _selectedFilter = 'Semua';

  @override
  Widget build(BuildContext context) {
    final activities = widget.activityLogs
        .where(
          (log) =>
              _selectedFilter == 'Semua' || log['action'] == _selectedFilter,
        )
        .map(_ActivityLog.fromMap)
        .toList();

    return Scaffold(
      backgroundColor: _pageColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 20),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: widget.onEditAdmin,
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Color(0xFFE9EDE6)),
                            ),
                            child: Row(
                              children: [
                                _AdminAvatar(
                                  name: widget.adminName,
                                  photo: widget.adminPhoto,
                                  size: 54,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.adminName,
                                        style: TextStyle(
                                          fontSize: 21,
                                          fontWeight: FontWeight.w700,
                                          color: _ink,
                                        ),
                                      ),
                                      Text(
                                        'Owner of Nabila Food Indonesia',
                                        style: TextStyle(
                                          color: Color(0xFF5B655C),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: widget.onEditAdmin,
                                  tooltip: 'Edit profil admin',
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    color: _green,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Menu Manajemen',
                              style: TextStyle(
                                color: _ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F6F1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                '5 Layanan',
                                style: TextStyle(
                                  color: Color(0xFF5B665B),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Color(0xFFE7EAE4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Log Aktivitas Terkini',
                                      style: TextStyle(
                                        color: _ink,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const Text(
                                    'Terbaru',
                                    style: TextStyle(
                                      color: Color(0xFF5C665D),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final filter in _filters)
                                    ChoiceChip(
                                      label: Text(filter),
                                      selected: _selectedFilter == filter,
                                      onSelected: (_) => setState(
                                        () => _selectedFilter = filter,
                                      ),
                                      selectedColor: const Color(0xFF0E7042),
                                      backgroundColor: const Color(0xFFF0F2EE),
                                      labelStyle: TextStyle(
                                        color: _selectedFilter == filter
                                            ? Colors.white
                                            : const Color(0xFF4E574D),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (activities.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                  ),
                                  child: Center(
                                    child: Text(
                                      _selectedFilter == 'Semua'
                                          ? 'Belum ada aktivitas.'
                                          : 'Belum ada aktivitas $_selectedFilter.',
                                      style: TextStyle(
                                        color: Color(0xFF5B665C),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                for (
                                  var index = 0;
                                  index < activities.length;
                                  index++
                                )
                                  _ActivityLogRow(
                                    log: activities[index],
                                    showDivider: index > 0,
                                  ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                height: 40,
                                child: OutlinedButton(
                                  onPressed: widget.onClearLogs,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _green,
                                    side: const BorderSide(
                                      color: Color(0xFF7DA57B),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    'Segarkan Log Aktivitas',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            onPressed: widget.onLogout,
                            style: FilledButton.styleFrom(
                              backgroundColor: _amber,
                              foregroundColor: const Color(0xFF3B2D00),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.logout, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Keluar (Logout)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
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
        ),
      ),
    );
  }
}

class _AdminAvatar extends StatelessWidget {
  const _AdminAvatar({
    required this.name,
    required this.photo,
    required this.size,
  });

  final String name;
  final Uint8List? photo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: Color(0xFFA7C19A),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: photo == null
          ? Text(
              initials.isEmpty ? 'A' : initials,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.34,
              ),
            )
          : Image.memory(
              photo!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Text(
                initials.isEmpty ? 'A' : initials,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: size * 0.34,
                ),
              ),
            ),
    );
  }
}

class _AdminProfileUpdate {
  const _AdminProfileUpdate({required this.name, required this.photo});

  final String name;
  final Uint8List? photo;
}

class _EditAdminProfileDialog extends StatefulWidget {
  const _EditAdminProfileDialog({required this.name, required this.photo});

  final String name;
  final Uint8List? photo;

  @override
  State<_EditAdminProfileDialog> createState() =>
      _EditAdminProfileDialogState();
}

class _EditAdminProfileDialogState extends State<_EditAdminProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  Uint8List? _photo;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _photo = widget.photo;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectPhoto() async {
    try {
      final selected = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (selected == null || !mounted) return;
      final bytes = await selected.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 5 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ukuran foto maksimal 5 MB.')),
        );
        return;
      }
      setState(() => _photo = bytes);
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Foto tidak dapat dipilih: ${error.message ?? error.code}',
          ),
        ),
      );
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _AdminProfileUpdate(name: _nameController.text.trim(), photo: _photo),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Profil Admin'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AdminAvatar(
                  name: _nameController.text,
                  photo: _photo,
                  size: 84,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _selectPhoto,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Ganti Foto'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Nama Admin',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.trim().isNotEmpty == true
                      ? null
                      : 'Nama admin wajib diisi',
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(onPressed: _save, child: const Text('Simpan')),
      ],
    );
  }
}

class _ActivityLog {
  const _ActivityLog({
    required this.type,
    required this.label,
    required this.detail,
    required this.time,
    required this.color,
  });

  final String type;
  final String label;
  final String detail;
  final String time;
  final Color color;

  factory _ActivityLog.fromMap(Map<String, dynamic> row) {
    final action = (row['action'] as String? ?? '').toUpperCase();
    final tableName = row['table_name'] as String? ?? '';
    final entity = switch (tableName) {
      'materials' => 'Bahan baku',
      'products' => 'Produk',
      'production_batches' => 'Produksi',
      'profiles' => 'Profil admin',
      _ => tableName,
    };
    final verb = switch (action) {
      'INSERT' => 'ditambahkan',
      'UPDATE' => 'diperbarui',
      'DELETE' => 'dihapus',
      _ => 'diubah',
    };
    final recordName = row['record_name'] as String?;
    final recordId = row['record_id']?.toString();
    return _ActivityLog(
      type: action,
      label: '$entity $verb',
      detail: recordName?.isNotEmpty == true
          ? recordName!
          : '$entity${recordId == null ? '' : ' • ID $recordId'}',
      time: _formatActivityTime(row['created_at']?.toString()),
      color: switch (action) {
        'INSERT' => const Color(0xFF2E8B57),
        'UPDATE' => const Color(0xFFE0A100),
        'DELETE' => const Color(0xFFC84545),
        _ => const Color(0xFF5B665C),
      },
    );
  }
}

String _formatActivityTime(String? value) {
  final date = value == null ? null : DateTime.tryParse(value)?.toLocal();
  if (date == null) return '-';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/${date.year} $hour:$minute';
}

class _ActivityLogRow extends StatelessWidget {
  const _ActivityLogRow({required this.log, required this.showDivider});

  final _ActivityLog log;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(top: BorderSide(color: Color(0xFFF1F2EE)))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: log.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F1EA),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        log.type,
                        style: const TextStyle(
                          color: _green,
                          fontWeight: FontWeight.w800,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        log.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      log.time,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Color(0xFF5B665C),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  log.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF5B665C),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.adminName,
    required this.adminPhoto,
    required this.onNotificationsTap,
  });

  final String adminName;
  final Uint8List? adminPhoto;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFBF6),
        border: Border(bottom: BorderSide(color: Color(0xFFECEEE7))),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/nabila-food-logo.png',
            width: 34,
            height: 34,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.eco, color: _green, size: 26),
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nabila Food',
                  style: TextStyle(
                    color: _green,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                Text(
                  'Nabila Management System',
                  style: TextStyle(color: Color(0xFF5E665D), fontSize: 8),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onNotificationsTap,
            tooltip: 'Notifikasi',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.notifications_none, size: 21),
          ),
          const SizedBox(width: 6),
          _AdminAvatar(name: adminName, photo: adminPhoto, size: 30),
        ],
      ),
    );
  }
}

class _GreetingRow extends StatelessWidget {
  const _GreetingRow({required this.adminName});

  final String adminName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Halo, $adminName! 👋',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F5EE),
            border: Border.all(color: const Color(0xFFE4E8DE)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Row(
            children: [
              Icon(Icons.calendar_month_outlined, size: 12, color: _green),
              SizedBox(width: 4),
              Text(
                'Hari Ini, 24 Mei',
                style: TextStyle(
                  color: _green,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TargetCard extends StatelessWidget {
  const _TargetCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [_green, _deepGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: _amber,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              '♟  PRO TARGET',
              style: TextStyle(
                color: Color(0xFF4D3900),
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Nabila Food Management!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Pantau aktivitas dapur dan progres produksi harian.',
            style: TextStyle(
              color: Color(0xFFBBD2B8),
              fontSize: 9,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    this.trailing,
    this.trailingColor = _green,
    this.onTap,
  });

  final String title;
  final String? trailing;
  final Color trailingColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null)
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.only(left: 8, top: 1, bottom: 1),
              child: Text(
                trailing!,
                style: TextStyle(
                  color: trailingColor,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onProductionTap,
    required this.onIngredientsTap,
    required this.onProductsTap,
  });

  final VoidCallback onProductionTap;
  final VoidCallback onIngredientsTap;
  final VoidCallback onProductsTap;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickActionData(
        label: '+ Produksi',
        icon: Icons.add_circle_outline,
        color: const Color(0xFF075921),
        background: const Color(0xFFDEF8DD),
        onTap: onProductionTap,
      ),
      _QuickActionData(
        label: '+ Bahan',
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFF946000),
        background: const Color(0xFFFFF0D3),
        onTap: onIngredientsTap,
      ),
      _QuickActionData(
        label: '+ Produk',
        icon: Icons.storefront_outlined,
        color: const Color(0xFF5B6259),
        background: const Color(0xFFF0F1ED),
        onTap: onProductsTap,
      ),
    ];
    return Row(
      children: [
        for (var index = 0; index < actions.length; index++) ...[
          if (index > 0) const SizedBox(width: 7),
          Expanded(child: _QuickActionCard(data: actions[index])),
        ],
      ],
    );
  }
}

class _QuickActionData {
  const _QuickActionData({
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback onTap;
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.data});

  final _QuickActionData data;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: data.onTap,
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFECEEE8)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D192C16),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 29,
                height: 29,
                decoration: BoxDecoration(
                  color: data.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(data.icon, color: data.color, size: 17),
              ),
              const SizedBox(height: 4),
              Text(
                data.label,
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.ingredientsKey,
    required this.productionKey,
    required this.materialCount,
    required this.productCount,
    required this.productionCount,
  });

  final GlobalKey ingredientsKey;
  final GlobalKey productionKey;
  final int materialCount;
  final int productCount;
  final int productionCount;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricData(
        title: 'Total Produk',
        value: '$productCount',
        unit: 'varian',
        icon: Icons.shopping_cart_outlined,
        iconColor: Color(0xFF946000),
        iconBackground: Color(0xFFFFF0D3),
      ),
      _MetricData(
        key: ingredientsKey,
        title: 'Bahan Baku',
        value: '$materialCount',
        unit: 'item',
        icon: Icons.assignment_turned_in_outlined,
        iconColor: _green,
        iconBackground: const Color(0xFFDEF8DD),
        status: materialCount == 0 ? 'Kosong' : 'Aktif',
      ),
      _MetricData(
        key: productionKey,
        title: 'Produksi',
        value: '$productionCount',
        unit: 'Batch',
        icon: Icons.soup_kitchen_outlined,
        iconColor: const Color(0xFF5B6259),
        iconBackground: const Color(0xFFF0F1ED),
        status: productionCount == 0 ? 'Kosong' : 'Aktif',
      ),
      const _MetricData(
        title: 'Pesanan Baru',
        value: '0',
        unit: 'pesanan',
        icon: Icons.receipt_long_outlined,
        iconColor: Color(0xFF946000),
        iconBackground: Color(0xFFFFF0D3),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 520;
        final cardWidth = isWide
            ? (constraints.maxWidth - 21) / 4
            : (constraints.maxWidth - 7) / 2;
        return Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: cardWidth,
                child: _MetricCard(data: metric),
              ),
          ],
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData({
    this.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    this.status,
  });

  final Key? key;
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String? status;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: data.key,
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFECEEE8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D192C16),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: data.iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(data.icon, color: data.iconColor, size: 15),
              ),
              const Spacer(),
              if (data.status != null)
                Text(
                  data.status!,
                  style: const TextStyle(
                    color: _green,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            data.title,
            style: const TextStyle(color: Color(0xFF414940), fontSize: 9),
          ),
          const SizedBox(height: 2),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                color: _ink,
                fontSize: 27,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
              ),
              children: [
                TextSpan(text: data.value),
                TextSpan(
                  text: ' ${data.unit}',
                  style: const TextStyle(
                    color: Color(0xFF7B8478),
                    fontSize: 9,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.items});

  final List<_ActivityData> items;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFECEEE8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D192C16),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: items.isEmpty
            ? const [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'Belum ada aktivitas produksi.',
                    style: TextStyle(color: Color(0xFF5B665C), fontSize: 10),
                  ),
                ),
              ]
            : [
                for (var index = 0; index < items.length; index++)
                  _ActivityRow(data: items[index], showDivider: index > 0),
              ],
      ),
    );
  }
}

class _ActivityData {
  const _ActivityData({
    required this.title,
    required this.detail,
    required this.time,
    required this.done,
  });

  final String title;
  final String detail;
  final String time;
  final bool done;
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.data, required this.showDivider});

  final _ActivityData data;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final foreground = data.done ? _green : const Color(0xFF946000);
    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(top: BorderSide(color: Color(0xFFF0F1ED)))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 25,
            height: 25,
            decoration: BoxDecoration(
              color: data.done
                  ? const Color(0xFFDEF8DD)
                  : const Color(0xFFFFF0D3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              data.done
                  ? Icons.check_circle_outline
                  : Icons.local_fire_department,
              color: foreground,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  data.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: data.done
                        ? const Color(0xFF798176)
                        : const Color(0xFFA66C00),
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            data.time,
            style: TextStyle(
              color: data.done ? const Color(0xFF576153) : foreground,
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = [
    (label: 'Dashboard', icon: Icons.dashboard, selected: Icons.dashboard),
    (
      label: 'Bahan Baku',
      icon: Icons.inventory_2_outlined,
      selected: Icons.inventory_2,
    ),
    (
      label: 'Produk',
      icon: Icons.storefront_outlined,
      selected: Icons.storefront,
    ),
    (
      label: 'Produksi',
      icon: Icons.soup_kitchen_outlined,
      selected: Icons.soup_kitchen,
    ),
    (label: 'Aktivitas', icon: Icons.history, selected: Icons.history),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        8,
        5,
        8,
        5 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: const Color(0xFFEFF0E9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12385522),
            blurRadius: 18,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var index = 0; index < _items.length; index++)
            Expanded(
              child: _NavigationItem(
                label: _items[index].label,
                icon: _items[index].icon,
                selectedIcon: _items[index].selected,
                selected: selectedIndex == index,
                onTap: () => onSelected(index),
              ),
            ),
        ],
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF4F7EF) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? selectedIcon : icon,
                size: 18,
                color: selected ? _green : const Color(0xFF465146),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: selected ? _green : const Color(0xFF465146),
                  fontSize: 7,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
