import 'package:flutter/material.dart';
import 'package:nabila_food/data/app_repository.dart';

const _green = Color(0xFF07551C);
const _amber = Color(0xFFFFB900);
const _ink = Color(0xFF20241F);
const _page = Colors.white;

class BahanBakuScreen extends StatefulWidget {
  const BahanBakuScreen({
    super.key,
    required this.repository,
    this.refreshVersion = 0,
  });

  final AppRepository repository;
  final int refreshVersion;

  @override
  State<BahanBakuScreen> createState() => _BahanBakuScreenState();
}

class _BahanBakuScreenState extends State<BahanBakuScreen> {
  final _searchController = TextEditingController();
  final _listController = ScrollController();
  final List<_MaterialStock> _materials = [];

  String _selectedCategory = 'Semua';
  bool _lowStockOnly = false;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  @override
  void didUpdateWidget(covariant BahanBakuScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshVersion != widget.refreshVersion) {
      _loadMaterials();
    }
  }

  Future<void> _loadMaterials() async {
    try {
      final rows = await widget.repository.getMaterials();
      if (!mounted) return;
      setState(() {
        _materials
          ..clear()
          ..addAll(rows.map(_MaterialStock.fromJson));
        _isLoading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Bahan baku gagal dimuat: $error';
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listController.dispose();
    super.dispose();
  }

  List<_MaterialStock> get _filteredMaterials {
    final query = _searchController.text.trim().toLowerCase();
    return _materials.where((material) {
      final matchesCategory =
          _selectedCategory == 'Semua' ||
          material.category == _selectedCategory;
      final matchesSearch =
          query.isEmpty ||
          material.name.toLowerCase().contains(query) ||
          material.category.toLowerCase().contains(query) ||
          material.location.toLowerCase().contains(query) ||
          material.id.toString().contains(query);
      return matchesCategory &&
          matchesSearch &&
          (!_lowStockOnly || material.isBelowMinimum);
    }).toList();
  }

  int get _lowStockCount =>
      _materials.where((material) => material.isBelowMinimum).length;

  Future<void> _addMaterial() async {
    final material = await Navigator.of(context).push<_MaterialStock>(
      MaterialPageRoute<_MaterialStock>(
        builder: (_) => const AddMaterialScreen(),
      ),
    );
    if (material == null || !mounted) return;
    try {
      final saved = _MaterialStock.fromJson(
        await widget.repository.saveMaterial(material.toJson()),
      );
      if (!mounted) return;
      setState(() {
        _materials.add(saved);
        _selectedCategory = 'Semua';
        _lowStockOnly = false;
        _searchController.clear();
      });
      _showMessage('${saved.name} berhasil ditambahkan.');
    } catch (error) {
      if (mounted) _showMessage('Bahan baku gagal disimpan: $error');
    }
  }

  Future<void> _editMaterial(_MaterialStock material) async {
    final result = await Navigator.of(context).push<_EditMaterialResult>(
      MaterialPageRoute<_EditMaterialResult>(
        builder: (_) => _EditMaterialScreen(material: material),
      ),
    );
    if (result == null || !mounted) return;
    try {
      final index = _materials.indexWhere((item) => item.id == material.id);
      if (result.deleted) {
        await widget.repository.deleteMaterial(material.id);
        if (!mounted) return;
        setState(() {
          if (index != -1) _materials.removeAt(index);
        });
        _showMessage('${material.name} berhasil dihapus.');
      } else {
        final saved = _MaterialStock.fromJson(
          await widget.repository.saveMaterial(result.material!.toJson()),
        );
        if (!mounted) return;
        setState(() {
          if (index != -1) _materials[index] = saved;
        });
        _showMessage('Data ${saved.name} berhasil diperbarui.');
      }
    } catch (error) {
      if (mounted) _showMessage('Perubahan bahan baku gagal disimpan: $error');
    }
  }

  Future<void> _addStock(_MaterialStock material) async {
    final amount = await _showStockDialog(material);
    if (amount == null || !mounted) return;
    final index = _materials.indexWhere((item) => item.id == material.id);
    if (index == -1) return;
    try {
      final updated = _materials[index].copyWith(
        quantity: _materials[index].quantity + amount,
      );
      final saved = _MaterialStock.fromJson(
        await widget.repository.saveMaterial(updated.toJson()),
      );
      if (!mounted) return;
      setState(() => _materials[index] = saved);
      _showMessage('Stok ${material.name} berhasil ditambahkan.');
    } catch (error) {
      if (mounted) _showMessage('Stok gagal diperbarui: $error');
    }
  }

  Future<void> _deleteMaterial(_MaterialStock material) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus bahan baku?'),
        content: Text('Data ${material.name} akan dihapus dari daftar bahan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;
    try {
      await widget.repository.deleteMaterial(material.id);
      if (!mounted) return;
      setState(() => _materials.removeWhere((item) => item.id == material.id));
      _showMessage('${material.name} berhasil dihapus.');
    } catch (error) {
      if (mounted) _showMessage('Bahan baku gagal dihapus: $error');
    }
  }

  Future<double?> _showStockDialog(_MaterialStock material) async {
    return showDialog<double>(
      context: context,
      builder: (_) => _StockFormDialog(material: material),
    );
  }

  void _toggleLowStock() {
    setState(() {
      _lowStockOnly = !_lowStockOnly;
      _selectedCategory = 'Semua';
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final visibleMaterials = _filteredMaterials;
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTitle(),
            _buildSearch(),
            _buildCategories(),
            if (_lowStockCount > 0) _buildLowStockNotice(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _loadError != null
                  ? Center(child: Text(_loadError!))
                  : visibleMaterials.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      controller: _listController,
                      padding: const EdgeInsets.fromLTRB(13, 9, 13, 90),
                      itemCount: visibleMaterials.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final material = visibleMaterials[index];
                        return _MaterialCard(
                          material: material,
                          onEdit: () => _editMaterial(material),
                          onRestock: () => _addStock(material),
                          onDelete: () => _deleteMaterial(material),
                        );
                      },
                    ),
            ),
          ],
        ),
        Positioned(
          right: 13,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'add-material',
            onPressed: _addMaterial,
            backgroundColor: _amber,
            foregroundColor: const Color(0xFF3F3300),
            elevation: 4,
            icon: const Icon(Icons.add, size: 20),
            label: const Text(
              'Tambah Bahan',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 17, 13, 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MANAJEMEN DAPUR',
                  style: TextStyle(
                    color: Color(0xFF8A6000),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Bahan Baku',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(color: Color(0x0C192C16), blurRadius: 5),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.circle, color: _green, size: 7),
                const SizedBox(width: 4),
                Text(
                  '${_materials.length} Item Aktif',
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13),
      child: SizedBox(
        height: 39,
        child: TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Cari nama bahan, kode id...',
            hintStyle: const TextStyle(color: Color(0xFF7C847A), fontSize: 11),
            prefixIcon: const Icon(
              Icons.search,
              color: Color(0xFF697468),
              size: 19,
            ),
            suffixIcon: IconButton(
              tooltip: _lowStockOnly
                  ? 'Tampilkan semua stok'
                  : 'Filter stok rendah',
              onPressed: _toggleLowStock,
              icon: Icon(
                _lowStockOnly ? Icons.filter_alt : Icons.tune,
                color: _lowStockOnly ? _green : const Color(0xFF4C554A),
                size: 18,
              ),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: const BorderSide(color: Color(0xFFE0E4DC)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: const BorderSide(color: Color(0xFF7D9C77)),
            ),
          ),
          style: const TextStyle(fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildCategories() {
    final categories = [
      'Semua',
      'Tepung & Gandum',
      'Ubi Ungu',
      'Mentega & Dairy',
      'Pemanis',
      'Bumbu',
    ];
    return SizedBox(
      height: 39,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(13, 8, 13, 4),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = _selectedCategory == category;
          final label = category == 'Semua'
              ? 'Semua (${_materials.length})'
              : category;
          return ChoiceChip(
            label: Text(label),
            selected: selected,
            showCheckmark: false,
            onSelected: (_) => setState(() {
              _selectedCategory = category;
              _lowStockOnly = false;
            }),
            labelStyle: TextStyle(
              color: selected ? Colors.white : const Color(0xFF40483E),
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            visualDensity: VisualDensity.compact,
            side: BorderSide(
              color: selected ? _green : const Color(0xFFE3E7DF),
            ),
            backgroundColor: Colors.white,
            selectedColor: _green,
            shape: const StadiumBorder(),
          );
        },
      ),
    );
  }

  Widget _buildLowStockNotice() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 4, 13, 4),
      child: Container(
        height: 47,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF4),
          border: Border.all(color: const Color(0xFFECE9DD)),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Container(
              width: 27,
              height: 27,
              decoration: const BoxDecoration(
                color: Color(0xFFFFE9AE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: Color(0xFF966300),
                size: 15,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Peringatan Stok Minimum',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '$_lowStockCount bahan baku butuh restock segera',
                    style: const TextStyle(
                      color: Color(0xFF636B60),
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _lowStockOnly = true;
                  _selectedCategory = 'Semua';
                });
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF8A6000),
                padding: const EdgeInsets.symmetric(horizontal: 9),
                minimumSize: const Size(0, 27),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: const BorderSide(color: Color(0xFFFFD680)),
                backgroundColor: Colors.white,
              ),
              child: const Text(
                'Periksa',
                style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, color: Color(0xFF879080), size: 36),
            const SizedBox(height: 8),
            Text(
              _materials.isEmpty && _searchController.text.trim().isEmpty
                  ? 'Belum ada bahan baku. Tambahkan bahan untuk mulai mengelola stok.'
                  : _lowStockOnly || _selectedCategory != 'Semua'
                  ? 'Tidak ada bahan pada filter ini'
                  : 'Bahan baku tidak ditemukan',
              style: const TextStyle(
                color: Color(0xFF586153),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            if (_materials.isNotEmpty)
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedCategory = 'Semua';
                    _lowStockOnly = false;
                    _searchController.clear();
                  });
                },
                child: const Text('Hapus filter'),
              ),
          ],
        ),
      ),
    );
  }
}

