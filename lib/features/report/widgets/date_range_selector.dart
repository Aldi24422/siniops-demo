import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';

/// Enum for date range presets
enum DateRangePreset { today, thisWeek, thisMonth, custom }

/// A professional date range selector widget with:
/// - Quick preset chips (Hari Ini, Minggu Ini, Bulan Ini)
/// - Custom date range picker
/// - Beautiful UI/UX design
class DateRangeSelector extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;
  final DateRangePreset selectedPreset;
  final ValueChanged<DateRangePreset> onPresetChanged;
  final ValueChanged<DateTimeRange> onCustomRangeSelected;

  const DateRangeSelector({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.selectedPreset,
    required this.onPresetChanged,
    required this.onCustomRangeSelected,
  });

  @override
  State<DateRangeSelector> createState() => _DateRangeSelectorState();
}

class _DateRangeSelectorState extends State<DateRangeSelector>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return DateFormat('d MMM yyyy', 'id_ID').format(date);
  }

  String _getPresetLabel(DateRangePreset preset) {
    switch (preset) {
      case DateRangePreset.today:
        return 'Hari Ini';
      case DateRangePreset.thisWeek:
        return 'Minggu Ini';
      case DateRangePreset.thisMonth:
        return 'Bulan Ini';
      case DateRangePreset.custom:
        return 'Kustom';
    }
  }

  IconData _getPresetIcon(DateRangePreset preset) {
    switch (preset) {
      case DateRangePreset.today:
        return Icons.today_rounded;
      case DateRangePreset.thisWeek:
        return Icons.date_range_rounded;
      case DateRangePreset.thisMonth:
        return Icons.calendar_month_rounded;
      case DateRangePreset.custom:
        return Icons.edit_calendar_rounded;
    }
  }

  Future<void> _showCustomDatePicker() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 2, 1, 1);
    final lastDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: DateTimeRange(
        start: widget.startDate,
        end: widget.endDate,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              secondary: AppColors.secondary,
              onSecondary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: GoogleFonts.lexendDeca(fontWeight: FontWeight.w600),
              ),
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          child: child!,
        );
      },
      helpText: 'Pilih Rentang Tanggal',
      cancelText: 'Batal',
      confirmText: 'Terapkan',
      saveText: 'Simpan',
      fieldStartHintText: 'Tanggal Mulai',
      fieldEndHintText: 'Tanggal Akhir',
    );

    if (picked != null) {
      widget.onCustomRangeSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Preset Chips
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: DateRangePreset.values.map((preset) {
                    final isSelected = widget.selectedPreset == preset;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (preset == DateRangePreset.custom) {
                                _showCustomDatePicker();
                              } else {
                                widget.onPresetChanged(preset);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.accent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getPresetIcon(preset),
                                    size: 18,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _getPresetLabel(preset),
                                    style: GoogleFonts.lexendDeca(
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Divider
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: AppColors.accent.withValues(alpha: 0.5),
            ),

            // Selected Date Range Display
            InkWell(
              onTap: _showCustomDatePicker,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Calendar icon with gradient background
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withValues(alpha: 0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.calendar_today_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Date range text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Periode Laporan',
                            style: GoogleFonts.lexendDeca(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.startDate == widget.endDate
                                ? _formatDate(widget.startDate)
                                : '${_formatDate(widget.startDate)} - ${_formatDate(widget.endDate)}',
                            style: GoogleFonts.lexendDeca(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Edit button
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: AppColors.secondary,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
