import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nabila_food/data/app_repository.dart';

const _green = Color(0xFF07551C);
const _amber = Color(0xFFFFB900);
const _ink = Color(0xFF202720);
const _page = Color(0xFFF8F9F3);

const _starterRecipes = <_Recipe>[
  _Recipe(
    name: 'Keripik Ubi Madu',
    category: 'Keripik Manis',
    recipeYield: '25 kg',
    recipeYieldKg: 25,
    ingredients: [
      'Ubi jalar: 100 kg',
      'Gula: 5 kg',
      'Madu: 1 lt',
      'Garam: 100 g',
      'Bawang putih: 250 g',
    ],
  ),
  _Recipe(
    name: 'Keripik Ubi Ungu',
    category: 'Aneka Keripik',
    recipeYield: '25 kg',
    recipeYieldKg: 25,
    ingredients: ['Ubi jalar: 100 kg', 'Garam: 100 g', 'Bawang putih: 250 g'],
  ),
  _Recipe(
    name: 'Keripik Ubi Cilembu',
    category: 'Aneka Keripik',
    recipeYield: '25 kg',
    recipeYieldKg: 25,
    ingredients: ['Ubi jalar: 100 kg', 'Garam: 100 g', 'Bawang putih: 250 g'],
  ),
  _Recipe(
    name: 'Stik Ubi',
    category: 'Aneka Keripik',
    recipeYield: '2,5-3 kg',
    ingredients: [
      'Ubi jalar: 5 kg',
      'Bawang putih bubuk: 40 g',
      'Garam: 40 g',
      'Kaldu bubuk: 50 g',
      'Lada bubuk: 10 g',
      'Minyak goreng: 100-150 ml',
    ],
  ),
  _Recipe(
    name: 'Keripik Kentang Udang',
    category: 'Keripik Gurih',
    recipeYield: '2,5-5 kg',
    ingredients: [
      'Kentang: 5 kg',
      'Udang kering/rebon: 250 g',
      'Bawang putih: 100 g',
      'Cabai merah: 200 g',
      'Gula merah: 300 g',
      'Gula pasir: 150 g',
      'Garam: 50 g',
      'Penyedap rasa: 50 g',
      'Asam jawa: 30 g',
      'Minyak untuk menggoreng: Secukupnya',
    ],
  ),
];

class ProdukScreen extends StatefulWidget {
  const ProdukScreen({
    super.key,
    required this.repository,
    required this.onStartBatch,
    this.refreshVersion = 0,
  });

  final AppRepository repository;
  final VoidCallback onStartBatch;
  final int refreshVersion;

  @override
  State<ProdukScreen> createState() => _ProdukScreenState();
}