class AddMaterialScreen extends StatefulWidget {
  const AddMaterialScreen({super.key});

  @override
  State<AddMaterialScreen> createState() => _AddMaterialScreenState();
}

class _AddMaterialScreenState extends State<AddMaterialScreen> {
  static const _categories = [
    'Tepung & Gandum',
    'Ubi Ungu',
    'Pemanis',
    'Bumbu',
    'Mentega & Dairy',
    'Lainnya',
  ];
  static const _units = ['Kg', 'Gram', 'Liter', 'mL', 'Pcs'];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '0');
  final _minimumController = TextEditingController(text: '0');
  final _supplierController = TextEditingController();
  String _category = _categories.first;
  String _unit = 'Kg';

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _minimumController.dispose();
    _supplierController.dispose();
    super.dispose();
  }

  double get _quantity =>
      double.tryParse(_quantityController.text.trim().replaceAll(',', '.')) ??
      0;

  void _changeQuantity(double change) {
    final value = (_quantity + change).clamp(0, 999999).toDouble();
    _quantityController.value = TextEditingValue(
      text: _formatQuantity(value),
      selection: TextSelection.collapsed(offset: _formatQuantity(value).length),
    );
    setState(() {});
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final supplier = _supplierController.text.trim();
    final minimumStock = double.parse(
      _minimumController.text.trim().replaceAll(',', '.'),
    );
    Navigator.of(context).pop(
      _MaterialStock(
        id: '',
        name: _nameController.text.trim(),
        category: _category,
        quantity: _quantity,
        capacity: _quantity > minimumStock * 2 ? _quantity : minimumStock * 2,
        location: supplier.isEmpty ? 'Gudang Utama' : supplier,
        icon: _categoryIcon(_category),
        unit: _unit,
        minimumStock: minimumStock,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: 12,
                              top: 10,
                              right: 12,
                            ),
                            child: IntrinsicHeight(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildInfoBanner(),
                                  const SizedBox(height: 12),
                                  Expanded(child: _buildFormCard()),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 53,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFBF6),
        border: Border(bottom: BorderSide(color: Color(0xFFECEEE7))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Kembali',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 30, height: 40),
            icon: const Icon(Icons.arrow_back, size: 20),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tambah Bahan Baku',
                    style: TextStyle(
                      color: _green,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Inventori & Gudang Dapur',
                    style: TextStyle(color: Color(0xFF5E665D), fontSize: 9),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE3B4),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'BAHAN BAKU',
              style: TextStyle(
                color: Color(0xFF704500),
                fontSize: 7,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F8E5),
        border: Border.all(color: const Color(0xFFC7EEC4)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, color: _green, size: 22),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Data bahan baku ini akan otomatis terkoneksi dengan kalkulator resep roti dan modul pesanan harian.',
              style: TextStyle(
                color: Color(0xFF315B36),
                fontSize: 9,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11192C16),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldLabel('Nama Bahan Baku', required: true),
          const SizedBox(height: 5),
          _pillInput(
            controller: _nameController,
            hintText: 'Contoh: Tepung Terigu Protein Tinggi',
            prefixIcon: Icons.inventory_2_outlined,
            validator: _requiredField,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 11),
          _fieldLabel('Kategori Bahan'),
          const SizedBox(height: 5),
          _categoryDropdown(),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _fieldLabel('Jumlah Stok Awal', required: true),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _fieldLabel(
                    'Timbangan Gudang',
                    color: _green,
                    fontSize: 7,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(flex: 3, child: _quantityStepper()),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: _unitDropdown()),
            ],
          ),
          const SizedBox(height: 11),
          _buildMinimumNotice(),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(child: _fieldLabel('Catatan / Pemasok (Opsional)')),
              const Text(
                'Opsional',
                style: TextStyle(color: Color(0xFF6C7569), fontSize: 7),
              ),
            ],
          ),
          const SizedBox(height: 5),
          _pillInput(
            controller: _supplierController,
            hintText: 'Nama pemasok atau lokasi gudang',
            prefixIcon: Icons.local_shipping_outlined,
            textCapitalization: TextCapitalization.words,
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(
    String label, {
    bool required = false,
    Color color = _ink,
    double fontSize = 9,
  }) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
        children: [
          TextSpan(text: label),
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFB3261E)),
            ),
        ],
      ),
    );
  }

  Widget _pillInput({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputType? keyboardType,
    Widget? suffix,
    ValueChanged<String>? onChanged,
    TextAlign textAlign = TextAlign.start,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 37),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        textAlign: textAlign,
        onChanged: onChanged,
        style: const TextStyle(
          color: _ink,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Color(0xFF9BA294),
            fontSize: 10,
            fontWeight: FontWeight.w400,
          ),
          isDense: true,
          prefixIcon: Icon(
            prefixIcon,
            color: const Color(0xFF657061),
            size: 15,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 34),
          suffixIcon: suffix,
          filled: true,
          fillColor: const Color(0xFFFAFBF7),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: const BorderSide(color: Color(0xFFDFE4D9)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: const BorderSide(color: Color(0xFFDFE4D9)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: const BorderSide(color: Color(0xFF82A57D)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFB3261E)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFB3261E)),
          ),
          errorStyle: const TextStyle(fontSize: 8, height: 1.1),
        ),
      ),
    );
  }

  Widget _categoryDropdown() {
    return SizedBox(
      height: 37,
      child: DropdownButtonFormField<String>(
        initialValue: _category,
        decoration: InputDecoration(
          prefixIcon: const Icon(
            Icons.category_outlined,
            color: Color(0xFF657061),
            size: 15,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 34),
          filled: true,
          fillColor: const Color(0xFFFAFBF7),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: const BorderSide(color: Color(0xFFDFE4D9)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: const BorderSide(color: Color(0xFFDFE4D9)),
          ),
        ),
        icon: const Icon(Icons.expand_more, size: 17),
        style: const TextStyle(
          color: _ink,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        items: [
          for (final category in _categories)
            DropdownMenuItem(value: category, child: Text(category)),
        ],
        onChanged: (value) {
          if (value != null) setState(() => _category = value);
        },
      ),
    );
  }

  Widget _quantityStepper() {
    return FormField<String>(
      initialValue: _quantityController.text,
      validator: _nonNegativeQuantityValidator,
      builder: (field) => Column(
        children: [
          Container(
            height: 37,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFBF7),
              border: Border.all(
                color: field.hasError
                    ? const Color(0xFFB3261E)
                    : const Color(0xFFDFE4D9),
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                _stepButton(
                  icon: Icons.remove,
                  tooltip: 'Kurangi jumlah',
                  onPressed: () {
                    _changeQuantity(-1);
                    field.didChange(_quantityController.text);
                  },
                  background: const Color(0xFFF0F1ED),
                ),
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    onChanged: (value) {
                      field.didChange(value);
                      setState(() {});
                    },
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: const InputDecoration(
                      hintText: '0',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
                _stepButton(
                  icon: Icons.add,
                  tooltip: 'Tambah jumlah',
                  onPressed: () {
                    _changeQuantity(1);
                    field.didChange(_quantityController.text);
                  },
                  background: const Color(0xFF9BF08D),
                  foreground: _green,
                ),
              ],
            ),
          ),
          if (field.errorText != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 3),
                child: Text(
                  field.errorText!,
                  style: const TextStyle(color: Color(0xFFB3261E), fontSize: 8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stepButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required Color background,
    Color foreground = const Color(0xFF4B5449),
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 27,
            height: 27,
            child: Icon(icon, color: foreground, size: 17),
          ),
        ),
      ),
    );
  }

  Widget _unitDropdown() {
    return SizedBox(
      height: 37,
      child: DropdownButtonFormField<String>(
        initialValue: _unit,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          filled: true,
          fillColor: const Color(0xFFFAFBF7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: const BorderSide(color: Color(0xFFDFE4D9)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: const BorderSide(color: Color(0xFFDFE4D9)),
          ),
        ),
        icon: const Icon(Icons.expand_more, size: 15),
        style: const TextStyle(
          color: _ink,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
        items: [
          for (final unit in _units)
            DropdownMenuItem(value: unit, child: Text(unit)),
        ],
        onChanged: (value) {
          if (value != null) setState(() => _unit = value);
        },
      ),
    );
  }

  Widget _buildMinimumNotice() {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9F0),
        border: Border.all(color: const Color(0xFFFFDFA8)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.notifications_active_outlined,
                color: Color(0xFF936100),
                size: 13,
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  'Batas Minimum Aman',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE5BA),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Peringatan Dini',
                  style: TextStyle(
                    color: Color(0xFF704500),
                    fontSize: 7,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _pillInput(
            controller: _minimumController,
            hintText: '25',
            prefixIcon: Icons.warning_amber_rounded,
            validator: _nonNegativeQuantityValidator,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suffix: const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFF936100),
                size: 14,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Color(0xFF936100), size: 11),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Notifikasi otomatis akan dikirim ke admin operasional jika stok tersisa di bawah batas ini.',
                  style: TextStyle(
                    color: Color(0xFF626252),
                    fontSize: 8,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x12385522),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 40,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_circle_outline, size: 15),
              label: const Text(
                'Simpan Bahan',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF176126),
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
            ),
          ),
          const SizedBox(height: 7),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: _green,
                side: const BorderSide(color: Color(0xFFD7DFD4)),
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'Batal',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditMaterialResult {
  const _EditMaterialResult.updated(this.material) : deleted = false;
  const _EditMaterialResult.deletedMaterial() : material = null, deleted = true;

  final _MaterialStock? material;
  final bool deleted;
}

