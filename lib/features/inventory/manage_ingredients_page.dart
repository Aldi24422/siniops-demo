import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/ingredient_model.dart';
import '../../core/services/ingredient_controller.dart';

class ManageIngredientsPage extends StatefulWidget {
  const ManageIngredientsPage({super.key});

  @override
  State<ManageIngredientsPage> createState() => _ManageIngredientsPageState();
}

class _ManageIngredientsPageState extends State<ManageIngredientsPage> {
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
          "Stok Bahan Baku",
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
        onPressed: () => _showIngredientDialog(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          "Tambah Bahan",
          style: GoogleFonts.lexendDeca(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: StreamBuilder<List<Ingredient>>(
        stream: _ingredientController.getIngredients(),
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

          final ingredients = snapshot.data!;

          if (ingredients.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.inventory_2_rounded,
                    size: 64,
                    color: AppColors.accent,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Belum ada bahan baku",
                    style: GoogleFonts.lexendDeca(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Tap tombol + untuk menambah bahan baru",
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
            itemCount: ingredients.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _buildIngredientCard(ingredients[index]),
          );
        },
      ),
    );
  }

  Widget _buildIngredientCard(Ingredient ingredient) {
    final isLowStock = ingredient.isLowStock;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLowStock
              ? AppColors.error.withValues(alpha: 0.5)
              : AppColors.accent,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isLowStock
                  ? AppColors.error.withValues(alpha: 0.1)
                  : AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.inventory_2_rounded,
              color: isLowStock ? AppColors.error : AppColors.secondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),

