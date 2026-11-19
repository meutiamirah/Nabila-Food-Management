import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AppRepository {
  Future<void> signIn({required String email, required String password});
  Future<void> signOut();

  Future<List<Map<String, dynamic>>> getMaterials();
  Future<Map<String, dynamic>> saveMaterial(Map<String, dynamic> material);
  Future<void> deleteMaterial(String id);

  Future<List<Map<String, dynamic>>> getProducts();
  Future<Map<String, dynamic>> saveProduct(Map<String, dynamic> product);
  Future<void> deleteProduct(String id);

  Future<List<Map<String, dynamic>>> getProductionBatches();
  Future<Map<String, dynamic>> saveProductionBatch(Map<String, dynamic> batch);
  Future<void> deleteProductionBatch(String id);

  Future<List<Map<String, dynamic>>> getActivityLogs();
  Future<void> clearActivityLogs();

  Future<Map<String, dynamic>?> getAdminProfile();
  Future<void> saveAdminProfile({required String name, String? photoBase64});
}

class SupabaseAppRepository implements AppRepository {
  SupabaseAppRepository({this.client});

  final SupabaseClient? client;

  SupabaseClient get _supabase => client ?? Supabase.instance.client;

  String get _userId {
    final id = _supabase.auth.currentUser?.id;
    if (id == null) throw StateError('Sesi login tidak ditemukan.');
    return id;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  @override
  Future<List<Map<String, dynamic>>> getMaterials() async {
    final rows = await _supabase
        .from('materials')
        .select()
        .eq('user_id', _userId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<Map<String, dynamic>> saveMaterial(
    Map<String, dynamic> material,
  ) async {
    final row = Map<String, dynamic>.of(material)..['user_id'] = _userId;
    final saved = await _supabase
        .from('materials')
        .upsert(row)
        .select()
        .single();
    return Map<String, dynamic>.from(saved);
  }

  @override
  Future<void> deleteMaterial(String id) async {
    await _supabase
        .from('materials')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }

  @override
  Future<List<Map<String, dynamic>>> getProducts() async {
    final rows = await _supabase
        .from('products')
        .select()
        .eq('user_id', _userId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<Map<String, dynamic>> saveProduct(Map<String, dynamic> product) async {
    final row = Map<String, dynamic>.of(product)..['user_id'] = _userId;
    try {
      final saved = await _supabase
          .from('products')
          .upsert(row)
          .select()
          .single();
      return Map<String, dynamic>.from(saved);
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST204' &&
          (error.message.contains('recipe_items') ||
              error.message.contains('recipe_yield') ||
              error.message.contains('weight_per_piece_gram'))) {
        throw StateError(
          'Database Supabase belum diperbarui. Jalankan ulang '
          'supabase/schema.sql di SQL Editor.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteProduct(String id) async {
    await _supabase
        .from('products')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }

  @override
  Future<List<Map<String, dynamic>>> getProductionBatches() async {
    final rows = await _supabase
        .from('production_batches')
        .select()
        .eq('user_id', _userId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<Map<String, dynamic>> saveProductionBatch(
    Map<String, dynamic> batch,
  ) async {
    final row = Map<String, dynamic>.of(batch)..['user_id'] = _userId;
    if (row['id'] == null) {
      final saved = await _supabase.rpc(
        'create_production_batch_with_materials',
        params: {'p_batch': row},
      );
      if (saved is! Map) {
        throw StateError('Respons penyimpanan produksi tidak valid.');
      }
      return Map<String, dynamic>.from(saved);
    }
    final id = row.remove('id') as String;
    row
      ..remove('user_id')
      ..remove('product_id')
      ..remove('material_usage');
    final saved = await _supabase
        .from('production_batches')
        .update(row)
        .eq('id', id)
        .eq('user_id', _userId)
        .select()
        .single();
    return Map<String, dynamic>.from(saved);
  }

  @override
  Future<void> deleteProductionBatch(String id) async {
    await _supabase.rpc(
      'delete_production_batch_restore_materials',
      params: {'p_batch_id': id},
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getActivityLogs() async {
    final rows = await _supabase
        .from('activity_logs')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<void> clearActivityLogs() async {
    await _supabase.from('activity_logs').delete().eq('user_id', _userId);
  }

  @override
  Future<Map<String, dynamic>?> getAdminProfile() async {
    final row = await _supabase
        .from('profiles')
        .select()
        .eq('id', _userId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  @override
  Future<void> saveAdminProfile({
    required String name,
    String? photoBase64,
  }) async {
    await _supabase.from('profiles').upsert({
      'id': _userId,
      'name': name,
      'photo_base64': ?photoBase64,
    });
  }
}

List<String> recipeUnitsForInventory(String inventoryUnit) {
  switch (inventoryUnit.trim().toLowerCase()) {
    case 'kg':
    case 'gram':
    case 'g':
      return const ['Kg', 'Gram'];
    case 'liter':
    case 'l':
    case 'ml':
      return const ['Liter', 'mL'];
    default:
      return [inventoryUnit];
  }
}

double convertRecipeQuantity(double quantity, String fromUnit, String toUnit) {
  final from = _canonicalUnit(fromUnit);
  final to = _canonicalUnit(toUnit);
  if (!quantity.isFinite || quantity < 0) {
    throw ArgumentError.value(quantity, 'quantity', 'must be finite and >= 0');
  }
  if (from == to) return quantity;
  if (from == 'g' && to == 'kg') return quantity / 1000;
  if (from == 'kg' && to == 'g') return quantity * 1000;
  if (from == 'ml' && to == 'l') return quantity / 1000;
  if (from == 'l' && to == 'ml') return quantity * 1000;
  throw StateError('Satuan $fromUnit tidak cocok dengan satuan stok $toUnit.');
}

String _canonicalUnit(String unit) {
  switch (unit.trim().toLowerCase()) {
    case 'gram':
    case 'g':
      return 'g';
    case 'kilogram':
    case 'kg':
      return 'kg';
    case 'liter':
    case 'litre':
    case 'l':
      return 'l';
    case 'milliliter':
    case 'millilitre':
    case 'ml':
      return 'ml';
    case 'pcs':
    case 'piece':
    case 'pieces':
      return 'pcs';
    default:
      return unit.trim().toLowerCase();
  }
}

class InMemoryAppRepository implements AppRepository {
  final List<Map<String, dynamic>> materials = [];
  final List<Map<String, dynamic>> products = [];
  final List<Map<String, dynamic>> productionBatches = [];
  final List<Map<String, dynamic>> activityLogs = [];
  Map<String, dynamic>? adminProfile;
  var _nextId = 0;

  Map<String, dynamic> _save(
    List<Map<String, dynamic>> rows,
    Map<String, dynamic> value,
    String tableName,
  ) {
    final row = Map<String, dynamic>.of(value);
    final id = row['id'] as String?;
    var action = 'INSERT';
    if (id == null || id.isEmpty) {
      row['id'] = 'test-${_nextId++}';
      rows.add(row);
    } else {
      final index = rows.indexWhere((item) => item['id'] == id);
      if (index == -1) {
        rows.add(row);
      } else {
        rows[index] = row;
        action = 'UPDATE';
      }
    }
    _recordActivity(action, tableName, row);
    return row;
  }

  void _recordActivity(
    String action,
    String tableName,
    Map<String, dynamic> row,
  ) {
    activityLogs.insert(0, {
      'id': 'test-log-${_nextId++}',
      'user_id': 'test-user',
      'action': action,
      'table_name': tableName,
      'record_id': row['id']?.toString(),
      'record_name': row['name']?.toString() ?? row['batch_code']?.toString(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  void _delete(List<Map<String, dynamic>> rows, String id, String tableName) {
    final index = rows.indexWhere((item) => item['id'] == id);
    if (index == -1) return;
    final deleted = rows.removeAt(index);
    _recordActivity('DELETE', tableName, deleted);
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<List<Map<String, dynamic>>> getMaterials() async => List.of(materials);

  @override
  Future<Map<String, dynamic>> saveMaterial(
    Map<String, dynamic> material,
  ) async => _save(materials, material, 'materials');

  @override
  Future<void> deleteMaterial(String id) async =>
      _delete(materials, id, 'materials');

  @override
  Future<List<Map<String, dynamic>>> getProducts() async => List.of(products);

  @override
  Future<Map<String, dynamic>> saveProduct(
    Map<String, dynamic> product,
  ) async => _save(products, product, 'products');

  @override
  Future<void> deleteProduct(String id) async =>
      _delete(products, id, 'products');

  @override
  Future<List<Map<String, dynamic>>> getProductionBatches() async =>
      List.of(productionBatches);

  @override
  Future<Map<String, dynamic>> saveProductionBatch(
    Map<String, dynamic> batch,
  ) async {
    final row = Map<String, dynamic>.of(batch);
    final batchId = row['id'] as String?;
    final oldBatches = batchId == null
        ? <Map<String, dynamic>>[]
        : productionBatches.where((item) => item['id'] == batchId).toList();
    final oldBatch = oldBatches.isEmpty ? null : oldBatches.first;
    if (oldBatch != null) {
      row['product_id'] = oldBatch['product_id'];
      row['material_usage'] = oldBatch['material_usage'];
    }
    final productionDate =
        row['produced_on'] as String? ?? _repositoryDateKey(DateTime.now());
    row['produced_on'] = productionDate;
    final batchCount = (row['batch_count'] as num?)?.toInt() ?? 1;
    if (batchCount <= 0) throw StateError('Jumlah batch harus lebih dari 0.');
    row['batch_count'] = batchCount;
    final productId = row['product_id'] as String?;
    if (productId != null) {
      final matchingProducts = products
          .where((item) => item['id'] == productId)
          .toList();
      if (matchingProducts.isEmpty) {
        throw StateError('Resep produk tidak ditemukan.');
      }
      final product = matchingProducts.first;
      final batchLimit = (product['batch_limit'] as num?)?.toInt() ?? 0;
      final batchesUsed = productionBatches
          .where(
            (item) =>
                item['product_id'] == productId &&
                item['produced_on'] == productionDate &&
                item['id'] != batchId,
          )
          .fold<int>(
            0,
            (total, item) =>
                total + ((item['batch_count'] as num?)?.toInt() ?? 1),
          );
      if (batchLimit <= 0 || batchesUsed + batchCount > batchLimit) {
        throw StateError(
          'Batas $batchLimit batch harian untuk ${product['name']} '
          'sudah tercapai.',
        );
      }
    }
    if ((row['id'] as String?) == null && productId != null) {
      final product = products.where((item) => item['id'] == productId);
      if (product.isEmpty) throw StateError('Resep produk tidak ditemukan.');
      final recipeItems = product.first['recipe_items'] as List? ?? const [];
      if (recipeItems.isEmpty) {
        throw StateError('Resep produk belum memiliki takaran bahan.');
      }
      final recipeYieldKg = (product.first['recipe_yield_kg'] as num?)
          ?.toDouble();
      final weightPerPieceGram =
          (product.first['weight_per_piece_gram'] as num?)?.toDouble();
      final produced = (row['produced'] as num?)?.toDouble();
      if (recipeYieldKg == null ||
          !recipeYieldKg.isFinite ||
          recipeYieldKg <= 0 ||
          weightPerPieceGram == null ||
          !weightPerPieceGram.isFinite ||
          weightPerPieceGram <= 0 ||
          produced == null ||
          !produced.isFinite ||
          produced <= 0) {
        throw StateError(
          'Isi hasil resep penuh (kg), berat per pcs (gram), '
          'dan jumlah produksi yang valid.',
        );
      }

      final scaleFactor =
          produced * weightPerPieceGram / (recipeYieldKg * 1000);

      final quantities = <String, double>{};
      for (final item in recipeItems) {
        if (item is! Map) throw StateError('Data takaran resep tidak valid.');
        final materialId = item['material_id'] as String?;
        final quantity = (item['quantity'] as num?)?.toDouble();
        final matches = materials.where((row) => row['id'] == materialId);
        if (materialId == null ||
            quantity == null ||
            !quantity.isFinite ||
            quantity <= 0) {
          throw StateError('Data takaran resep tidak valid.');
        }
        if (matches.isEmpty) {
          throw StateError('Bahan yang dipakai resep tidak ditemukan.');
        }
        final materialUnit = matches.first['unit'] as String? ?? 'Kg';
        final recipeUnit = item['unit'] as String? ?? materialUnit;
        final stockQuantity = convertRecipeQuantity(
          quantity * scaleFactor,
          recipeUnit,
          materialUnit,
        );
        quantities.update(
          materialId,
          (existing) => existing + stockQuantity,
          ifAbsent: () => stockQuantity,
        );
      }

      final usage = <Map<String, dynamic>>[];
      for (final entry in quantities.entries) {
        final matches = materials.where((item) => item['id'] == entry.key);
        final material = matches.first;
        final stock = (material['quantity'] as num?)?.toDouble() ?? 0;
        if (stock < entry.value) {
          throw StateError(
            'Stok ${material['name']} tidak cukup. '
            'Tersedia $stock ${material['unit']}, '
            'dibutuhkan ${entry.value} ${material['unit']}.',
          );
        }
        usage.add({'material_id': entry.key, 'quantity': entry.value});
      }

      for (final item in usage) {
        final materialId = item['material_id'] as String;
        final index = materials.indexWhere((row) => row['id'] == materialId);
        final material = Map<String, dynamic>.of(materials[index]);
        material['quantity'] =
            ((material['quantity'] as num?)?.toDouble() ?? 0) -
            (item['quantity'] as num).toDouble();
        _save(materials, material, 'materials');
      }
      row['material_usage'] = usage;
    }
    final saved = _save(productionBatches, row, 'production_batches');
    final savedProductId = saved['product_id'] as String?;
    final previousProductId = oldBatch?['product_id'] as String?;
    if (savedProductId != null && savedProductId == previousProductId) {
      final producedDelta =
          ((saved['produced'] as num?)?.toInt() ?? 0) -
          ((oldBatch?['produced'] as num?)?.toInt() ?? 0);
      _changeProductStock(savedProductId, producedDelta);
    } else {
      if (previousProductId != null) {
        _changeProductStock(
          previousProductId,
          -((oldBatch?['produced'] as num?)?.toInt() ?? 0),
        );
      }
      if (savedProductId != null) {
        _changeProductStock(
          savedProductId,
          (saved['produced'] as num?)?.toInt() ?? 0,
        );
      }
    }
    return saved;
  }

  void _changeProductStock(String productId, int delta) {
    final index = products.indexWhere((item) => item['id'] == productId);
    if (index == -1 || delta == 0) return;
    final product = Map<String, dynamic>.of(products[index]);
    final stock = (product['stock'] as num?)?.toInt() ?? 0;
    product['stock'] = (stock + delta).clamp(0, 0x7fffffff).toInt();
    _save(products, product, 'products');
  }

  @override
  Future<void> deleteProductionBatch(String id) async {
    final matches = productionBatches.where((item) => item['id'] == id);
    if (matches.isEmpty) return;
    final batch = matches.first;
    final usage = batch['material_usage'] as List? ?? const [];
    final restore = <(int, double)>[];
    for (final item in usage) {
      if (item is! Map) {
        throw StateError('Riwayat pemakaian bahan tidak valid.');
      }
      final materialId = item['material_id'] as String?;
      final quantity = (item['quantity'] as num?)?.toDouble();
      if (materialId == null || quantity == null || quantity <= 0) {
        throw StateError('Riwayat pemakaian bahan tidak valid.');
      }
      final index = materials.indexWhere((row) => row['id'] == materialId);
      if (index == -1) {
        throw StateError(
          'Bahan yang digunakan batch sudah tidak ada di inventori.',
        );
      }
      restore.add((index, quantity));
    }
    for (final (index, quantity) in restore) {
      final material = Map<String, dynamic>.of(materials[index]);
      material['quantity'] =
          ((material['quantity'] as num?)?.toDouble() ?? 0) + quantity;
      _save(materials, material, 'materials');
    }
    final productId = batch['product_id'] as String?;
    if (productId != null) {
      _changeProductStock(
        productId,
        -((batch['produced'] as num?)?.toInt() ?? 0),
      );
    }
    _delete(productionBatches, id, 'production_batches');
  }

  @override
  Future<List<Map<String, dynamic>>> getActivityLogs() async =>
      List.of(activityLogs);

  @override
  Future<void> clearActivityLogs() async => activityLogs.clear();

  @override
  Future<Map<String, dynamic>?> getAdminProfile() async => adminProfile;

  @override
  Future<void> saveAdminProfile({
    required String name,
    String? photoBase64,
  }) async {
    adminProfile = {
      ...?adminProfile,
      'name': name,
      'photo_base64': ?photoBase64,
    };
  }
}

String _repositoryDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