class _ProdukScreenState extends State<ProdukScreen> {
  final _searchController = TextEditingController();
  final List<_Product> _products = [];
  bool _isLoading = true;
  bool _isImportingRecipes = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void didUpdateWidget(covariant ProdukScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshVersion != oldWidget.refreshVersion) {
      _loadProducts();
    }
  }

  Future<void> _loadProducts() async {
    try {
      final rows = await widget.repository.getProducts();
      if (!mounted) return;
      setState(() {
        _products
          ..clear()
          ..addAll(rows.map(_Product.fromJson));
        _isLoading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Produk gagal dimuat: $error';
      });
    }
  }

  String _category = 'Semua';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_Product> get _visibleProducts {
    final query = _searchController.text.trim().toLowerCase();
    return _products.where((product) {
      final matchesCategory =
          _category == 'Semua' ||
          product.name.toLowerCase().contains(_category.toLowerCase());
      final matchesSearch =
          query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  Future<void> _showProductForm({_Product? product}) async {
    List<_RecipeMaterial> materials;
    try {
      materials = (await widget.repository.getMaterials())
          .map(_RecipeMaterial.fromJson)
          .where((material) => material.useInRecipes)
          .toList();
    } catch (error) {
      if (mounted) _showMessage('Daftar bahan baku gagal dimuat: $error');
      return;
    }
    if (!mounted) return;
    final result = await Navigator.of(context).push<_Product>(
      MaterialPageRoute<_Product>(
        builder: (_) => _ProductFormScreen(
          product: product,
          materials: materials,
          onDelete: product == null
              ? null
              : () => _deleteProduct(product, confirm: false),
        ),
      ),
    );
    if (result == null || !mounted) return;
    try {
      final saved = _Product.fromJson(
        await widget.repository.saveProduct(result.toJson()),
      );
      if (!mounted) return;
      setState(() {
        if (product == null) {
          _products.add(saved);
        } else {
          final index = _products.indexOf(product);
          if (index != -1) _products[index] = saved;
        }
      });
    } catch (error) {
      if (mounted) _showMessage('Produk gagal disimpan: $error');
    }
  }

  Future<void> _importRecipes() async {
    if (_isImportingRecipes) return;
    setState(() => _isImportingRecipes = true);

    final existingNames = _products
        .map((product) => product.name.toLowerCase())
        .toSet();
    var added = 0;
    var skipped = 0;
    try {
      for (final recipe in _starterRecipes) {
        if (existingNames.contains(recipe.name.toLowerCase())) {
          skipped++;
          continue;
        }
        final saved = await widget.repository.saveProduct(
          recipe.toProduct().toJson(),
        );
        if (!mounted) return;
        setState(() => _products.add(_Product.fromJson(saved)));
        existingNames.add(recipe.name.toLowerCase());
        added++;
      }
    } catch (error) {
      await _loadProducts();
      if (!mounted) return;
      setState(() => _isImportingRecipes = false);
      _showMessage('Impor berhenti setelah menambahkan $added resep: $error');
      return;
    }

    if (!mounted) return;
    setState(() => _isImportingRecipes = false);
    if (added == 0) {
      _showMessage('Semua resep sudah ada. Tidak ada data yang diubah.');
    } else if (skipped > 0) {
      _showMessage('$added resep ditambahkan, $skipped resep dilewati.');
    } else {
      _showMessage('$added resep berhasil ditambahkan.');
    }
  }

  Future<void> _showRecipe(_Product product) async {
    List<_RecipeMaterial> materials;
    try {
      materials = (await widget.repository.getMaterials())
          .map(_RecipeMaterial.fromJson)
          .toList();
    } catch (error) {
      if (mounted) _showMessage('Daftar bahan baku gagal dimuat: $error');
      return;
    }
    if (!mounted) return;
    final materialsById = {for (final item in materials) item.id: item};
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Hasil jadi: ${product.recipeYield ?? '-'}'),
              const SizedBox(height: 12),
              const Text(
                'Bahan',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              if (product.ingredients.isEmpty && product.recipeItems.isEmpty)
                const Text('Detail resep belum tersedia.')
              else if (product.ingredients.isNotEmpty)
                for (final ingredient in product.ingredients)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('- $ingredient'),
                  ),
              if (product.recipeItems.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final ingredient in product.recipeItems)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '- ${materialsById[ingredient.materialId]?.name ?? 'Bahan tidak ditemukan'}: '
                      '${_formatRecipeQuantity(ingredient.quantity)} '
                      '${ingredient.unit ?? materialsById[ingredient.materialId]?.unit ?? ''}',
                    ),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _deleteProduct(_Product product, {bool confirm = true}) async {
    if (confirm) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Hapus produk?'),
          content: Text('Data ${product.name} akan dihapus.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Hapus'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return false;
    }
    try {
      if (product.id != null) {
        await widget.repository.deleteProduct(product.id!);
      }
      if (!mounted) return false;
      setState(() => _products.remove(product));
      return true;
    } catch (error) {
      if (mounted) _showMessage('Produk gagal dihapus: $error');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = _visibleProducts;
    return Scaffold(
      backgroundColor: _page,
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 11, 13, 6),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Produk Keripik',
                            style: TextStyle(
                              color: _green,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Kelola kuota batch & ketersediaan display',
                            style: TextStyle(
                              color: Color(0xFF555E53),
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDF3DE),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${_products.length} Varian Aktif',
                        style: const TextStyle(
                          color: _green,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  height: 37,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Cari nama produk...',
                      hintStyle: const TextStyle(fontSize: 10),
                      prefixIcon: const Icon(Icons.search, size: 17),
                      suffixIcon: const Icon(Icons.tune, size: 15),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.zero,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(99),
                        borderSide: const BorderSide(color: Color(0xFFE1E5DC)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(99),
                        borderSide: const BorderSide(color: Color(0xFF7E9B78)),
                      ),
                    ),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: TextButton.icon(
                    key: const ValueKey('import-starter-recipes'),
                    onPressed: _isImportingRecipes ? null : _importRecipes,
                    icon: _isImportingRecipes
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined, size: 16),
                    label: Text(
                      _isImportingRecipes ? 'Mengimpor...' : 'Impor 5 Resep',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 5),
                  scrollDirection: Axis.horizontal,
                  children: ['Semua', 'Ubi Ungu', 'Ubi Cilembu', 'Singkong']
                      .map((category) {
                        final selected = _category == category;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(category),
                            selected: selected,
                            showCheckmark: false,
                            onSelected: (_) => setState(() {
                              _category = selected ? 'Semua' : category;
                            }),
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : _ink,
                              fontSize: 9,
                            ),
                            backgroundColor: Colors.white,
                            selectedColor: _green,
                            side: BorderSide(
                              color: selected
                                  ? _green
                                  : const Color(0xFFE1E5DC),
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                        );
                      })
                      .toList(),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _loadError != null
                    ? Center(child: Text(_loadError!))
                    : products.isEmpty
                    ? Center(
                        child: Text(
                          _products.isEmpty
                              ? 'Belum ada produk. Tekan Tambah Produk untuk memulai.'
                              : 'Produk tidak ditemukan',
                          style: TextStyle(
                            color: Color(0xFF687164),
                            fontSize: 12,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 1, 12, 90),
                        itemCount: products.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _ProductCard(
                            product: products[index],
                            id: _products.indexOf(products[index]),
                            onRecipe: () => _showRecipe(products[index]),
                            onEdit: () =>
                                _showProductForm(product: products[index]),
                            onDelete: () => _deleteProduct(products[index]),
                            onStartBatch: widget.onStartBatch,
                          ),
                        ),
                      ),
              ),
            ],
          ),
          Positioned(
            right: 13,
            bottom: 16,
            child: FloatingActionButton.extended(
              heroTag: 'add-product',
              onPressed: () => _showProductForm(),
              backgroundColor: _amber,
              foregroundColor: const Color(0xFF3F3300),
              elevation: 4,
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'Tambah Produk',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductFormScreen extends StatefulWidget {
  const _ProductFormScreen({
    required this.materials,
    this.product,
    this.onDelete,
  });

  final List<_RecipeMaterial> materials;
  final _Product? product;
  final Future<bool> Function()? onDelete;

  @override
  State<_ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<_ProductFormScreen> {
  static const _categories = [
    'Aneka Keripik',
    'Keripik Manis',
    'Keripik Gurih',
  ];
  static const _maximumPhotoBytes = 5 * 1024 * 1024;
  final _imagePicker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _batchController;
  late final TextEditingController _recipeYieldKgController;
  late final TextEditingController _weightPerPieceGramController;
  final Map<String, String> _quantityControllers = {};
  final Map<String, String> _quantityUnits = {};
  late String _category;
  late List<String> _ingredients;
  late List<_ProductRecipeItem> _recipeItems;
  Uint8List? _photoBytes;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _batchController = TextEditingController(
      text: product?.batchLimit.toString() ?? '0',
    );
    _recipeYieldKgController = TextEditingController(
      text: product?.recipeYieldKg?.toString() ?? '',
    );
    _weightPerPieceGramController = TextEditingController(
      text: product?.weightPerPieceGram?.toString() ?? '',
    );
    _category = _categories.contains(product?.category)
        ? product!.category
        : 'Aneka Keripik';
    _ingredients = List<String>.of(product?.ingredients ?? const []);
    _recipeItems = List<_ProductRecipeItem>.of(
      product?.recipeItems ?? const [],
    );
    for (final item in _recipeItems) {
      _quantityControllers[item.materialId] = _formatRecipeQuantity(
        item.quantity,
      );
      final material = widget.materials.where(
        (candidate) => candidate.id == item.materialId,
      );
      _quantityUnits[item.materialId] =
          item.unit ?? (material.isEmpty ? 'Kg' : material.first.unit);
    }
    _photoBytes = product?.photoBytes;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _batchController.dispose();
    _recipeYieldKgController.dispose();
    _weightPerPieceGramController.dispose();
    super.dispose();
  }

  int get _batchLimit => int.tryParse(_batchController.text.trim()) ?? 0;

  String? _validateBatch(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    return number == null || number <= 0
        ? 'Masukkan batas batch lebih dari 0'
        : null;
  }

  void _changeBatch(int change) {
    final value = (_batchLimit + change).clamp(0, 999999);
    final text = value.toString();
    _batchController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  String? _validateRecipeQuantity(String? value) {
    final quantity = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
    return quantity == null || !quantity.isFinite || quantity <= 0
        ? 'Masukkan jumlah lebih dari 0'
        : null;
  }

  String? _validatePositiveWeight(String? value, String label) {
    final text = (value ?? '').trim().replaceAll(',', '.');
    if (text.isEmpty && _recipeItems.isEmpty) return null;
    final quantity = double.tryParse(text);
    return quantity == null || !quantity.isFinite || quantity <= 0
        ? 'Masukkan $label lebih dari 0'
        : null;
  }

  Future<void> _selectPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Ambil foto dengan kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > _maximumPhotoBytes) {
        _showMessage('Ukuran foto maksimal 5 MB.');
        return;
      }
      setState(() => _photoBytes = bytes);
    } on PlatformException catch (error) {
      if (!mounted) return;
      _showMessage('Foto tidak dapat dipilih: ${error.message ?? error.code}');
    }
  }

  Future<void> _addIngredient() async {
    if (widget.materials.isEmpty) {
      _showMessage('Tambahkan bahan baku terlebih dahulu.');
      return;
    }
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (context) {
        final draft = _recipeItems
            .map((ingredient) => ingredient.materialId)
            .toSet();
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Pilih Bahan Utama'),
            content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final ingredient in widget.materials)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(ingredient.name),
                        subtitle: Text(
                          'Stok ${_formatRecipeQuantity(ingredient.quantity)} '
                          '${ingredient.unit}',
                        ),
                        value: draft.contains(ingredient.id),
                        onChanged: (selected) {
                          setDialogState(() {
                            if (selected == true) {
                              draft.add(ingredient.id);
                            } else {
                              draft.remove(ingredient.id);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, draft),
                child: const Text('Pilih'),
              ),
            ],
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    setState(() {
      _recipeItems = [
        for (final material in widget.materials)
          if (selected.contains(material.id))
            _recipeItems.firstWhere(
              (item) => item.materialId == material.id,
              orElse: () => _ProductRecipeItem(
                materialId: material.id,
                quantity: 0,
                unit: material.unit,
              ),
            ),
      ];
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmDelete() async {
    final product = widget.product;
    if (product == null || widget.onDelete == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus produk?'),
        content: Text('Data ${product.name} akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (await widget.onDelete!() && mounted) Navigator.pop(context);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _Product(
        id: widget.product?.id,
        name: _nameController.text.trim(),
        category: _category,
        batchLimit: _batchLimit,
        stock: widget.product?.stock ?? 0,
        image: widget.product?.image ?? 'assets/produk-ubi.png',
        photoBytes: _photoBytes,
        ingredients: _ingredients,
        recipeYield: widget.product?.recipeYield,
        recipeYieldKg: _parseOptionalQuantity(_recipeYieldKgController.text),
        weightPerPieceGram: _parseOptionalQuantity(
          _weightPerPieceGramController.text,
        ),
        recipeItems: [
          for (final item in _recipeItems)
            _ProductRecipeItem(
              materialId: item.materialId,
              quantity: double.parse(
                _recipeQuantity(item.materialId).replaceAll(',', '.'),
              ),
              unit: _recipeUnit(item.materialId),
            ),
        ],
      ),
    );
  }

  String _recipeQuantity(String materialId) =>
      _quantityControllers[materialId] ??
      _formatRecipeQuantity(
        _recipeItems
            .firstWhere((item) => item.materialId == materialId)
            .quantity,
      );

  String _recipeUnit(String materialId) {
    final unit =
        _quantityUnits[materialId] ??
        _recipeItems.firstWhere((item) => item.materialId == materialId).unit ??
        widget.materials
            .firstWhere((material) => material.id == materialId)
            .unit;
    switch (unit.trim().toLowerCase()) {
      case 'kg':
      case 'kilogram':
        return 'Kg';
      case 'g':
      case 'gram':
        return 'Gram';
      case 'l':
      case 'liter':
      case 'litre':
        return 'Liter';
      case 'ml':
      case 'milliliter':
      case 'millilitre':
        return 'mL';
      default:
        return unit;
    }
  }

  double? _parseOptionalQuantity(String value) {
    final text = value.trim().replaceAll(',', '.');
    return text.isEmpty ? null : double.parse(text);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;
    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                _buildHeader(isEditing),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      child: Container(
                        padding: EdgeInsets.fromLTRB(
                          isEditing ? 18 : 20,
                          isEditing ? 18 : 20,
                          isEditing ? 18 : 20,
                          isEditing ? 18 : 22,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: const Color(0xFFE4E8DE)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (isEditing) ...[
                              _buildEditPhotoPicker(),
                              const SizedBox(height: 24),
                              _buildLabel('Nama Roti', required: true),
                              const SizedBox(height: 8),
                              _buildNameField(isEditing: true),
                              const SizedBox(height: 24),
                              _buildLabel('Kategori Roti', required: true),
                              const SizedBox(height: 8),
                              _buildCategoryField(),
                              const SizedBox(height: 24),
                              _buildEditBatchLimit(),
                              const SizedBox(height: 18),
                              _buildEditStock(),
                            ] else ...[
                              _buildPhotoPicker(),
                              const SizedBox(height: 22),
                              _buildLabel('Nama Produk', required: true),
                              const SizedBox(height: 10),
                              _buildNameField(),
                              const SizedBox(height: 22),
                              _buildLabel('Kategori Roti', required: true),
                              const SizedBox(height: 10),
                              _buildCategoryField(),
                              const SizedBox(height: 26),
                              _buildBatchLimit(),
                            ],
                            const SizedBox(height: 28),
                            _buildIngredients(),
                            const SizedBox(height: 24),
                            _buildRecipeOutputSettings(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _buildFooter(isEditing),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isEditing) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE9EBE4))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            tooltip: 'Kembali',
            icon: const Icon(Icons.arrow_back, size: 23),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'Edit Produk' : 'Tambah Produk',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text(
                  'Katalog Produk Toko & Dapur',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0xFF596054), fontSize: 12),
                ),
              ],
            ),
          ),
          if (isEditing)
            IconButton(
              onPressed: _confirmDelete,
              tooltip: 'Hapus produk',
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFFFEFED),
                foregroundColor: const Color(0xFFCC1616),
              ),
              icon: const Icon(Icons.delete_outline, size: 23),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE0AE),
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Text(
                'PRODUK BARU',
                style: TextStyle(
                  color: Color(0xFF593D00),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditPhotoPicker() {
    final product = widget.product!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Foto Produk',
          style: TextStyle(
            color: Color(0xFF485047),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _selectPhoto,
          child: SizedBox(
            height: 208,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_photoBytes != null)
                    Image.memory(_photoBytes!, fit: BoxFit.cover)
                  else
                    Image.asset(
                      product.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: const Color(0xFFE6EEE0),
                        child: const Icon(
                          Icons.local_cafe,
                          color: _green,
                          size: 42,
                        ),
                      ),
                    ),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xD9000000),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Text(
                        'JPG • 1.2 MB',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: FilledButton.icon(
                      onPressed: _selectPhoto,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _green,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                      ),
                      icon: const Icon(Icons.camera_alt_outlined, size: 15),
                      label: const Text(
                        'Ganti Foto',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.photo_camera_back_outlined,
              color: _green,
              size: 18,
            ),
            const SizedBox(width: 7),
            const Expanded(
              child: Text(
                'Foto Produk',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              'Rasio 1:1 • Maks 5MB',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: _selectPhoto,
          borderRadius: BorderRadius.circular(34),
          child: CustomPaint(
            painter: _DashedRoundedBorder(
              color: const Color(0xFFBECAB8),
              radius: 34,
            ),
            child: Container(
              height: 164,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5EF),
                borderRadius: BorderRadius.circular(34),
              ),
              child: _photoBytes == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 62,
                          height: 62,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt_outlined,
                            color: _green,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Unggah Foto Produk',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Ketuk untuk memilih foto atau ambil kamera',
                          style: TextStyle(
                            color: Color(0xFF596054),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Image.memory(
                        _photoBytes!,
                        width: double.infinity,
                        height: 164,
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text, {bool required = false}) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: _ink,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        children: [
          TextSpan(text: text),
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFD52B24)),
            ),
        ],
      ),
    );
  }

  Widget _buildNameField({bool isEditing = false}) {
    return TextFormField(
      key: const ValueKey('product-name'),
      controller: _nameController,
      textCapitalization: TextCapitalization.words,
      decoration: _fieldDecoration(hintText: 'Contoh: Keripik Ubi Unggu Madu')
          .copyWith(
            suffixIcon: isEditing
                ? const Icon(Icons.edit_outlined, color: Color(0xFF485047))
                : null,
          ),
      validator: (value) =>
          value?.trim().isNotEmpty == true ? null : 'Nama produk wajib diisi',
    );
  }

  Widget _buildCategoryField() {
    return DropdownButtonFormField<String>(
      initialValue: _category,
      decoration: _fieldDecoration(),
      icon: const Icon(Icons.keyboard_arrow_down),
      items: [
        for (final category in _categories)
          DropdownMenuItem(value: category, child: Text(category)),
      ],
      onChanged: (value) {
        if (value != null) setState(() => _category = value);
      },
    );
  }

  InputDecoration _fieldDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(99),
        borderSide: const BorderSide(color: Color(0xFFC7D0C1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(99),
        borderSide: const BorderSide(color: _green, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFB3261E)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFB3261E)),
      ),
    );
  }

  Widget _buildBatchLimit() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5EF),
        border: Border.all(color: const Color(0xFFE4E6DD)),
        borderRadius: BorderRadius.circular(35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune, color: Color(0xFF926400), size: 17),
              SizedBox(width: 5),
              Text(
                'Batas Batch Harian',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFC7D0C1)),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _changeBatch(-1)),
                  tooltip: 'Kurangi batch',
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: TextFormField(
                    key: const ValueKey('product-batch-limit'),
                    controller: _batchController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      color: _green,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      suffixText: ' batch',
                      suffixStyle: TextStyle(
                        color: _ink,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    validator: _validateBatch,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _changeBatch(1)),
                  tooltip: 'Tambah batch',
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditBatchLimit() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4EF),
        border: Border.all(color: const Color(0xFFE4E6DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Batas Batch',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.calendar_month_outlined, color: Color(0xFF926400)),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            height: 51,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFC7D0C1)),
            ),
            alignment: Alignment.centerLeft,
            child: TextFormField(
              key: const ValueKey('product-batch-limit'),
              controller: _batchController,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                color: _ink,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                suffixText: 'batch',
                suffixStyle: TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              validator: _validateBatch,
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF926400), size: 14),
              SizedBox(width: 5),
              Flexible(
                child: Text(
                  'Kapasitas maksimal penggorengan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0xFF596054), fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditStock() {
    final stock = widget.product!.stock;
    final available = stock > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4EF),
        border: Border.all(color: const Color(0xFFE4E6DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Stok Siap Display',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: available
                      ? const Color(0xFFE7F5E9)
                      : const Color(0xFFFFF1DE),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  available ? '● Tersedia' : '● Habis',
                  style: TextStyle(
                    color: available
                        ? const Color(0xFF12672C)
                        : const Color(0xFFE77A00),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            height: 51,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFC7D0C1)),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              '$stock pcs',
              style: const TextStyle(
                color: _ink,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Etalase Utama Dapur Depan',
            style: TextStyle(color: Color(0xFF596054), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredients() {
    final materialsById = {for (final item in widget.materials) item.id: item};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.grain, color: Color(0xFF926400), size: 17),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Kebutuhan Bahan Utama',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '(Opsional)',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        if (widget.materials.isEmpty)
          const Text(
            'Tambahkan bahan baku terlebih dahulu agar dapat disusun resepnya.',
            style: TextStyle(color: Color(0xFF687164), fontSize: 12),
          )
        else
          for (final ingredient in _recipeItems) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      materialsById[ingredient.materialId]?.name ??
                          'Bahan tidak ditemukan',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: TextFormField(
                      key: ValueKey('recipe-quantity-${ingredient.materialId}'),
                      initialValue: _recipeQuantity(ingredient.materialId),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Takaran',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateRecipeQuantity,
                      onChanged: (value) =>
                          _quantityControllers[ingredient.materialId] = value,
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 85,
                    child: DropdownButton<String>(
                      key: ValueKey('recipe-unit-${ingredient.materialId}'),
                      value: _recipeUnit(ingredient.materialId),
                      isExpanded: true,
                      items: [
                        for (final unit in recipeUnitsForInventory(
                          materialsById[ingredient.materialId]?.unit ?? 'Kg',
                        ))
                          DropdownMenuItem(
                            value: unit,
                            child: Text(
                              unit,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (unit) {
                        if (unit != null) {
                          setState(
                            () => _quantityUnits[ingredient.materialId] = unit,
                          );
                        }
                      },
                    ),
                  ),
                  IconButton(
                    tooltip:
                        'Hapus ${materialsById[ingredient.materialId]?.name ?? 'bahan'}',
                    onPressed: () => setState(() {
                      _recipeItems.removeWhere(
                        (item) => item.materialId == ingredient.materialId,
                      );
                    }),
                    icon: const Icon(Icons.close, size: 17),
                  ),
                ],
              ),
            ),
          ],
        ActionChip(
          avatar: const Icon(Icons.add, color: _green, size: 17),
          label: const Text('Tambah Bahan'),
          onPressed: _addIngredient,
          backgroundColor: Colors.white,
          side: const BorderSide(color: _green, style: BorderStyle.solid),
          labelStyle: const TextStyle(
            color: _green,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildRecipeOutputSettings() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5EF),
        border: Border.all(color: const Color(0xFFE4E6DD)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Patokan hasil resep',
            style: TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pemakaian bahan mengikuti (jumlah pcs x gram per pcs) / hasil resep penuh (gram).',
            style: TextStyle(color: Color(0xFF596054), fontSize: 11),
          ),
          const SizedBox(height: 14),
          TextFormField(
            key: const ValueKey('product-recipe-yield-kg'),
            controller: _recipeYieldKgController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _fieldDecoration(
              hintText: 'Contoh: 2,75',
            ).copyWith(labelText: 'Hasil satu resep penuh', suffixText: 'kg'),
            validator: (value) =>
                _validatePositiveWeight(value, 'hasil resep dalam kg'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('product-weight-per-piece-gram'),
            controller: _weightPerPieceGramController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _fieldDecoration(
              hintText: 'Contoh: 100',
            ).copyWith(labelText: 'Berat per pcs/kemasan', suffixText: 'gram'),
            validator: (value) =>
                _validatePositiveWeight(value, 'berat per pcs dalam gram'),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isEditing) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        isEditing ? 20 : 16,
        isEditing ? 10 : 12,
        isEditing ? 20 : 16,
        isEditing ? 6 : 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x12000000),
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
            height: isEditing ? 60 : 58,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_circle_outline, size: 21),
              label: Text(
                isEditing ? 'Simpan Perubahan' : 'Simpan Produk',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF176126),
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
            ),
          ),
          SizedBox(height: isEditing ? 5 : 10),
          SizedBox(
            width: double.infinity,
            height: isEditing ? 50 : 50,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: _ink,
                side: const BorderSide(color: Color(0xFF899184)),
                shape: const StadiumBorder(),
              ),
              child: const Text('Batal', style: TextStyle(fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.id,
    required this.onRecipe,
    required this.onEdit,
    required this.onDelete,
    required this.onStartBatch,
  });

  final _Product product;
  final int id;
  final VoidCallback onRecipe;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onStartBatch;

  @override
  Widget build(BuildContext context) {
    final lowStock = product.stock <= product.batchLimit * 0.4;
    final statusColor = lowStock
        ? const Color(0xFFE77A00)
        : const Color(0xFF12672C);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: lowStock ? const Color(0xFFFFD7A3) : const Color(0xFFE8EBE5),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x09000000),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: lowStock
                  ? const Color(0xFFFFF1DE)
                  : const Color(0xFFE7F5E9),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              lowStock ? '● Menipis' : '● Tersedia',
              style: TextStyle(
                color: statusColor,
                fontSize: 7,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: product.photoBytes == null
                    ? Image.asset(
                        product.image,
                        width: 33,
                        height: 33,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _fallbackProductImage(),
                      )
                    : Image.memory(
                        product.photoBytes!,
                        width: 33,
                        height: 33,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _fallbackProductImage(),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F1ED),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            'ID: $id',
                            style: const TextStyle(fontSize: 7),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Kategori: ${product.category}',
                      style: const TextStyle(
                        color: Color(0xFF626A5F),
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Container(
            height: 39,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F4EF),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ProductMetric(
                    title: 'Batas Batch',
                    amount: product.batchLimit,
                    unit: 'batch',
                    color: _green,
                  ),
                ),
                Container(width: 1, height: 24, color: const Color(0xFFE3E4DE)),
                Expanded(
                  child: _ProductMetric(
                    title: 'Stok Siap',
                    amount: product.stock,
                    unit: 'pcs',
                    color: lowStock ? const Color(0xFFE77A00) : _ink,
                  ),
                ),
              ],
            ),
          ),
          if (lowStock)
            InkWell(
              onTap: onStartBatch,
              child: const Padding(
                padding: EdgeInsets.only(top: 5),
                child: Row(
                  children: [
                    Icon(Icons.assignment_outlined, color: _green, size: 11),
                    SizedBox(width: 4),
                    Text(
                      'Halaman Produksi',
                      style: TextStyle(color: _green, fontSize: 8),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _ProductAction(
                label: 'Resep',
                icon: Icons.receipt_long_outlined,
                onTap: onRecipe,
              ),
              const SizedBox(width: 6),
              _ProductAction(
                label: 'Edit',
                icon: Icons.edit_outlined,
                onTap: onEdit,
              ),
              const SizedBox(width: 6),
              _ProductAction(
                label: 'Hapus',
                icon: Icons.delete_outline,
                onTap: onDelete,
                destructive: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductMetric extends StatelessWidget {
  const _ProductMetric({
    required this.title,
    required this.amount,
    required this.unit,
    required this.color,
  });

  final String title;
  final int amount;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title, style: const TextStyle(fontSize: 7)),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$amount',
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 3),
            Text(unit, style: const TextStyle(fontSize: 8)),
          ],
        ),
      ],
    );
  }
}