          // Info - using smart displayStock
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ingredient.name,
                  style: GoogleFonts.lexendDeca(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      ingredient.displayStock, // Smart display!
                      style: GoogleFonts.dongle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isLowStock ? AppColors.error : AppColors.primary,
                        height: 1,
                      ),
                    ),
                    if (isLowStock) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "STOK RENDAH",
                          style: GoogleFonts.lexendDeca(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  "Min. alert: ${ingredient.displayMinStock}",
                  style: GoogleFonts.lexendDeca(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Actions
          Column(
            children: [
              // Restock Button
              IconButton(
                onPressed: () => _showRestockDialog(ingredient),
                icon: const Icon(Icons.add_shopping_cart_rounded),
                color: AppColors.success,
                tooltip: "Belanja Stok",
              ),
              // More Options
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: AppColors.textSecondary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) {
                  if (value == 'edit') {
                    _showIngredientDialog(ingredient: ingredient);
                  } else if (value == 'delete') {
                    _confirmDelete(ingredient);
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
        ],
      ),
    );
  }

  /// Show Add/Edit Ingredient Dialog with Unit Conversion
  void _showIngredientDialog({Ingredient? ingredient}) {
    final isEdit = ingredient != null;
    final nameController = TextEditingController(text: ingredient?.name ?? '');

    // For edit: convert base unit to best display unit
    String selectedUnit = isEdit
        ? UnitConverter.getBestDisplayUnit(
            ingredient.stockInBaseUnit,
            ingredient.baseUnit,
          )
        : 'Gram';

    // Display value in selected unit
    final stockController = TextEditingController(
      text: isEdit
          ? _formatDouble(
              UnitConverter.fromBaseUnit(
                ingredient.stockInBaseUnit,
                selectedUnit,
              ),
            )
          : '',
    );
    final minAlertController = TextEditingController(
      text: isEdit
          ? _formatDouble(
              UnitConverter.fromBaseUnit(
                ingredient.minStockAlert,
                selectedUnit,
              ),
            )
          : '0',
    );

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
                isEdit ? "Edit Bahan" : "Tambah Bahan",
                style: GoogleFonts.lexendDeca(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Name
                TextField(
                  controller: nameController,
                  decoration: _inputDecoration("Nama Bahan"),
                  style: GoogleFonts.lexendDeca(fontSize: 14),
                ),
                const SizedBox(height: 14),

                // Unit Dropdown - Smart Units
                DropdownButtonFormField<String>(
                  initialValue: selectedUnit,
                  decoration: _inputDecoration("Satuan"),
                  style: GoogleFonts.lexendDeca(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  items: UnitConverter.displayUnits
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedUnit = val);
                    }
                  },
                ),
                const SizedBox(height: 14),

                // Current Stock - DECIMAL ENABLED
                TextField(
                  controller: stockController,
                  decoration: _inputDecoration("Stok Saat Ini ($selectedUnit)"),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                  ],
                  style: GoogleFonts.lexendDeca(fontSize: 14),
                ),
                const SizedBox(height: 14),

                // Min Stock Alert - DECIMAL ENABLED
                TextField(
                  controller: minAlertController,
                  decoration: _inputDecoration(
                    "Batas Stok Minimum ($selectedUnit)",
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                  ],
                  style: GoogleFonts.lexendDeca(fontSize: 14),
                ),
              ],
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
                final name = nameController.text.trim();
                final stockText = stockController.text.trim().replaceAll(
                  ',',
                  '.',
                );
                final minAlertText = minAlertController.text.trim().replaceAll(
                  ',',
                  '.',
                );

                if (name.isEmpty || stockText.isEmpty) {
                  _showSnackBar("Nama dan stok harus diisi", isError: true);
                  return;
                }

                final inputStock = double.tryParse(stockText);
                final inputMinAlert = double.tryParse(minAlertText) ?? 0;

                if (inputStock == null || inputStock < 0) {
                  _showSnackBar("Masukkan stok yang valid", isError: true);
                  return;
                }

                // Convert to base unit
                final baseUnit = UnitConverter.getBaseUnit(selectedUnit);
                final stockInBaseUnit = UnitConverter.toBaseUnit(
                  inputStock,
                  selectedUnit,
                );
                final minAlertInBaseUnit = UnitConverter.toBaseUnit(
                  inputMinAlert,
                  selectedUnit,
                );

                Navigator.pop(ctx);

                try {
                  if (isEdit) {
                    await _ingredientController.updateIngredient(
                      Ingredient(
                        id: ingredient.id,
                        name: name,
                        stockInBaseUnit: stockInBaseUnit,
                        baseUnit: baseUnit,
                        minStockAlert: minAlertInBaseUnit,
                      ),
                    );
                    _showSnackBar("Bahan berhasil diupdate");
                  } else {
                    await _ingredientController.addIngredient(
                      Ingredient(
                        name: name,
                        stockInBaseUnit: stockInBaseUnit,
                        baseUnit: baseUnit,
                        minStockAlert: minAlertInBaseUnit,
                      ),
                    );
                    _showSnackBar("Bahan berhasil ditambahkan");
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

  /// Show Restock Dialog (Increment stock) with decimal support
  void _showRestockDialog(Ingredient ingredient) {
    final amountController = TextEditingController();

    // Use best display unit for restock
    String selectedUnit = UnitConverter.getBestDisplayUnit(
      ingredient.stockInBaseUnit,
      ingredient.baseUnit,
    );

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
              const Icon(
                Icons.add_shopping_cart_rounded,
                color: AppColors.success,
              ),
              const SizedBox(width: 10),
              Text(
                "Belanja Stok",
                style: GoogleFonts.lexendDeca(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ingredient.name,
                style: GoogleFonts.lexendDeca(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                "Stok saat ini: ${ingredient.displayStock}",
                style: GoogleFonts.lexendDeca(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),

              // Unit selector for restock
              DropdownButtonFormField<String>(
                initialValue: selectedUnit,
                decoration: _inputDecoration("Satuan"),
                style: GoogleFonts.lexendDeca(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                items:
                    (ingredient.baseUnit == 'gram'
                            ? ['Gram', 'Kilogram']
                            : ['MiliLiter', 'Liter'])
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedUnit = val);
                  }
                },
              ),
              const SizedBox(height: 14),

              // Amount input - DECIMAL ENABLED
              TextField(
                controller: amountController,
                decoration: _inputDecoration("Jumlah Tambahan ($selectedUnit)"),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                ],
                style: GoogleFonts.lexendDeca(fontSize: 14),
                autofocus: true,
              ),
            ],
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
                final amountText = amountController.text.trim().replaceAll(
                  ',',
                  '.',
                );
                final inputAmount = double.tryParse(amountText);

                if (inputAmount == null || inputAmount <= 0) {
                  _showSnackBar("Masukkan jumlah yang valid", isError: true);
                  return;
                }

                // Convert to base unit
                final amountInBaseUnit = UnitConverter.toBaseUnit(
                  inputAmount,
                  selectedUnit,
                );

                Navigator.pop(ctx);

                try {
                  await _ingredientController.restockIngredient(
                    ingredient.id!,
                    amountInBaseUnit,
                  );
                  _showSnackBar(
                    "Berhasil menambah ${_formatDouble(inputAmount)} $selectedUnit",
                  );
                } catch (e) {
                  _showSnackBar("Error: $e", isError: true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                "Tambah Stok",
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

  /// Confirm delete dialog
  void _confirmDelete(Ingredient ingredient) {
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
              "Hapus Bahan?",
              style: GoogleFonts.lexendDeca(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          "Anda yakin ingin menghapus \"${ingredient.name}\"? Tindakan ini tidak dapat dibatalkan.",
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
                await _ingredientController.deleteIngredient(ingredient.id!);
                _showSnackBar("Bahan berhasil dihapus");
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

  String _formatDouble(double value) {
    if (value == value.toInt().toDouble()) {
      return value.toInt().toString();
    }
    String formatted = value.toStringAsFixed(2);
    if (formatted.contains('.')) {
      formatted = formatted.replaceAll(RegExp(r'0+$'), '');
      formatted = formatted.replaceAll(RegExp(r'\.$'), '');
    }
    return formatted;
  }
}
