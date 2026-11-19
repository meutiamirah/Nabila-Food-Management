import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nabila_food/data/app_repository.dart';

const _green = Color(0xFF07551C);
const _ink = Color(0xFF202720);
const _page = Color(0xFFF8F9F3);
const _amber = Color(0xFFFFB900);
const _productionLocations = [
  'Area Penggorengan',
  'Area Penirisan',
  'Area Pengemasan',
];

class ProduksiScreen extends StatefulWidget {
  const ProduksiScreen({
    super.key,
    required this.repository,
    this.onStockChanged,
  });

  final AppRepository repository;
  final VoidCallback? onStockChanged;

  @override
  State<ProduksiScreen> createState() => _ProduksiScreenState();
}

class _ProduksiScreenState extends State<ProduksiScreen> {
  static final _initialDate = DateTime.now();
  final List<_ProductionBatch> _batches = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    try {
      final rows = await widget.repository.getProductionBatches();
      if (!mounted) return;
      setState(() {
        _batches
          ..clear()
          ..addAll(rows.map(_ProductionBatch.fromJson));
        _isLoading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Data produksi gagal dimuat: $error';
      });
    }
  }

  DateTime _selectedDate = _initialDate;
  String _statusFilter = 'Semua';
  bool _sortDescending = false;

  List<_ProductionBatch> get _visibleBatches {
    final batches = _batches.where((batch) {
      if (_statusFilter == 'Normal') return !batch.isOverTarget;
      if (_statusFilter == 'Melebihi target') return batch.isOverTarget;
      return true;
    }).toList();
    batches.sort(
      (a, b) => _sortDescending
          ? b.produced.compareTo(a.produced)
          : a.id.compareTo(b.id),
    );
    return batches;
  }

  String get _formattedDate {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${_selectedDate.day} ${months[_selectedDate.month - 1]} ${_selectedDate.year}';
  }

  String get _compactDate =>
      '${_selectedDate.day.toString().padLeft(2, '0')}-'
      '${_selectedDate.month.toString().padLeft(2, '0')}-'
      '${_selectedDate.year}';

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (selected != null) setState(() => _selectedDate = selected);
  }

  void _shiftDate(int days) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: days)));
  }

  Future<void> _showFilter() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Filter Produksi',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            for (final option in ['Semua', 'Normal', 'Melebihi target'])
              ListTile(
                title: Text(option),
                leading: Icon(
                  _statusFilter == option
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: _statusFilter == option ? _green : null,
                  size: 20,
                ),
                onTap: () => Navigator.pop(context, option),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null) setState(() => _statusFilter = selected);
  }

  Future<void> _editBatch([_ProductionBatch? batch]) async {
    final productionDate = batch?.producedOn ?? _selectedDate;
    var products = <_ProductionProduct>[];
    var materials = <_ProductionMaterial>[];
    try {
      final productRows = await widget.repository.getProducts();
      final materialRows = await widget.repository.getMaterials();
      products = productRows
          .map(_ProductionProduct.fromJson)
          .where((product) => product.recipeItems.isNotEmpty)
          .toList();
      materials = materialRows.map(_ProductionMaterial.fromJson).toList();
    } catch (error) {
      if (mounted) _showMessage('Resep dan stok bahan gagal dimuat: $error');
      return;
    }
    if (!mounted) return;
    final usedBatchCountsByProduct = <String, int>{};
    final usedLocations = <String>{};
    for (final existing in _batches) {
      if (!_isSameDate(existing.producedOn, productionDate) ||
          identical(existing, batch)) {
        continue;
      }
      if (existing.productId != null) {
        usedBatchCountsByProduct.update(
          existing.productId!,
          (count) => count + existing.batchCount,
          ifAbsent: () => existing.batchCount,
        );
      }
      if (existing.station.isNotEmpty) usedLocations.add(existing.station);
    }
    final result = await Navigator.of(context).push<_ProductionBatch>(
      MaterialPageRoute<_ProductionBatch>(
        builder: (_) => _ProductionFormScreen(
          batch: batch,
          products: products,
          materials: materials,
          productionDate: productionDate,
          usedBatchCountsByProduct: usedBatchCountsByProduct,
          usedLocations: usedLocations,
        ),
      ),
    );
    if (result == null || !mounted) return;
    if (batch == null) {
      if (result.productId != null) {
        final product = products.firstWhere(
          (item) => item.id == result.productId,
        );
        final batchesUsed = usedBatchCountsByProduct[product.id] ?? 0;
        if (batchesUsed + result.batchCount > product.batchLimit) {
          _showMessage(
            'Batas ${product.batchLimit} batch harian untuk ${product.name} '
            'sudah tercapai pada ${_formatProductionDate(productionDate)}.',
          );
          return;
        }
      }
      final nextId = (_batches.length + 1).toString().padLeft(2, '0');
      result.id = 'PRD-$nextId';
    } else {
      result
        ..id = batch.id
        ..dbId = batch.dbId;
    }
    try {
      final saved = _ProductionBatch.fromJson(
        await widget.repository.saveProductionBatch(result.toJson()),
      );
      if (!mounted) return;
      setState(() {
        if (batch == null) {
          _batches.add(saved);
        } else {
          final index = _batches.indexOf(batch);
          if (index != -1) _batches[index] = saved;
        }
      });
      if (result.productId != null) widget.onStockChanged?.call();
    } catch (error) {
      if (mounted) _showMessage('Data produksi gagal disimpan: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _deleteBatch(_ProductionBatch batch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus batch produksi?'),
        content: Text('Batch ${batch.id} • ${batch.name} akan dihapus.'),
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
    if (confirmed == true && mounted) {
      try {
        if (batch.dbId != null) {
          await widget.repository.deleteProductionBatch(batch.dbId!);
        }
        if (!mounted) return;
        setState(() => _batches.remove(batch));
        if (batch.productId != null || batch.materialUsage.isNotEmpty) {
          widget.onStockChanged?.call();
        }
      } catch (error) {
        if (mounted) _showMessage('Batch produksi gagal dihapus: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final batches = _visibleBatches;
    return Scaffold(
      backgroundColor: _page,
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 25, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'OPERASIONAL DAPUR',
                                style: TextStyle(
                                  color: Color(0xFF926400),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Produksi Harian',
                                style: TextStyle(
                                  color: _ink,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _pickDate,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFFF0F1ED),
                            foregroundColor: _ink,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 8,
                            ),
                            side: const BorderSide(color: Color(0xFFE4E6DD)),
                          ),
                          icon: const Icon(
                            Icons.calendar_month_outlined,
                            color: _green,
                            size: 15,
                          ),
                          label: Text(
                            _formattedDate,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        _DateChip(
                          label: 'Kemarin',
                          selected:
                              _selectedDate ==
                              _initialDate.subtract(const Duration(days: 1)),
                          onTap: () => _shiftDate(-1),
                        ),
                        const SizedBox(width: 7),
                        _DateChip(
                          label: 'Hari Ini',
                          selected: _selectedDate == _initialDate,
                          onTap: () =>
                              setState(() => _selectedDate = _initialDate),
                        ),
                        const SizedBox(width: 7),
                        _DateChip(
                          label: 'Besok',
                          selected:
                              _selectedDate ==
                              _initialDate.add(const Duration(days: 1)),
                          onTap: () => _shiftDate(1),
                        ),
                        const SizedBox(width: 7),
                        OutlinedButton.icon(
                          onPressed: _showFilter,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _statusFilter == 'Semua'
                                ? const Color(0xFFF4F4EF)
                                : const Color(0xFFE4F2E3),
                            foregroundColor: _ink,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                            side: const BorderSide(color: Color(0xFFE7E8E2)),
                          ),
                          icon: const Icon(Icons.tune, size: 14),
                          label: const Text(
                            'Filter',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 19),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Daftar Batch Produksi',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7E8E2),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '${batches.fold<int>(0, (total, batch) => total + batch.batchCount)} Batch',
                            style: const TextStyle(
                              color: Color(0xFF485047),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 11),
                        TextButton.icon(
                          onPressed: () => setState(
                            () => _sortDescending = !_sortDescending,
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: _green,
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.sort, size: 15),
                          label: const Text(
                            'Urutkan',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _loadError != null
                    ? Center(child: Text(_loadError!))
                    : batches.isEmpty
                    ? Center(
                        child: Text(
                          _batches.isEmpty
                              ? 'Belum ada batch produksi. Tekan Tambah Produksi untuk memulai.'
                              : 'Tidak ada batch sesuai filter.',
                          style: TextStyle(color: Color(0xFF596054)),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 78),
                        itemCount: batches.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 11),
                        itemBuilder: (context, index) => _ProductionCard(
                          batch: batches[index],
                          date: _compactDate,
                          onEdit: () => _editBatch(batches[index]),
                          onDelete: () => _deleteBatch(batches[index]),
                        ),
                      ),
              ),
            ],
          ),
          Positioned(
            right: 4,
            bottom: 10,
            child: FloatingActionButton.extended(
              heroTag: 'add-production',
              onPressed: () => _editBatch(),
              backgroundColor: _amber,
              foregroundColor: const Color(0xFF513900),
              elevation: 3,
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'Tambah Produksi',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 30,
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: selected ? _green : const Color(0xFFEFF0EC),
            foregroundColor: selected ? Colors.white : const Color(0xFF424A40),
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            shape: const StadiumBorder(),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _ProductionCard extends StatelessWidget {
  const _ProductionCard({
    required this.batch,
    required this.date,
    required this.onEdit,
    required this.onDelete,
  });

  final _ProductionBatch batch;
  final String date;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final over = batch.isOverTarget;
    final overAmount = batch.produced - batch.target;
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: over ? const Color(0xFFFFC533) : const Color(0xFFE8EBE5),
          width: over ? 1.3 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C192C16),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  batch.image,
                  width: 49,
                  height: 49,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 49,
                    height: 49,
                    color: const Color(0xFFE6EEE0),
                    child: const Icon(Icons.fastfood, color: _green),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '#${batch.id}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF555E53),
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        _StatusPill(over: over),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      batch.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${batch.station} • ${date.replaceAll(' ', '-')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF596054),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 42,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${batch.produced}',
                      style: TextStyle(
                        color: over ? const Color(0xFF926400) : _green,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      over ? '+$overAmount Over' : '${batch.batchCount} batch',
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        color: over
                            ? const Color(0xFF926400)
                            : const Color(0xFF485047),
                        fontSize: over ? 8 : 9,
                        fontWeight: over ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 9),
            child: Divider(height: 1, color: Color(0xFFEDEFEA)),
          ),
          Row(
            children: [
              Icon(
                over ? Icons.info_outline : Icons.check_circle_outline,
                color: over ? const Color(0xFF926400) : _green,
                size: 14,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  over
                      ? 'Melebihi kuota harian (+${((overAmount / batch.target) * 100).round()}%)'
                      : 'Target ${batch.target} tercapai',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: over
                        ? const Color(0xFF926400)
                        : const Color(0xFF485047),
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(
                height: 26,
                child: FilledButton.icon(
                  onPressed: onEdit,
                  style: FilledButton.styleFrom(
                    backgroundColor: over ? _amber : const Color(0xFFF0F1ED),
                    foregroundColor: _ink,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 13),
                  label: const Text('Edit', style: TextStyle(fontSize: 10)),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 29,
                height: 26,
                child: IconButton(
                  onPressed: onDelete,
                  tooltip: 'Hapus batch ${batch.id}',
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF1F0),
                    foregroundColor: const Color(0xFFD21B20),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.over});

  final bool over;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: over ? const Color(0xFFFFF6E5) : const Color(0xFFE7F5E9),
        borderRadius: BorderRadius.circular(99),
        border: over ? Border.all(color: const Color(0xFFFFC533)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            over ? Icons.warning_amber_rounded : Icons.circle,
            color: over ? const Color(0xFFFF9800) : _green,
            size: over ? 11 : 7,
          ),
          const SizedBox(width: 4),
          Text(
            over ? 'over' : 'normal',
            style: TextStyle(
              color: over ? const Color(0xFF926400) : _green,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductionFormScreen extends StatefulWidget {
  const _ProductionFormScreen({
    required this.batch,
    required this.products,
    required this.materials,
    required this.productionDate,
    required this.usedBatchCountsByProduct,
    required this.usedLocations,
  });

  final _ProductionBatch? batch;
  final List<_ProductionProduct> products;
  final List<_ProductionMaterial> materials;
  final DateTime productionDate;
  final Map<String, int> usedBatchCountsByProduct;
  final Set<String> usedLocations;

  @override
  State<_ProductionFormScreen> createState() => _ProductionFormScreenState();
}

class _ProductionFormScreenState extends State<_ProductionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  _ProductionProduct? _selectedProduct;
  String? _selectedLocation;
  int _batchCount = 1;

  @override
  void initState() {
    super.initState();
    final batch = widget.batch;
    _selectedLocation = batch?.station.isNotEmpty == true
        ? batch!.station
        : null;
    if (batch == null && widget.products.isNotEmpty) {
      _selectedProduct = widget.products.first;
    }
    for (final product in widget.products) {
      if (product.id == batch?.productId) {
        _selectedProduct = product;
        if (batch != null) _batchCount = batch.batchCount;
        break;
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildRecipeProductSelector() {
    return DropdownButtonFormField<String>(
      key: const ValueKey('production-product'),
      initialValue: _selectedProduct?.id,
      isExpanded: true,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'Pilih produk untuk memakai resep',
      ),
      items: [
        for (final product in widget.products)
          DropdownMenuItem(
            value: product.id,
            child: Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      validator: (value) => value == null ? 'Pilih produk resep' : null,
      onChanged: (id) {
        if (id == null) return;
        final product = widget.products.firstWhere((item) => item.id == id);
        setState(() {
          _selectedProduct = product;
          final available = _availableBatchCount(product);
          if (_batchCount > available && available > 0) {
            _batchCount = available;
          }
        });
      },
    );
  }

  Widget _buildLocationSelector() {
    final locations = _productionLocations.toSet();
    final selectedLocation = _selectedLocation;
    if (selectedLocation != null) locations.add(selectedLocation);
    final availableLocations = locations.where(
      (location) =>
          !widget.usedLocations.contains(location) ||
          location == selectedLocation,
    );
    return DropdownButtonFormField<String>(
      key: const ValueKey('production-station'),
      initialValue: _selectedLocation,
      isExpanded: true,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(99)),
        hintText: 'Pilih lokasi produksi',
        prefixIcon: const Icon(
          Icons.location_on_outlined,
          color: _green,
          size: 19,
        ),
      ),
      items: [
        for (final location in availableLocations)
          DropdownMenuItem(value: location, child: Text(location)),
      ],
      validator: (value) => value == null ? 'Pilih lokasi produksi' : null,
      onChanged: (value) => setState(() => _selectedLocation = value),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final selectedProduct = _selectedProduct;
    final pcsPerBatch = selectedProduct == null
        ? null
        : _pcsPerBatch(selectedProduct);
    if (selectedProduct == null ||
        selectedProduct.recipeYieldKg == null ||
        pcsPerBatch == null ||
        pcsPerBatch <= 0) {
      _showMessage(
        'Lengkapi hasil resep penuh (kg) dan berat per pcs (gram) di Produk.',
      );
      return;
    }
    if (_batchCount > _availableBatchCount(selectedProduct)) {
      _showMessage(
        'Batas ${selectedProduct.batchLimit} batch harian untuk '
        '${selectedProduct.name} sudah tercapai.',
      );
      return;
    }
    final produced = (pcsPerBatch * _batchCount).round();
    final original = widget.batch;
    Navigator.pop(
      context,
      _ProductionBatch(
        id: original?.id ?? '',
        dbId: original?.dbId,
        name: selectedProduct.name,
        produced: produced,
        target: produced,
        batchCount: _batchCount,
        station: _selectedLocation!,
        image: selectedProduct.image,
        photoBase64: original?.photoBase64,
        productId: selectedProduct.id,
        producedOn: original?.producedOn ?? widget.productionDate,
        materialUsage: original?.materialUsage ?? const [],
      ),
    );
  }

  int _availableBatchCount(_ProductionProduct product) =>
      (product.batchLimit - (widget.usedBatchCountsByProduct[product.id] ?? 0))
          .clamp(0, product.batchLimit)
          .toInt();

  int? _pcsPerBatch(_ProductionProduct product) {
    final yieldKg = product.recipeYieldKg;
    final weightGram = product.weightPerPieceGram;
    if (yieldKg == null ||
        weightGram == null ||
        yieldKg <= 0 ||
        weightGram <= 0) {
      return null;
    }
    return (yieldKg * 1000 / weightGram).round();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.batch != null;
    final product = _selectedProduct;
    final pcsPerBatch = product == null ? null : _pcsPerBatch(product);
    final totalKg = product?.recipeYieldKg == null
        ? 0.0
        : product!.recipeYieldKg! * _batchCount;
    final totalPcs = pcsPerBatch == null ? 0 : pcsPerBatch * _batchCount;
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (product != null) _buildProductSummary(product),
                          const SizedBox(height: 16),
                          _buildSectionTitle('Informasi Produksi'),
                          const SizedBox(height: 12),
                          _buildFieldLabel('Produk & Resep', required: true),
                          const SizedBox(height: 8),
                          _buildRecipeProductSelector(),
                          const SizedBox(height: 16),
                          _buildFieldLabel('Lokasi Produksi', required: true),
                          const SizedBox(height: 8),
                          _buildLocationSelector(),
                          const SizedBox(height: 18),
                          _buildBatchCounter(product),
                          const SizedBox(height: 16),
                          _buildSectionTitle('Ringkasan Produksi (Estimasi)'),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFE4E8DE),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildSummaryMetric(
                                        Icons.scale_outlined,
                                        'Total Hasil Produksi',
                                        '${_formatProductionQuantity(totalKg)} kg',
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildSummaryMetric(
                                        Icons.inventory_2_outlined,
                                        'Estimasi Produk Jadi',
                                        '$totalPcs pcs',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (product != null)
                                  _buildMaterialsForCount(product),
                              ],
                            ),
                          ),
                        ],
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

  Widget _buildProductSummary(_ProductionProduct product) {
    final pcsPerBatch = _pcsPerBatch(product);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE1E5DC)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: product.photoBytes == null
                ? Image.asset(
                    product.image,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder: _productImageError,
                  )
                : Image.memory(
                    product.photoBytes!,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder: _productImageError,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF126B35),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'Resep: ${_formatProductionQuantity(product.recipeYieldKg ?? 0)} kg',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildSummaryMini(
            Icons.scale_outlined,
            'Hasil Resep',
            '${_formatProductionQuantity(product.recipeYieldKg ?? 0)} kg',
          ),
          const SizedBox(width: 8),
          _buildSummaryMini(
            Icons.inventory_2_outlined,
            'Berat / pcs',
            '${_formatProductionQuantity(product.weightPerPieceGram ?? 0)} g',
          ),
          const SizedBox(width: 8),
          _buildSummaryMini(
            Icons.card_giftcard_outlined,
            'Estimasi',
            '${pcsPerBatch ?? 0} pcs',
          ),
        ],
      ),
    );
  }

  Widget _productImageError(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    return Container(
      width: 70,
      height: 70,
      color: const Color(0xFFF2F4EE),
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: _green),
    );
  }

  Widget _buildSummaryMini(IconData icon, String label, String value) {
    return SizedBox(
      width: 58,
      child: Column(
        children: [
          Icon(icon, color: _green, size: 18),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF596054), fontSize: 8),
          ),
          Text(
            value,
            style: const TextStyle(
              color: _ink,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchCounter(_ProductionProduct? product) {
    final maxCount = product?.batchLimit ?? 1;
    final usedCount = product == null
        ? 0
        : widget.usedBatchCountsByProduct[product.id] ?? 0;
    final effectiveMax = product == null ? 0 : _availableBatchCount(product);
    final totalUsed = usedCount + _batchCount;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E5DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.layers_outlined, color: _green, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Jumlah Batch *',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: const Color(0xFFC8D0C2)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _batchCount > 1
                          ? () => setState(() => _batchCount--)
                          : null,
                      icon: const Icon(Icons.remove, size: 18),
                      color: _green,
                    ),
                    Container(
                      width: 68,
                      alignment: Alignment.center,
                      child: Text(
                        '$_batchCount batch',
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _batchCount < effectiveMax
                          ? () => setState(() => _batchCount++)
                          : null,
                      icon: const Icon(Icons.add, size: 18),
                      color: _green,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: effectiveMax == 0 ? 0 : _batchCount / effectiveMax,
              minHeight: 7,
              backgroundColor: const Color(0xFFE4E8DF),
              color: _green,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Penggunaan hari ini: $totalUsed / $maxCount batch',
            style: const TextStyle(color: Color(0xFF596054), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: _green, size: 21),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Color(0xFF596054), fontSize: 9),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialsForCount(_ProductionProduct product) {
    final materialsById = {
      for (final material in widget.materials) material.id: material,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kebutuhan Bahan',
          style: TextStyle(
            color: _ink,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in product.recipeItems)
              Builder(
                builder: (_) {
                  final material = materialsById[item.materialId];
                  final quantity = item.quantity * _batchCount;
                  return Chip(
                    avatar: const Icon(
                      Icons.inventory_2_outlined,
                      size: 15,
                      color: _green,
                    ),
                    label: Text(
                      '${material?.name ?? 'Bahan'}  '
                      '${_formatProductionQuantity(quantity)} '
                      '${item.unit ?? material?.unit ?? ''}',
                      style: const TextStyle(fontSize: 10),
                    ),
                    side: const BorderSide(color: Color(0xFFE2E6DD)),
                    backgroundColor: const Color(0xFFF8F9F5),
                  );
                },
              ),
          ],
        ),
      ],
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
                  isEditing ? 'Edit Produksi' : 'Tambah Produksi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text(
                  'Operasional Dapur & Produksi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0xFF596054), fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE0AE),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              isEditing ? 'EDIT BATCH' : 'BATCH BARU',
              style: const TextStyle(
                color: Color(0xFF593D00),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _ink,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildFieldLabel(String label, {bool required = false}) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: _ink,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        children: [
          TextSpan(text: label),
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFD52B24)),
            ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isEditing) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
            height: 54,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: Text(
                isEditing ? 'Simpan Perubahan' : 'Simpan Produksi',
                style: const TextStyle(
                  fontSize: 14,
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
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: _ink,
                side: const BorderSide(color: Color(0xFFD7DFD4)),
                shape: const StadiumBorder(),
              ),
              child: const Text('Batal', style: TextStyle(fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductionBatch {
  _ProductionBatch({
    required this.id,
    this.dbId,
    required this.name,
    required this.produced,
    required this.target,
    this.batchCount = 1,
    required this.station,
    required this.image,
    required this.producedOn,
    this.photoBase64,
    this.productId,
    this.materialUsage = const [],
  });

  String id;
  String? dbId;
  final String name;
  final int produced;
  final int target;
  final int batchCount;
  final String station;
  final String image;
  final DateTime producedOn;
  final String? photoBase64;
  final String? productId;
  final List<Map<String, dynamic>> materialUsage;

  factory _ProductionBatch.fromJson(Map<String, dynamic> json) =>
      _ProductionBatch(
        id: json['batch_code'] as String? ?? '',
        dbId: json['id'] as String?,
        name: json['name'] as String? ?? '',
        batchCount: (json['batch_count'] as num?)?.toInt() ?? 1,
        produced: (json['produced'] as num?)?.toInt() ?? 0,
        target: (json['target'] as num?)?.toInt() ?? 0,
        station: json['station'] as String? ?? '',
        image: json['image'] as String? ?? 'assets/produk-ubi.png',
        producedOn:
            DateTime.tryParse(
              json['produced_on'] as String? ??
                  json['created_at'] as String? ??
                  '',
            ) ??
            DateTime.now(),
        photoBase64: json['photo_base64'] as String?,
        productId: json['product_id'] as String?,
        materialUsage: (json['material_usage'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    if (dbId != null) 'id': dbId,
    'batch_code': id,
    'batch_count': batchCount,
    'name': name,
    'produced': produced,
    'target': target,
    'station': station,
    'image': image,
    'produced_on': _productionDateKey(producedOn),
    'photo_base64': photoBase64,
    'product_id': productId,
    'material_usage': materialUsage,
  };

  bool get isOverTarget => produced > target;
}

class _ProductionProduct {
  const _ProductionProduct({
    required this.id,
    required this.name,
    required this.image,
    this.photoBytes,
    required this.recipeItems,
    required this.batchLimit,
    this.recipeYieldKg,
    this.weightPerPieceGram,
  });

  final String id;
  final String name;
  final String image;
  final Uint8List? photoBytes;
  final List<_ProductionRecipeItem> recipeItems;
  final int batchLimit;
  final double? recipeYieldKg;
  final double? weightPerPieceGram;

  factory _ProductionProduct.fromJson(Map<String, dynamic> json) {
    final photoBase64 = json['photo_base64'] as String?;
    return _ProductionProduct(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      image: json['image'] as String? ?? 'assets/produk-ubi.png',
      photoBytes: photoBase64 == null || photoBase64.isEmpty
          ? null
          : base64Decode(photoBase64),
      batchLimit: (json['batch_limit'] as num?)?.toInt() ?? 0,
      recipeYieldKg: (json['recipe_yield_kg'] as num?)?.toDouble(),
      weightPerPieceGram: (json['weight_per_piece_gram'] as num?)?.toDouble(),
      recipeItems: (json['recipe_items'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                _ProductionRecipeItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }
}

class _ProductionRecipeItem {
  const _ProductionRecipeItem({
    required this.materialId,
    required this.quantity,
    this.unit,
  });

  final String materialId;
  final double quantity;
  final String? unit;

  factory _ProductionRecipeItem.fromJson(Map<String, dynamic> json) =>
      _ProductionRecipeItem(
        materialId: json['material_id'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        unit: json['unit'] as String?,
      );
}

class _ProductionMaterial {
  const _ProductionMaterial({
    required this.id,
    required this.name,
    required this.unit,
    required this.quantity,
  });

  final String id;
  final String name;
  final String unit;
  final double quantity;

  factory _ProductionMaterial.fromJson(Map<String, dynamic> json) =>
      _ProductionMaterial(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        unit: json['unit'] as String? ?? 'Kg',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      );
}

String _formatProductionQuantity(double quantity) =>
    quantity == quantity.roundToDouble()
    ? quantity.toInt().toString()
    : quantity.toString();

String _productionDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _formatProductionDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

bool _isSameDate(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;