class _ProductAction extends StatelessWidget {
  const _ProductAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final foreground = destructive ? const Color(0xFFB71920) : _ink;
    return SizedBox(
      height: 25,
      child: FilledButton.tonalIcon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: destructive
              ? const Color(0xFFFFE5E3)
              : const Color(0xFFEFF0EC),
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          visualDensity: VisualDensity.compact,
        ),
        icon: Icon(icon, size: 11),
        label: Text(label, style: const TextStyle(fontSize: 8)),
      ),
    );
  }
}

class _Product {
  _Product({
    this.id,
    required this.name,
    required this.category,
    required this.batchLimit,
    required this.stock,
    required this.image,
    this.photoBytes,
    this.ingredients = const [],
    this.recipeYield,
    this.recipeYieldKg,
    this.weightPerPieceGram,
    this.recipeItems = const [],
  });

  final String? id;
  final String name;
  final String category;
  final int batchLimit;
  int stock;
  final String image;
  final Uint8List? photoBytes;
  final List<String> ingredients;
  final String? recipeYield;
  final double? recipeYieldKg;
  final double? weightPerPieceGram;
  final List<_ProductRecipeItem> recipeItems;

  factory _Product.fromJson(Map<String, dynamic> json) {
    final photoBase64 = json['photo_base64'] as String?;
    return _Product(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'Aneka Keripik',
      batchLimit: (json['batch_limit'] as num?)?.toInt() ?? 0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      image: json['image'] as String? ?? 'assets/produk-ubi.png',
      photoBytes: photoBase64 == null ? null : base64Decode(photoBase64),
      ingredients: List<String>.from(json['ingredients'] as List? ?? const []),
      recipeYield: json['recipe_yield'] as String?,
      recipeYieldKg: (json['recipe_yield_kg'] as num?)?.toDouble(),
      weightPerPieceGram: (json['weight_per_piece_gram'] as num?)?.toDouble(),
      recipeItems: (json['recipe_items'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                _ProductRecipeItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'name': name,
    'category': category,
    'batch_limit': batchLimit,
    'stock': stock,
    'image': image,
    'photo_base64': photoBytes == null ? null : base64Encode(photoBytes!),
    'ingredients': ingredients,
    'recipe_yield': recipeYield,
    'recipe_yield_kg': recipeYieldKg,
    'weight_per_piece_gram': weightPerPieceGram,
    'recipe_items': recipeItems.map((item) => item.toJson()).toList(),
  };
}

class _ProductRecipeItem {
  const _ProductRecipeItem({
    required this.materialId,
    required this.quantity,
    this.unit,
  });

  final String materialId;
  final double quantity;
  final String? unit;

  factory _ProductRecipeItem.fromJson(Map<String, dynamic> json) =>
      _ProductRecipeItem(
        materialId: json['material_id'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        unit: json['unit'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'material_id': materialId,
    'quantity': quantity,
    if (unit != null) 'unit': unit,
  };
}

class _RecipeMaterial {
  const _RecipeMaterial({
    required this.id,
    required this.name,
    required this.unit,
    required this.quantity,
    required this.useInRecipes,
  });

  final String id;
  final String name;
  final String unit;
  final double quantity;
  final bool useInRecipes;

  factory _RecipeMaterial.fromJson(Map<String, dynamic> json) =>
      _RecipeMaterial(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        unit: json['unit'] as String? ?? 'Kg',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        useInRecipes: json['use_in_recipes'] as bool? ?? true,
      );
}

String _formatRecipeQuantity(double quantity) =>
    quantity == quantity.roundToDouble()
    ? quantity.toInt().toString()
    : quantity.toString();

class _Recipe {
  const _Recipe({
    required this.name,
    required this.category,
    required this.recipeYield,
    required this.ingredients,
    this.recipeYieldKg,
  });

  final String name;
  final String category;
  final String recipeYield;
  final List<String> ingredients;
  final double? recipeYieldKg;

  _Product toProduct() => _Product(
    name: name,
    category: category,
    batchLimit: 1,
    stock: 0,
    image: 'assets/produk-ubi.png',
    ingredients: ingredients,
    recipeYield: recipeYield,
    recipeYieldKg: recipeYieldKg,
  );
}

Widget _fallbackProductImage() {
  return Container(
    width: 33,
    height: 33,
    color: const Color(0xFFE6EEE0),
    child: const Icon(Icons.local_cafe, color: _green, size: 18),
  );
}

class _DashedRoundedBorder extends CustomPainter {
  const _DashedRoundedBorder({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += 12) {
        final end = distance + 7 < metric.length ? distance + 7 : metric.length;
        canvas.drawPath(metric.extractPath(distance, end), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRoundedBorder oldDelegate) =>
      color != oldDelegate.color || radius != oldDelegate.radius;
}
