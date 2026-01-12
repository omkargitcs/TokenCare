import 'package:flutter/material.dart';

const Color tealColor = Color(0xFF26A69A);
const Color blueColor = Color(0xFF42A5F5);
const Color primaryWhite = Color(0xFFFFFFFF);
const Color lightGrey = Color(0xFFF5F5F5);
const Color darkGrey = Color(0xFF757575);

const TextStyle titleTextStyle = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.bold,
  color: primaryWhite,
);

const TextStyle headingTextStyle = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.bold,
  color: tealColor,
);

const TextStyle bodyTextStyle = TextStyle(fontSize: 16, color: darkGrey);

const TextStyle cardTitleStyle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w600,
  color: tealColor,
);

const TextStyle largeNumberStyle = TextStyle(
  fontSize: 48,
  fontWeight: FontWeight.bold,
  color: tealColor,
);

ThemeData appTheme() {
  return ThemeData(
    primarySwatch: Colors.teal,
    scaffoldBackgroundColor: primaryWhite,
    appBarTheme: const AppBarTheme(
      backgroundColor: tealColor,
      foregroundColor: primaryWhite,
      elevation: 2,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: tealColor,
        foregroundColor: primaryWhite,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
