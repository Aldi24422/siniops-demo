import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/product_model.dart';
import '../../core/models/ingredient_model.dart';
import '../../core/services/product_controller.dart';
import '../../core/services/ingredient_controller.dart';

class ManageMenuPage extends StatefulWidget {
  const ManageMenuPage({super.key});

  @override
  State<ManageMenuPage> createState() => _ManageMenuPageState();
}

class _ManageMenuPageState extends State<ManageMenuPage> {
  final ProductController _productController = ProductController();
  final IngredientController _ingredientController = IngredientController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Kelola Menu",
          style: GoogleFonts.lexendDeca(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.accent, height: 1),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showMenuDialog(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          "Tambah Menu",
          style: GoogleFonts.lexendDeca(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: StreamBuilder<List<Product>>(
        stream: _productController.getProducts(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
                style: GoogleFonts.lexendDeca(color: AppColors.error),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final products = snapshot.data!;

          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.restaurant_menu_rounded,
                    size: 64,
                    color: AppColors.accent,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Belum ada menu",
                    style: GoogleFonts.lexendDeca(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Tap tombol + untuk menambah menu baru",
                    style: GoogleFonts.lexendDeca(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: products.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _buildMenuCard(products[index]),
          );
        },
      ),
    );
  }

  Widget _buildMenuCard(Product product) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.coffee_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: GoogleFonts.lexendDeca(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  product.description,
                  style: GoogleFonts.lexendDeca(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      "Rp ${_formatRupiah(product.price)}",
                      style: GoogleFonts.lexendDeca(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        product.category,
                        style: GoogleFonts.lexendDeca(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (product.hasRecipe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.science_rounded,
                              size: 10,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              "${product.recipe.length}",
                              style: GoogleFonts.lexendDeca(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Actions
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'edit') {
                _showMenuDialog(product: product);
              } else if (value == 'delete') {
                _confirmDelete(product);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    const Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Text("Edit", style: GoogleFonts.lexendDeca()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Hapus",
                      style: GoogleFonts.lexendDeca(color: AppColors.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Show Add/Edit Menu Dialog with Recipe input
  void _showMenuDialog({Product? product}) {
    final isEdit = product != null;
    final nameController = TextEditingController(text: product?.name ?? '');
    final descController = TextEditingController(
      text: product?.description ?? '',
    );
    final priceController = TextEditingController(
      text: product?.price.toStringAsFixed(0) ?? '',
    );
    String selectedCategory = product?.category ?? 'Coffee';

    // Recipe state - mutable list
    List<RecipeItem> recipeItems = product?.recipe.toList() ?? [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                isEdit ? Icons.edit_rounded : Icons.add_circle_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Text(
                isEdit ? "Edit Menu" : "Tambah Menu",
                style: GoogleFonts.lexendDeca(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  TextField(
                    controller: nameController,
                    decoration: _inputDecoration("Nama Menu"),
                    style: GoogleFonts.lexendDeca(fontSize: 14),
                  ),
                  const SizedBox(height: 14),

                  // Description
                  TextField(
                    controller: descController,
                    decoration: _inputDecoration("Deskripsi"),
                    style: GoogleFonts.lexendDeca(fontSize: 14),
                  ),
                  const SizedBox(height: 14),

                  // Price
                  TextField(
                    controller: priceController,
                    decoration: _inputDecoration("Harga (Rp)"),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.lexendDeca(fontSize: 14),
                  ),
                  const SizedBox(height: 14),

                  // Category Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: _inputDecoration("Kategori"),
                    style: GoogleFonts.lexendDeca(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    items: ['Coffee', 'Non-Coffee', 'Food', 'Snack']
                        .map(
                          (cat) =>
                              DropdownMenuItem(value: cat, child: Text(cat)),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedCategory = val);
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  // === RECIPE SECTION ===
                  Row(
                    children: [
                      const Icon(
                        Icons.science_rounded,
                        size: 18,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Komposisi Resep",
                        style: GoogleFonts.lexendDeca(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Recipe items list
                  if (recipeItems.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: recipeItems.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          return _buildRecipeItemRow(
                            item,
                            onDelete: () {
                              setDialogState(() {
                                recipeItems.removeAt(index);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),

                  if (recipeItems.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          "Belum ada bahan",
                          style: GoogleFonts.lexendDeca(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 10),

                  // Add ingredient button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showAddIngredientDialog((RecipeItem newItem) {
                            setDialogState(() {
                              recipeItems.add(newItem);
                            });
                          }),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(
                        "Tambah Bahan",
                        style: GoogleFonts.lexendDeca(fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.secondary,
                        side: const BorderSide(color: AppColors.secondary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                "Batal",
                style: GoogleFonts.lexendDeca(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                // Validate
                final name = nameController.text.trim();
                final desc = descController.text.trim();
                final priceText = priceController.text.trim();

                if (name.isEmpty || desc.isEmpty || priceText.isEmpty) {
                  _showSnackBar("Semua field harus diisi", isError: true);
                  return;
                }

                final price = double.tryParse(priceText);
                if (price == null || price <= 0) {
                  _showSnackBar("Harga harus angka positif", isError: true);
                  return;
                }

                Navigator.pop(ctx);

                try {
                  if (isEdit) {
                    await _productController.updateProduct(
                      Product(
                        id: product.id,
                        name: name,
                        description: desc,
                        price: price,
                        category: selectedCategory,
                        recipe: recipeItems,
                      ),
                    );
                    _showSnackBar("Menu berhasil diupdate");
                  } else {
                    await _productController.addProduct(
                      Product(
                        name: name,
                        description: desc,
                        price: price,
                        category: selectedCategory,
                        recipe: recipeItems,
                      ),
                    );
                    _showSnackBar("Menu berhasil ditambahkan");
                  }
                } catch (e) {
                  _showSnackBar("Error: $e", isError: true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                isEdit ? "Simpan" : "Tambah",
                style: GoogleFonts.lexendDeca(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build recipe item row widget
  Widget _buildRecipeItemRow(
    RecipeItem item, {
    required VoidCallback onDelete,
  }) {
    return FutureBuilder<Ingredient?>(
      future: _ingredientController.getIngredientById(item.ingredientId),
      builder: (context, snapshot) {
        final ingredient = snapshot.data;
        final name = ingredient?.name ?? 'Loading...';
        final unit = ingredient?.baseUnit ?? '';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.accent, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.lexendDeca(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                "${item.amount.toStringAsFixed(0)} $unit",
                style: GoogleFonts.lexendDeca(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Show dialog to add ingredient to recipe
  void _showAddIngredientDialog(Function(RecipeItem) onAdd) {
    String? selectedIngredientId;
    String selectedUnit = '';
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.add_circle_outline, color: AppColors.secondary),
              const SizedBox(width: 10),
              Text(
                "Tambah Bahan",
                style: GoogleFonts.lexendDeca(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          content: StreamBuilder<List<Ingredient>>(
            stream: _ingredientController.getIngredients(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 100,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }

              final ingredients = snapshot.data!;
              if (ingredients.isEmpty) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 48,
                      color: AppColors.accent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Belum ada bahan baku",
                      style: GoogleFonts.lexendDeca(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Tambahkan bahan di menu Stok Bahan",
                      style: GoogleFonts.lexendDeca(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ingredient dropdown
                  DropdownButtonFormField<String>(
                    initialValue: selectedIngredientId,
                    decoration: _inputDecoration("Pilih Bahan"),
                    style: GoogleFonts.lexendDeca(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    items: ingredients
                        .map(
                          (i) => DropdownMenuItem(
                            value: i.id,
                            child: Text("${i.name} (${i.baseUnit})"),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        selectedIngredientId = val;
                        final selected = ingredients.firstWhere(
                          (i) => i.id == val,
                        );
                        selectedUnit = selected.baseUnit;
                      });
                    },
                  ),
                  const SizedBox(height: 14),

                  // Amount input
                  TextField(
                    controller: amountController,
                    decoration: _inputDecoration(
                      selectedUnit.isNotEmpty
                          ? "Jumlah ($selectedUnit)"
                          : "Jumlah",
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    style: GoogleFonts.lexendDeca(fontSize: 14),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                "Batal",
                style: GoogleFonts.lexendDeca(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedIngredientId == null) {
                  _showSnackBar("Pilih bahan terlebih dahulu", isError: true);
                  return;
                }

                final amount = double.tryParse(amountController.text.trim());
                if (amount == null || amount <= 0) {
                  _showSnackBar("Masukkan jumlah yang valid", isError: true);
                  return;
                }

                Navigator.pop(ctx);
                onAdd(
                  RecipeItem(
                    ingredientId: selectedIngredientId!,
                    amount: amount,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                "Tambah",
                style: GoogleFonts.lexendDeca(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Confirm delete with dialog
  void _confirmDelete(Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error),
            const SizedBox(width: 10),
            Text(
              "Hapus Menu?",
              style: GoogleFonts.lexendDeca(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          "Anda yakin ingin menghapus \"${product.name}\"? Tindakan ini tidak dapat dibatalkan.",
          style: GoogleFonts.lexendDeca(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Batal",
              style: GoogleFonts.lexendDeca(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _productController.deleteProduct(product.id!);
                _showSnackBar("Menu berhasil dihapus");
              } catch (e) {
                _showSnackBar("Error: $e", isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              "Hapus",
              style: GoogleFonts.lexendDeca(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.lexendDeca(
        color: AppColors.textSecondary,
        fontSize: 13,
      ),
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _formatRupiah(double value) {
    return value
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
  }
}
