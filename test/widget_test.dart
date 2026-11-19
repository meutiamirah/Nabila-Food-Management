import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nabila_food/data/app_repository.dart';
import 'package:nabila_food/main.dart';

void main() {
  test(
    'in-memory repository records insert, update, and delete activity',
    () async {
      final repository = InMemoryAppRepository();

      final inserted = await repository.saveMaterial({'name': 'Tepung Beras'});
      await repository.saveMaterial({
        ...inserted,
        'name': 'Tepung Beras Premium',
      });
      await repository.deleteMaterial(inserted['id'] as String);

      final logs = await repository.getActivityLogs();
      expect(logs.map((log) => log['action']), ['DELETE', 'UPDATE', 'INSERT']);
      expect(logs.first['record_name'], 'Tepung Beras Premium');
    },
  );

  test('production deducts recipe stock, rejects shortages, and restores on delete', () async {
    final repository = InMemoryAppRepository();
    final material = await repository.saveMaterial({
      'name': 'Ubi Jalar',
      'quantity': 5,
      'unit': 'Kg',
    });
    final product = await repository.saveProduct({
      'name': 'Keripik Ubi',
      'category': 'Aneka Keripik',
      'batch_limit': 3,
      'recipe_yield_kg': 1,
      'weight_per_piece_gram': 1000,
      'recipe_items': [
        {'material_id': material['id'], 'quantity': 4},
      ],
    });
    final batch = await repository.saveProductionBatch({
      'batch_code': 'PRD-01',
      'name': 'Keripik Ubi',
      'produced': 1,
      'target': 1,
      'station': 'Dapur',
      'product_id': product['id'],
    });

    expect(repository.materials.single['quantity'], 1);
    expect(repository.products.single['stock'], 1);
    await expectLater(
      repository.saveProductionBatch({
        'batch_code': 'PRD-02',
        'name': 'Keripik Ubi',
        'produced': 1,
        'target': 1,
        'station': 'Dapur',
        'product_id': product['id'],
      }),
      throwsA(isA<StateError>()),
    );
    expect(repository.productionBatches, hasLength(1));
    expect(repository.materials.single['quantity'], 1);

    final editedBatch = await repository.saveProductionBatch({
      ...batch,
      'produced': 3,
      'target': 3,
    });
    expect(repository.products.single['stock'], 3);

    await repository.deleteProductionBatch(editedBatch['id'] as String);
    expect(repository.materials.single['quantity'], 5);
    expect(repository.products.single['stock'], 0);
    expect(repository.productionBatches, isEmpty);
  });

  test(
    'production scales recipe grams to inventory kilograms by produced pcs',
    () async {
      final repository = InMemoryAppRepository();
      final material = await repository.saveMaterial({
        'name': 'Gula',
        'quantity': 1,
        'unit': 'Kg',
      });
      final packaging = await repository.saveMaterial({
        'name': 'Kemasan',
        'quantity': 10,
        'unit': 'Pcs',
      });
      final product = await repository.saveProduct({
        'name': 'Keripik',
        'batch_limit': 1,
        'recipe_yield_kg': 1,
        'weight_per_piece_gram': 100,
        'recipe_items': [
          {'material_id': material['id'], 'quantity': 250, 'unit': 'Gram'},
          {'material_id': packaging['id'], 'quantity': 4, 'unit': 'Pcs'},
        ],
      });

      final batch = await repository.saveProductionBatch({
        'batch_code': 'PRD-01',
        'name': 'Keripik',
        'produced': 5,
        'target': 5,
        'station': 'Dapur',
        'product_id': product['id'],
      });

      expect(repository.materials.first['quantity'], 0.875);
      expect(repository.materials[1]['quantity'], 8);
      await repository.deleteProductionBatch(batch['id'] as String);
      expect(repository.materials.first['quantity'], 1);
      expect(repository.materials[1]['quantity'], 10);
      expect(convertRecipeQuantity(500, 'g', 'Kg'), 0.5);
      expect(convertRecipeQuantity(250, 'mL', 'Liter'), 0.25);
      expect(
        () => convertRecipeQuantity(1, 'Pcs', 'Kg'),
        throwsA(isA<StateError>()),
      );
    },
  );

  test(
    'production enforces a product batch limit separately each day',
    () async {
      final repository = InMemoryAppRepository();
      final material = await repository.saveMaterial({
        'name': 'Ubi',
        'quantity': 10,
        'unit': 'Kg',
      });
      final product = await repository.saveProduct({
        'name': 'Keripik',
        'batch_limit': 3,
        'recipe_yield_kg': 1,
        'weight_per_piece_gram': 1000,
        'recipe_items': [
          {'material_id': material['id'], 'quantity': 1, 'unit': 'Kg'},
        ],
      });
      String dateKey(DateTime date) =>
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      final today = dateKey(DateTime.now());

      Map<String, dynamic> batch(String code, String date, {int count = 1}) => {
        'batch_code': code,
        'batch_count': count,
        'name': 'Keripik',
        'produced': count,
        'target': count,
        'station': 'Dapur',
        'product_id': product['id'],
        'produced_on': date,
      };

      await repository.saveProductionBatch(batch('PRD-01', today, count: 2));
      await repository.saveProductionBatch(batch('PRD-02', today));
      await expectLater(
        repository.saveProductionBatch(batch('PRD-03', today)),
        throwsA(isA<StateError>()),
      );
      expect(repository.materials.single['quantity'], 7);

      final tomorrow = dateKey(DateTime.now().add(const Duration(days: 1)));
      await repository.saveProductionBatch(batch('PRD-04', tomorrow));
      expect(repository.productionBatches, hasLength(3));
      expect(repository.materials.single['quantity'], 6);
      expect(repository.products.single['stock'], 4);
    },
  );

  testWidgets('activity tab displays logged data changes', (tester) async {
    _usePhoneSize(tester);
    final repository = InMemoryAppRepository();
    await repository.saveMaterial({'name': 'Tepung Beras'});

    await tester.pumpWidget(NabilaFoodApp(repository: repository));
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'nurvi@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'contoh-password');
    await tester.ensureVisible(find.text('Masuk Sekarang'));
    await tester.tap(find.text('Masuk Sekarang'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Aktivitas'));
    await tester.pumpAndSettle();

    expect(find.text('Log Aktivitas Terkini'), findsOneWidget);
    expect(find.text('Bahan baku ditambahkan'), findsOneWidget);
    expect(find.text('Tepung Beras'), findsOneWidget);
  });

  testWidgets('login validation prevents navigation with empty fields', (
    tester,
  ) async {
    _usePhoneSize(tester);
    await tester.pumpWidget(NabilaFoodApp(repository: InMemoryAppRepository()));

    await tester.ensureVisible(find.text('Masuk Sekarang'));
    await tester.tap(find.text('Masuk Sekarang'));
    await tester.pumpAndSettle();

    expect(find.text('Masukkan alamat email yang valid'), findsOneWidget);
    expect(find.text('Kata sandi wajib diisi'), findsOneWidget);
    expect(find.text('Nabila Food Management!'), findsNothing);
  });

  testWidgets('valid login opens the dashboard', (tester) async {
    _usePhoneSize(tester);

    await tester.pumpWidget(NabilaFoodApp(repository: InMemoryAppRepository()));
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'nurvi@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'contoh-password');
    await tester.ensureVisible(find.text('Masuk Sekarang'));
    await tester.tap(find.text('Masuk Sekarang'));
    await tester.pumpAndSettle();

    expect(find.text('Nabila Food Management!'), findsOneWidget);
    expect(find.text('Ringkasan Hari Ini'), findsOneWidget);
    expect(find.text('Top Product Hari Ini'), findsNothing);
    expect(find.text('Aktivitas Produksi & Pengemasan'), findsOneWidget);
    expect(find.text('Produk Sedang Dikemas'), findsNothing);
  });

  testWidgets('logout signs out and returns to the login screen', (
    tester,
  ) async {
    _usePhoneSize(tester);
    await _openDashboard(tester);

    await tester.tap(find.text('Aktivitas'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Keluar (Logout)'));
    await tester.tap(find.text('Keluar (Logout)'));
    await tester.pumpAndSettle();

    expect(find.text('Selamat Datang!'), findsOneWidget);
    expect(find.text('Nabila Food Management!'), findsNothing);
  });

  testWidgets('activity button clears all logs immediately', (tester) async {
    _usePhoneSize(tester);
    final repository = InMemoryAppRepository();
    await repository.saveMaterial({
      'name': 'Garam',
      'quantity': 1,
      'unit': 'Kg',
    });
    await _openDashboard(tester, repository: repository);

    await tester.tap(find.text('Aktivitas'));
    await tester.pumpAndSettle();
    expect(find.text('Bahan baku ditambahkan'), findsOneWidget);

    await tester.ensureVisible(find.text('Segarkan Log Aktivitas'));
    await tester.tap(find.text('Segarkan Log Aktivitas'));
    await tester.pumpAndSettle();

    expect(repository.activityLogs, isEmpty);
    expect(find.text('Belum ada aktivitas.'), findsOneWidget);
  });

  testWidgets('bahan-baku tab starts empty', (tester) async {
    _usePhoneSize(tester);
    await _openDashboard(tester);

    await tester.tap(find.byTooltip('Bahan Baku'));
    await tester.pumpAndSettle();
    expect(find.text('MANAJEMEN DAPUR'), findsOneWidget);
    expect(
      find.text(
        'Belum ada bahan baku. Tambahkan bahan untuk mulai mengelola stok.',
      ),
      findsOneWidget,
    );
    expect(find.text('0 Item Aktif'), findsOneWidget);
    expect(find.text('Ubi Jalar'), findsNothing);
  });

  testWidgets('produk tab starts empty', (tester) async {
    _usePhoneSize(tester);
    await _openDashboard(tester);

    await tester.tap(find.byTooltip('Produk'));
    await tester.pumpAndSettle();

    expect(find.text('Produk Keripik'), findsOneWidget);
    expect(find.text('0 Varian Aktif'), findsOneWidget);
    expect(
      find.text('Belum ada produk. Tekan Tambah Produk untuk memulai.'),
      findsOneWidget,
    );
    expect(find.text('Keripik Ubi Ungu Madu'), findsNothing);
  });

  testWidgets('starter recipes import and show yield and ingredients', (
    tester,
  ) async {
    _usePhoneSize(tester);
    final repository = InMemoryAppRepository();
    await _openDashboard(tester, repository: repository);
    await tester.tap(find.byTooltip('Produk'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('import-starter-recipes')));
    await tester.pumpAndSettle();

    expect(find.text('5 Varian Aktif'), findsOneWidget);
    expect(repository.products, hasLength(5));
    await tester.tap(find.text('Resep').first);
    await tester.pumpAndSettle();
    expect(find.text('Hasil jadi: 25 kg'), findsOneWidget);
    expect(find.text('- Ubi jalar: 100 kg'), findsOneWidget);

    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('import-starter-recipes')));
    await tester.pumpAndSettle();
    expect(repository.products, hasLength(5));
  });

  testWidgets('production tab starts with no batches', (tester) async {
    _usePhoneSize(tester);
    await _openDashboard(tester);
    await tester.tap(find.byTooltip('Produksi'));
    await tester.pumpAndSettle();

    expect(find.text('Produksi Harian'), findsOneWidget);
    expect(find.text('Daftar Batch Produksi'), findsOneWidget);
    expect(find.text('0 Batch'), findsOneWidget);
    expect(
      find.text(
        'Belum ada batch produksi. Tekan Tambah Produksi untuk memulai.',
      ),
      findsOneWidget,
    );
    expect(find.text('Keripik Tempe'), findsNothing);
  });

  testWidgets('production batch can be added', (tester) async {
    _usePhoneSize(tester);
    final repository = InMemoryAppRepository();
    final material = await repository.saveMaterial({
      'name': 'Ubi Jalar',
      'quantity': 10,
      'unit': 'Kg',
      'use_in_recipes': true,
    });
    await repository.saveProduct({
      'name': 'Keripik Pisang',
      'category': 'Keripik',
      'batch_limit': 3,
      'recipe_yield_kg': 1,
      'weight_per_piece_gram': 100,
      'recipe_items': [
        {'material_id': material['id'], 'quantity': 1, 'unit': 'Kg'},
      ],
    });
    await _openDashboard(tester, repository: repository);
    await tester.tap(find.byTooltip('Produksi'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tambah Produksi'));
    await tester.pumpAndSettle();
    expect(find.text('Operasional Dapur & Produksi'), findsOneWidget);
    expect(find.text('Jumlah Batch *'), findsOneWidget);
    expect(find.text('Estimasi Produk Jadi'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.byKey(const ValueKey('production-station')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Area Penggorengan'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byIcon(Icons.add));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan Produksi'));
    await tester.pumpAndSettle();

    expect(repository.productionBatches, hasLength(1));
    expect(repository.productionBatches.single['batch_count'], 2);
    expect(repository.productionBatches.single['produced'], 20);
    expect(repository.products.single['stock'], 20);
    expect(find.text('2 Batch'), findsOneWidget);
    await tester.tap(find.text('Tambah Produksi'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('production-station')));
    await tester.pumpAndSettle();
    expect(find.text('Area Penggorengan'), findsNothing);
    await tester.tap(find.text('Area Penirisan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan Produksi'));
    await tester.pumpAndSettle();
    expect(repository.productionBatches, hasLength(2));
    expect(repository.productionBatches.map((batch) => batch['station']), [
      'Area Penggorengan',
      'Area Penirisan',
    ]);
    expect(repository.products.single['stock'], 30);
    expect(find.text('3 Batch'), findsOneWidget);
    expect(find.text('Keripik Pisang'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('Area Penggorengan • 2 batch • 20 pcs'), findsOneWidget);
    expect(find.text('Area Penirisan • 1 batch • 10 pcs'), findsOneWidget);
    await tester.tap(find.byTooltip('Produk'));
    await tester.pumpAndSettle();
    expect(find.text('Stok Siap'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
  });

  testWidgets('production selection consumes the saved product recipe', (
    tester,
  ) async {
    _usePhoneSize(tester);
    final repository = InMemoryAppRepository();
    final material = await repository.saveMaterial({
      'name': 'Ubi Jalar',
      'quantity': 5,
      'unit': 'Kg',
      'use_in_recipes': true,
    });
    final product = await repository.saveProduct({
      'name': 'Keripik Ubi Madu',
      'category': 'Keripik Manis',
      'batch_limit': 1,
      'recipe_yield_kg': 1.8,
      'weight_per_piece_gram': 100,
      'recipe_items': [
        {'material_id': material['id'], 'quantity': 2},
      ],
    });
    await _openDashboard(tester, repository: repository);
    await tester.tap(find.byTooltip('Bahan Baku'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText().contains('5 Kg'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Produksi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah Produksi'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('production-station')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Area Penggorengan'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Simpan Produksi'));
    await tester.tap(find.text('Simpan Produksi'));
    await tester.pumpAndSettle();

    expect(repository.productionBatches, hasLength(1));
    expect(repository.productionBatches.single['product_id'], product['id']);
    expect(repository.products.single['stock'], 18);
    expect(repository.materials.single['quantity'], 3);
    await tester.tap(find.byTooltip('Bahan Baku'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText().contains('3 Kg'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('changing production product updates its image and summary', (
    tester,
  ) async {
    _usePhoneSize(tester);
    final repository = InMemoryAppRepository();
    final material = await repository.saveMaterial({
      'name': 'Ubi Jalar',
      'quantity': 10,
      'unit': 'Kg',
      'use_in_recipes': true,
    });
    await repository.saveProduct({
      'name': 'Keripik Ubi',
      'category': 'Keripik',
      'batch_limit': 3,
      'recipe_yield_kg': 1,
      'weight_per_piece_gram': 100,
      'recipe_items': [
        {'material_id': material['id'], 'quantity': 1, 'unit': 'Kg'},
      ],
    });
    await repository.saveProduct({
      'name': 'Keripik Tempe',
      'category': 'Keripik',
      'image': 'assets/produk-tempe.png',
      'photo_base64': 'dGVzdA==',
      'batch_limit': 3,
      'recipe_yield_kg': 2.5,
      'weight_per_piece_gram': 50,
      'recipe_items': [
        {'material_id': material['id'], 'quantity': 2, 'unit': 'Kg'},
      ],
    });
    await _openDashboard(tester, repository: repository);
    await tester.tap(find.byTooltip('Produksi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah Produksi'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('production-product')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keripik Tempe').last);
    await tester.pumpAndSettle();

    expect(find.text('Keripik Tempe'), findsNWidgets(2));
    expect(find.text('Resep: 2.5 kg'), findsOneWidget);
    expect(find.text('50 g'), findsOneWidget);
    expect(find.text('50 pcs'), findsNWidgets(2));
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is MemoryImage,
      ),
      findsOneWidget,
    );
  });

  testWidgets('produk tab can add a product', (tester) async {
    _usePhoneSize(tester);
    await _openDashboard(tester);
    await tester.tap(find.byTooltip('Produk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah Produk'));
    await tester.pumpAndSettle();

    expect(find.text('Foto Produk'), findsOneWidget);
    expect(find.text('Kebutuhan Bahan Utama'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('product-name')),
      'Keripik Pisang',
    );
    await tester.enterText(
      find.byKey(const ValueKey('product-batch-limit')),
      '25',
    );
    await tester.tap(find.text('Simpan Produk'));
    await tester.pumpAndSettle();

    expect(find.text('1 Varian Aktif'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Keripik Pisang');
    await tester.pumpAndSettle();
    expect(find.text('Keripik Pisang'), findsNWidgets(2));
  });

  testWidgets('new inventory materials can be added to product recipes', (
    tester,
  ) async {
    _usePhoneSize(tester);
    final repository = InMemoryAppRepository();
    final material = await repository.saveMaterial({
      'name': 'Bawang Putih Baru',
      'quantity': 10,
      'unit': 'Kg',
      'use_in_recipes': true,
    });
    await _openDashboard(tester, repository: repository);
    await tester.tap(find.byTooltip('Produk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah Produk'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('product-name')),
      'Keripik Bawang',
    );
    await tester.enterText(
      find.byKey(const ValueKey('product-batch-limit')),
      '10',
    );
    await tester.ensureVisible(find.text('Tambah Bahan'));
    await tester.tap(find.text('Tambah Bahan'));
    await tester.pumpAndSettle();
    expect(find.text('Bawang Putih Baru'), findsOneWidget);
    await tester.tap(find.text('Bawang Putih Baru'));
    await tester.tap(find.text('Pilih'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(ValueKey('recipe-quantity-${material['id']}')),
      '2.5',
    );
    await tester.tap(find.byKey(ValueKey('recipe-unit-${material['id']}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gram').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('product-recipe-yield-kg')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('product-recipe-yield-kg')),
      '1',
    );
    await tester.enterText(
      find.byKey(const ValueKey('product-weight-per-piece-gram')),
      '100',
    );
    await tester.tap(find.text('Simpan Produk'));
    await tester.pumpAndSettle();

    final recipeItems = repository.products.single['recipe_items'] as List;
    expect(recipeItems, [
      {'material_id': material['id'], 'quantity': 2.5, 'unit': 'Gram'},
    ]);
  });

  testWidgets('product edit shows existing stock and saves product changes', (
    tester,
  ) async {
    _usePhoneSize(tester);
    await _openDashboard(tester);
    await tester.tap(find.byTooltip('Produk'));
    await tester.pumpAndSettle();

    await _addProduct(tester, name: 'Keripik Ubi Ungu Madu', batchLimit: '45');
    await tester.ensureVisible(find.text('Edit').first);
    await tester.tap(find.text('Edit').first);
    await tester.pumpAndSettle();

    expect(find.text('Edit Produk'), findsOneWidget);
    expect(find.text('Ganti Foto'), findsOneWidget);
    expect(find.text('0 pcs'), findsOneWidget);
    expect(find.text('Kebutuhan Bahan Utama'), findsOneWidget);
    expect(find.byTooltip('Hapus produk'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('product-name')),
      'Keripik Ubi Ungu Madu Premium',
    );
    await tester.enterText(
      find.byKey(const ValueKey('product-batch-limit')),
      '55',
    );
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();

    expect(find.text('Keripik Ubi Ungu Madu Premium'), findsOneWidget);
    expect(find.text('55'), findsWidgets);
  });

  testWidgets('product edit can delete the current product', (tester) async {
    _usePhoneSize(tester);
    await _openDashboard(tester);
    await tester.tap(find.byTooltip('Produk'));
    await tester.pumpAndSettle();

    await _addProduct(tester, name: 'Keripik Ubi Ungu Madu', batchLimit: '45');
    await tester.ensureVisible(find.text('Edit').first);
    await tester.tap(find.text('Edit').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Hapus produk'));
    await tester.pumpAndSettle();

    expect(find.text('Hapus produk?'), findsOneWidget);
    await tester.tap(find.text('Hapus').last);
    await tester.pumpAndSettle();

    expect(find.text('Edit Produk'), findsNothing);
    expect(find.text('0 Varian Aktif'), findsOneWidget);
  });

  testWidgets('new product requires a name and a positive batch limit', (
    tester,
  ) async {
    _usePhoneSize(tester);
    await _openDashboard(tester);
    await tester.tap(find.byTooltip('Produk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah Produk'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Simpan Produk'));
    await tester.pumpAndSettle();
    expect(find.text('Nama produk wajib diisi'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('product-name')),
      'Keripik Pisang',
    );
    await tester.enterText(
      find.byKey(const ValueKey('product-batch-limit')),
      '0',
    );
    await tester.tap(find.text('Simpan Produk'));
    await tester.pumpAndSettle();
    expect(find.text('Masukkan batas batch lebih dari 0'), findsOneWidget);
    expect(find.text('Tambah Produk'), findsOneWidget);
  });

  testWidgets('bahan-baku page can add an item', (tester) async {
    _usePhoneSize(tester);
    await _openDashboard(tester);

    await tester.tap(find.byTooltip('Bahan Baku'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah Bahan'));
    await tester.pumpAndSettle();

    expect(find.text('Inventori & Gudang Dapur'), findsOneWidget);
    expect(find.text('Batas Minimum Aman'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Tepung Beras');
    await tester.tap(find.byTooltip('Tambah jumlah'));
    await tester.pump();
    await tester.tap(find.text('Simpan Bahan'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Tepung Beras');
    await tester.pumpAndSettle();
    expect(find.text('Tepung Beras'), findsNWidgets(2));
    expect(find.text('1 Item Aktif'), findsOneWidget);
  });

  testWidgets('add bahan requires a name and accepts zero initial stock', (
    tester,
  ) async {
    _usePhoneSize(tester);
    await _openDashboard(tester);
    await tester.tap(find.byTooltip('Bahan Baku'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah Bahan'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Simpan Bahan'));
    await tester.pumpAndSettle();

    expect(find.text('Bagian ini wajib diisi'), findsOneWidget);
    expect(find.text('Masukkan jumlah 0 atau lebih'), findsNothing);
    expect(find.text('Tambah Bahan Baku'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Tepung Beras');
    await tester.tap(find.text('Simpan Bahan'));
    await tester.pumpAndSettle();
    expect(find.text('1 Item Aktif'), findsOneWidget);
  });

  testWidgets(
    'edit bahan updates stock, minimum, category and recipe setting',
    (tester) async {
      _usePhoneSize(tester);
      await _openDashboard(tester);
      await tester.tap(find.byTooltip('Bahan Baku'));
      await tester.pumpAndSettle();
      await _addMaterial(tester, name: 'Ubi Jalar', stockIncrement: 1);
      await tester.tap(find.byTooltip('Edit Ubi Jalar'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Bahan Baku'), findsOneWidget);
      expect(find.text('Detail & Penyesuaian Stok'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        '1',
      );

      await tester.tap(find.text('+10 Kg'));
      await tester.pump();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        '11',
      );
      await tester.tap(find.text('Simpan Perubahan'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Ubi Jalar');
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is RichText && widget.text.toPlainText().contains('11 Kg'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('edit bahan can be cancelled without changing stock', (
    tester,
  ) async {
    _usePhoneSize(tester);
    await _openDashboard(tester);
    await tester.tap(find.byTooltip('Bahan Baku'));
    await tester.pumpAndSettle();
    await _addMaterial(tester, name: 'Ubi Jalar', stockIncrement: 1);
    await tester.tap(find.byTooltip('Edit Ubi Jalar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('+50 Kg'));
    await tester.pump();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(find.text('Ubi Jalar'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText().contains('1 Kg'),
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText().contains('51 Kg'),
      ),
      findsNothing,
    );
  });

  testWidgets('password visibility can be toggled', (tester) async {
    _usePhoneSize(tester);
    await tester.pumpWidget(NabilaFoodApp(repository: InMemoryAppRepository()));

    final passwordField = tester.widget<EditableText>(
      find.descendant(
        of: find.byType(TextFormField).at(1),
        matching: find.byType(EditableText),
      ),
    );
    expect(passwordField.obscureText, isTrue);

    await tester.tap(find.byTooltip('Tampilkan kata sandi'));
    await tester.pump();

    final visiblePasswordField = tester.widget<EditableText>(
      find.descendant(
        of: find.byType(TextFormField).at(1),
        matching: find.byType(EditableText),
      ),
    );
    expect(visiblePasswordField.obscureText, isFalse);
  });
}

void _usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _addProduct(
  WidgetTester tester, {
  required String name,
  required String batchLimit,
}) async {
  await tester.tap(find.text('Tambah Produk'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('product-name')), name);
  await tester.enterText(
    find.byKey(const ValueKey('product-batch-limit')),
    batchLimit,
  );
  await tester.tap(find.text('Simpan Produk'));
  await tester.pumpAndSettle();
}

Future<void> _addMaterial(
  WidgetTester tester, {
  required String name,
  int stockIncrement = 0,
}) async {
  await tester.tap(find.text('Tambah Bahan'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).first, name);
  for (var index = 0; index < stockIncrement; index++) {
    await tester.tap(find.byTooltip('Tambah jumlah'));
    await tester.pump();
  }
  await tester.tap(find.text('Simpan Bahan'));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

Future<void> _openDashboard(
  WidgetTester tester, {
  InMemoryAppRepository? repository,
}) async {
  await tester.pumpWidget(
    NabilaFoodApp(repository: repository ?? InMemoryAppRepository()),
  );
  await tester.enterText(find.byType(TextFormField).at(0), 'nurvi@example.com');
  await tester.enterText(find.byType(TextFormField).at(1), 'contoh-password');
  await tester.ensureVisible(find.text('Masuk Sekarang'));
  await tester.tap(find.text('Masuk Sekarang'));
  await tester.pumpAndSettle();
}