class _EditMaterialScreen extends StatefulWidget {
  const _EditMaterialScreen({required this.material});

  final _MaterialStock material;

  @override
  State<_EditMaterialScreen> createState() => _EditMaterialScreenState();
}

class _EditMaterialScreenState extends State<_EditMaterialScreen> {
  static const _categories = [
    'Tepung & Gandum',
    'Ubi Ungu',
    'Pemanis',
    'Bumbu',
    'Mentega & Dairy',
    'Lainnya',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _minimumController;
  late String _category;
  late bool _useInRecipes;

  @override
  void initState() {
    super.initState();
    final material = widget.material;
    _nameController = TextEditingController(text: material.name);
    _quantityController = TextEditingController(
      text: _formatQuantity(material.quantity),
    );
    _minimumController = TextEditingController(
      text: _formatQuantity(material.minimumStock),
    );
    _category = _categories.contains(material.category)
        ? material.category
        : 'Lainnya';
    _useInRecipes = material.useInRecipes;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _minimumController.dispose();
    super.dispose();
  }

  double get _quantity =>
      double.tryParse(_quantityController.text.trim().replaceAll(',', '.')) ??
      0;

  void _changeQuantity(double amount) {
    final value = (_quantity + amount).clamp(0, 999999).toDouble();
    final text = _formatQuantity(value);
    _quantityController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() {});
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final quantity = _quantity;
    Navigator.of(context).pop(
      _EditMaterialResult.updated(
        widget.material.copyWith(
          name: _nameController.text.trim(),
          category: _category,
          quantity: quantity,
          capacity: quantity > widget.material.capacity
              ? quantity
              : widget.material.capacity,
          minimumStock: double.parse(
            _minimumController.text.trim().replaceAll(',', '.'),
          ),
          useInRecipes: _useInRecipes,
          icon: _categoryIcon(_category),
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus bahan baku?'),
        content: Text('Data ${widget.material.name} akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD91F26),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (delete == true && mounted) {
      Navigator.of(context).pop(const _EditMaterialResult.deletedMaterial());
    }
  }

  @override
  Widget build(BuildContext context) {
    final material = widget.material;
    final stockPercent = material.capacity <= 0
        ? 0.0
        : (_quantity / material.capacity).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(11, 9, 11, 14),
                      children: [
                        _buildStockSummary(stockPercent),
                        const SizedBox(height: 12),
                        _buildNameCard(),
                        const SizedBox(height: 10),
                        _buildCategoryCard(),
                        const SizedBox(height: 10),
                        _buildQuantityCard(stockPercent),
                        const SizedBox(height: 10),
                        _buildMinimumCard(),
                        const SizedBox(height: 10),
                        _buildRecipeCard(),
                      ],
                    ),
                  ),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 49,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFBF6),
        border: Border(bottom: BorderSide(color: Color(0xFFECEEE7))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Kembali',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.arrow_back, size: 18),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Edit Bahan Baku',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Detail & Penyesuaian Stok',
                  style: TextStyle(color: Color(0xFF5F675C), fontSize: 8),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE3B4),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '#BB-${_shortId(widget.material.id)}',
              style: const TextStyle(
                color: Color(0xFF704500),
                fontSize: 7,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: _delete,
            tooltip: 'Hapus bahan',
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFFFE3E0),
              foregroundColor: const Color(0xFFD91F26),
            ),
            icon: const Icon(Icons.delete_outline, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildStockSummary(double stockPercent) {
    final currentMaterial = widget.material.copyWith(
      quantity: _quantity,
      minimumStock:
          double.tryParse(
            _minimumController.text.trim().replaceAll(',', '.'),
          ) ??
          0,
    );
    final statusColor = currentMaterial.statusColor;
    return _EditCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F6E5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '● Status Stok: ${currentMaterial.status} '
                      '(${_formatQuantity(_quantity)} ${widget.material.unit})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${(stockPercent * 100).round()}% Kapasitas',
                style: const TextStyle(fontSize: 8),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: stockPercent,
              minHeight: 5,
              color: statusColor,
              backgroundColor: const Color(0xFFE6E8E2),
            ),
          ),
          const SizedBox(height: 7),
          const Row(
            children: [
              Icon(Icons.history, size: 11, color: Color(0xFF8A650B)),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Belum ada riwayat restock.',
                  style: TextStyle(color: Color(0xFF687064), fontSize: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNameCard() {
    return _EditCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EditFieldLabel('Nama Bahan Baku'),
          const SizedBox(height: 5),
          _editInput(
            controller: _nameController,
            icon: Icons.grain,
            validator: _requiredField,
            capitalization: TextCapitalization.words,
            suffix: const Icon(Icons.edit, size: 14, color: _ink),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard() {
    return _EditCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EditFieldLabel('Kategori'),
          const SizedBox(height: 5),
          _dropdown(
            value: _category,
            values: _categories,
            icon: Icons.category_outlined,
            onChanged: (value) => setState(() => _category = value),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityCard(double stockPercent) {
    return _EditCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: _EditFieldLabel('Jumlah Stok Fisik Saat Ini'),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDF8DD),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Unit ${widget.material.unit}',
                  style: const TextStyle(
                    color: _green,
                    fontSize: 7,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFBF7),
              border: Border.all(color: const Color(0xFFDFE4D9)),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                _roundQuantityButton(
                  icon: Icons.remove,
                  tooltip: 'Kurangi stok',
                  onPressed: () => _changeQuantity(-1),
                  background: const Color(0xFFF1F2EE),
                  foreground: _ink,
                ),
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    validator: _quantityValidator,
                    style: const TextStyle(
                      color: _green,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      errorStyle: const TextStyle(fontSize: 7, height: 0.9),
                      suffixText: widget.material.unit,
                      suffixStyle: const TextStyle(
                        color: Color(0xFF4D554B),
                        fontSize: 9,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                _roundQuantityButton(
                  icon: Icons.add,
                  tooltip: 'Tambah stok',
                  onPressed: () => _changeQuantity(1),
                  background: _green,
                  foreground: Colors.white,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _quickStockButton('-10 ${widget.material.unit}', -10),
              const SizedBox(width: 6),
              _quickStockButton('+10 ${widget.material.unit}', 10),
              const SizedBox(width: 6),
              _quickStockButton('+50 ${widget.material.unit}', 50),
            ],
          ),
          if (widget.material.capacity > 0) ...[
            const SizedBox(height: 7),
            Text(
              'Kapasitas ${_formatQuantity(widget.material.capacity)} '
              '${widget.material.unit} • ${(stockPercent * 100).round()}% terisi',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Color(0xFF768071), fontSize: 7),
            ),
          ],
        ],
      ),
    );
  }

  Widget _quickStockButton(String label, double amount) {
    return Expanded(
      child: SizedBox(
        height: 28,
        child: OutlinedButton(
          onPressed: () => _changeQuantity(amount),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: const Color(0xFF453920),
            backgroundColor: const Color(0xFFFFF1DC),
            side: const BorderSide(color: Color(0xFFF1D6AD)),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(fontSize: 8),
          ),
          child: Text(label),
        ),
      ),
    );
  }

  Widget _buildMinimumCard() {
    return _EditCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _EditFieldLabel('Batas Minimum Stok (Reorder Point)'),
          const SizedBox(height: 5),
          _editInput(
            controller: _minimumController,
            icon: Icons.warning_amber_outlined,
            onChanged: (_) => setState(() {}),
            validator: _nonNegativeQuantityValidator,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suffix: Text(
              widget.material.unit,
              style: const TextStyle(fontSize: 9, color: _ink),
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'ⓘ Notifikasi aktif otomatis jika stok kurang dari batas ini',
            style: TextStyle(color: Color(0xFF966400), fontSize: 8),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeCard() {
    return _EditCard(
      child: Row(
        children: [
          Container(
            width: 27,
            height: 27,
            decoration: const BoxDecoration(
              color: Color(0xFFFFEAC7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Color(0xFF916000),
              size: 14,
            ),
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gunakan untuk Resep Otomatis Harian',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Alokasikan bahan langsung ke sistem jadwal baking pagi.',
                  style: TextStyle(
                    color: Color(0xFF646D61),
                    fontSize: 8,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _useInRecipes,
            activeThumbColor: Colors.white,
            activeTrackColor: _green,
            onChanged: (value) => setState(() => _useInRecipes = value),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
        boxShadow: [
          BoxShadow(
            color: Color(0x12385522),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 39,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _green,
                  side: const BorderSide(color: _green),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Batal'),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            flex: 4,
            child: SizedBox(
              height: 39,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined, size: 14),
                label: const Text(
                  'Simpan Perubahan',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF176126),
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editInput({
    required TextEditingController controller,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    Widget? suffix,
    TextCapitalization capitalization = TextCapitalization.none,
    ValueChanged<String>? onChanged,
  }) {
    return SizedBox(
      height: 37,
      child: TextFormField(
        controller: controller,
        onChanged: onChanged,
        validator: validator,
        keyboardType: keyboardType,
        textCapitalization: capitalization,
        style: const TextStyle(fontSize: 10, color: _ink),
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: Icon(icon, color: const Color(0xFF657061), size: 14),
          prefixIconConstraints: const BoxConstraints(minWidth: 33),
          suffixIcon: suffix == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(right: 11),
                  child: suffix,
                ),
          suffixIconConstraints: suffix == null
              ? null
              : const BoxConstraints(minWidth: 22),
          contentPadding: const EdgeInsets.symmetric(horizontal: 11),
          filled: true,
          fillColor: const Color(0xFFFAFBF7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: const BorderSide(color: Color(0xFFDFE4D9)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: const BorderSide(color: Color(0xFFDFE4D9)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: const BorderSide(color: Color(0xFF82A57D)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: Color(0xFFB3261E)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: Color(0xFFB3261E)),
          ),
          errorStyle: const TextStyle(fontSize: 7, height: 1),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String value,
    required List<String> values,
    required IconData icon,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      height: 37,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        onChanged: (nextValue) {
          if (nextValue != null) onChanged(nextValue);
        },
        icon: const Icon(Icons.expand_more, size: 17),
        style: const TextStyle(fontSize: 10, color: _ink),
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: Icon(icon, color: const Color(0xFF657061), size: 14),
          prefixIconConstraints: const BoxConstraints(minWidth: 33),
          contentPadding: const EdgeInsets.symmetric(horizontal: 11),
          filled: true,
          fillColor: const Color(0xFFFAFBF7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: const BorderSide(color: Color(0xFFDFE4D9)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: const BorderSide(color: Color(0xFFDFE4D9)),
          ),
        ),
        items: [
          for (final option in values)
            DropdownMenuItem(value: option, child: Text(option)),
        ],
      ),
    );
  }

  Widget _roundQuantityButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required Color background,
    required Color foreground,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, color: foreground, size: 18),
          ),
        ),
      ),
    );
  }
}

class _EditCard extends StatelessWidget {
  const _EditCard({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(11, 10, 11, 10),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE9ECE5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D192C16),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _EditFieldLabel extends StatelessWidget {
  const _EditFieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF434B41),
        fontSize: 8,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _MaterialStock {
  const _MaterialStock({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.capacity,
    required this.location,
    required this.icon,
    this.unit = 'Kg',
    this.minimumStock = 0,
    this.useInRecipes = true,
  });

  final String id;
  final String name;
  final String category;
  final double quantity;
  final double capacity;
  final String location;
  final IconData icon;
  final String unit;
  final double minimumStock;
  final bool useInRecipes;

  double get stockPercent =>
      capacity <= 0 ? 0 : (quantity / capacity * 100).clamp(0, 100).toDouble();
  bool get isBelowMinimum => minimumStock > 0 && quantity <= minimumStock;

  factory _MaterialStock.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as String? ?? 'Lainnya';
    return _MaterialStock(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      category: category,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      capacity: (json['capacity'] as num?)?.toDouble() ?? 0,
      location: json['location'] as String? ?? 'Gudang Utama',
      icon: _categoryIcon(category),
      unit: json['unit'] as String? ?? 'Kg',
      minimumStock: (json['minimum_stock'] as num?)?.toDouble() ?? 0,
      useInRecipes: json['use_in_recipes'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id.isNotEmpty) 'id': id,
    'name': name,
    'category': category,
    'quantity': quantity,
    'capacity': capacity,
    'location': location,
    'icon': icon.codePoint.toString(),
    'unit': unit,
    'minimum_stock': minimumStock,
    'use_in_recipes': useInRecipes,
  };

  String get status {
    if (isBelowMinimum) {
      return quantity <= minimumStock / 2 ? 'Kritis' : 'Stok Rendah';
    }
    if (stockPercent > 50) return 'Stok Aman';
    if (stockPercent > 35) return 'Stok Sedang';
    if (stockPercent > 20) return 'Stok Rendah';
    return 'Kritis';
  }

  Color get statusColor {
    if (isBelowMinimum) {
      return quantity <= minimumStock / 2
          ? const Color(0xFFB42318)
          : const Color(0xFF946000);
    }
    if (stockPercent > 50) return _green;
    if (stockPercent > 20) return const Color(0xFF946000);
    return const Color(0xFFB42318);
  }

  Color get statusBackground {
    if (isBelowMinimum) {
      return quantity <= minimumStock / 2
          ? const Color(0xFFFFD9D6)
          : const Color(0xFFFFE0AD);
    }
    if (stockPercent > 50) return const Color(0xFFDDF8DD);
    if (stockPercent > 20) return const Color(0xFFFFE0AD);
    return const Color(0xFFFFD9D6);
  }

  Color get progressColor {
    if (isBelowMinimum) {
      return quantity <= minimumStock / 2
          ? const Color(0xFFD91F26)
          : const Color(0xFFFFB52A);
    }
    if (stockPercent > 50) return _green;
    if (stockPercent > 35) return const Color(0xFFFFB52A);
    if (stockPercent > 20) return const Color(0xFFFFB52A);
    return const Color(0xFFD91F26);
  }

  _MaterialStock copyWith({
    String? id,
    String? name,
    String? category,
    double? quantity,
    double? capacity,
    String? location,
    IconData? icon,
    String? unit,
    double? minimumStock,
    bool? useInRecipes,
  }) {
    return _MaterialStock(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      capacity: capacity ?? this.capacity,
      location: location ?? this.location,
      icon: icon ?? this.icon,
      unit: unit ?? this.unit,
      minimumStock: minimumStock ?? this.minimumStock,
      useInRecipes: useInRecipes ?? this.useInRecipes,
    );
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({
    required this.material,
    required this.onEdit,
    required this.onRestock,
    required this.onDelete,
  });

  final _MaterialStock material;
  final VoidCallback onEdit;
  final VoidCallback onRestock;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final percent = material.stockPercent;
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 10, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11192C16),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: percent <= 20
                      ? const Color(0xFFFFF0F0)
                      : (percent <= 35
                            ? const Color(0xFFFFF5E5)
                            : const Color(0xFFF1F3EC)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  material.icon,
                  color: material.statusColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'ID #${_shortId(material.id)}',
                          style: const TextStyle(
                            color: Color(0xFF626A60),
                            fontSize: 7,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: material.statusBackground,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '● ${material.status}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: material.statusColor,
                                fontSize: 7,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      material.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: material.statusColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      children: [
                        TextSpan(text: _formatQuantity(material.quantity)),
                        TextSpan(
                          text: ' ${material.unit}',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 9,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Kapasitas ${percent.round()}%',
                    style: const TextStyle(
                      color: Color(0xFF788074),
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 5,
              color: material.progressColor,
              backgroundColor: const Color(0xFFECEDE8),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Icon(
                material.location.toLowerCase().contains('chiller')
                    ? Icons.ac_unit
                    : Icons.warehouse_outlined,
                color: const Color(0xFF70796D),
                size: 15,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  material.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF51594F), fontSize: 8),
                ),
              ),
              _MaterialAction(
                icon: Icons.edit_outlined,
                label: 'Edit ${material.name}',
                color: const Color(0xFF946000),
                onPressed: onEdit,
              ),
              _MaterialAction(
                icon: Icons.swap_horiz,
                label: 'Tambah stok ${material.name}',
                color: _green,
                onPressed: onRestock,
              ),
              _MaterialAction(
                icon: Icons.delete_outline,
                label: 'Hapus ${material.name}',
                color: const Color(0xFFD91F26),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MaterialAction extends StatelessWidget {
  const _MaterialAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: label,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 29, height: 30),
      padding: EdgeInsets.zero,
      icon: Icon(icon, color: color, size: 18),
    );
  }
}

class _StockFormDialog extends StatefulWidget {
  const _StockFormDialog({required this.material});

  final _MaterialStock material;

  @override
  State<_StockFormDialog> createState() => _StockFormDialogState();
}

class _StockFormDialogState extends State<_StockFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Stok'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.material.name} • Stok tersedia '
              '${_formatQuantity(widget.material.quantity)} ${widget.material.unit}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            _DialogField(
              controller: _amountController,
              label: 'Jumlah tambahan (${widget.material.unit})',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: _quantityValidator,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              double.parse(_amountController.text.trim().replaceAll(',', '.')),
            );
          },
          style: FilledButton.styleFrom(backgroundColor: _green),
          child: const Text('Tambah'),
        ),
      ],
    );
  }
}

class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

String? _requiredField(String? value) {
  if (value == null || value.trim().isEmpty) return 'Bagian ini wajib diisi';
  return null;
}

String? _quantityValidator(String? value) {
  final quantity = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
  if (quantity == null || !quantity.isFinite || quantity <= 0) {
    return 'Masukkan jumlah lebih dari 0';
  }
  return null;
}

String? _nonNegativeQuantityValidator(String? value) {
  final quantity = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
  if (quantity == null || !quantity.isFinite || quantity < 0) {
    return 'Masukkan jumlah 0 atau lebih';
  }
  return null;
}

IconData _categoryIcon(String category) {
  switch (category) {
    case 'Tepung & Gandum':
      return Icons.grain;
    case 'Ubi Ungu':
      return Icons.spa_outlined;
    case 'Pemanis':
      return Icons.water_drop;
    case 'Bumbu':
      return Icons.lunch_dining;
    case 'Mentega & Dairy':
      return Icons.egg_alt_outlined;
    default:
      return Icons.inventory_2_outlined;
  }
}

String _formatQuantity(double quantity) {
  return quantity == quantity.roundToDouble()
      ? quantity.toInt().toString()
      : quantity.toStringAsFixed(1);
}

String _shortId(String id) =>
    id.substring(0, id.length < 6 ? id.length : 6).toUpperCase();
