import 'package:flutter/material.dart';

class AppColors {
  // --- Sini.Ngopi Brand Palette ---
  
  // 1. ESPRESSO BOLD (Primary)
  // Warna cokelat tua gelap dari background logo kotak.
  // Gunakan untuk: AppBar, Tombol Utama, Teks Judul Penting.
  static const Color primary = Color(0xFF3E2723); 

  // 2. MOCHA BROWN (Secondary)
  // Warna cokelat susu dari gelombang di stiker.
  // Gunakan untuk: Tombol sekunder, Ikon aktif, Floating Action Button.
  static const Color secondary = Color(0xFF6D4C41); 

  // 3. GOLDEN CREMA (Accent/Tertiary)
  // Warna emas dari uap kopi di logo berwarna.
  // Gunakan untuk: Highlight harga, Diskon, atau Notifikasi penting.
  static const Color accent = Color(0xFFD7CCC8); 
  static const Color gold = Color(0xFFC5A572); // Warna emas spesifik

  // --- Neutral & Backgrounds (Modern Clean) ---
  
  // 4. LATTE FOAM (Background Aplikasi)
  // Krem sangat muda, hampir putih tapi hangat. Tidak menyakitkan mata.
  static const Color background = Color(0xFFFDFBF7); 

  // 5. MILK WHITE (Surface/Card)
  // Putih bersih untuk kartu produk atau dialog.
  static const Color surface = Color(0xFFFFFFFF);
  
  // --- Functional Colors ---
  static const Color success = Color(0xFF2E7D32); // Hijau daun tua (Elegan)
  static const Color error = Color(0xFFC62828);   // Merah tua (Tidak mencolok)
  static const Color textPrimary = Color(0xFF2D2422); // Hampir hitam, tapi cokelat sangat tua
  static const Color textSecondary = Color(0xFF795548); // Teks keterangan
}