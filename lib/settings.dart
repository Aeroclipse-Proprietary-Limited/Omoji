// lib/settings.dart

import 'dart:ui'; // Required for ImageFilter.blur
import 'package:flutter/material.dart';
import 'package:omoji/main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showCardForm = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white.withValues(alpha: 0.7) : Colors.black.withValues(alpha: 0.6);
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03);
    final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF2E2E2E).withValues(alpha: 0.65),
                        const Color(0xFF1A1A1A).withValues(alpha: 0.45),
                        const Color(0xFF121212).withValues(alpha: 0.75),
                      ]
                    : [
                        const Color(0xFFFFFFFF).withValues(alpha: 0.65),
                        const Color(0xFFE0E0E0).withValues(alpha: 0.45),
                        const Color(0xFFF5F5F5).withValues(alpha: 0.75),
                      ],
                stops: const [0.0, 0.4, 1.0],
              ),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          color: textColor,
                          splashRadius: 20,
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Settings',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Section: Theme
                    Text(
                      'App Theme',
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: themeNotifier,
                      builder: (context, currentTheme, _) {
                        return Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorderColor),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildThemeOption(
                                  context: context,
                                  label: 'Dark',
                                  icon: Icons.dark_mode_rounded,
                                  isActive: currentTheme == ThemeMode.dark,
                                  onTap: () => themeNotifier.value = ThemeMode.dark,
                                ),
                              ),
                              Expanded(
                                child: _buildThemeOption(
                                  context: context,
                                  label: 'Light',
                                  icon: Icons.light_mode_rounded,
                                  isActive: currentTheme == ThemeMode.light,
                                  onTap: () => themeNotifier.value = ThemeMode.light,
                                ),
                              ),
                              Expanded(
                                child: _buildThemeOption(
                                  context: context,
                                  label: 'System',
                                  icon: Icons.settings_brightness_rounded,
                                  isActive: currentTheme == ThemeMode.system,
                                  onTap: () => themeNotifier.value = ThemeMode.system,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Section: Developer Information
                    Text(
                      'Developer',
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorderColor),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.teal.withValues(alpha: 0.2),
                            child: const Icon(Icons.person_rounded, color: Colors.teal),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kevin Manda',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Creator of Omoji',
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section: Donation / Support
                    Text(
                      'Support Development',
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorderColor),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.coffee_rounded, color: Colors.amber, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'buy me a coffee',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDonationButton(
                                  context: context,
                                  label: 'card',
                                  icon: Icons.credit_card_rounded,
                                  color: Colors.teal,
                                  isActive: _showCardForm,
                                  onTap: () {
                                    setState(() {
                                      _showCardForm = !_showCardForm;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildDonationButton(
                                  context: context,
                                  label: 'eth/ doge',
                                  icon: Icons.currency_bitcoin_rounded,
                                  color: Colors.amber[700]!,
                                  isActive: false,
                                  onTap: () {
                                    setState(() {
                                      _showCardForm = false; // Hide card form if they click crypto
                                    });
                                    debugPrint('Donate with Crypto clicked');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Crypto donation coming soon!'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (_showCardForm) ...[
                            const SizedBox(height: 20),
                            Divider(color: isDark ? Colors.white10 : Colors.black12),
                            const SizedBox(height: 12),
                            _buildCardForm(context, textColor, cardBg, cardBorderColor),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = Colors.teal;
    final textColor = isDark ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.white : (isDark ? Colors.white54 : Colors.black54),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : textColor,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonationButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.3) : color.withValues(alpha: 0.15),
          border: Border.all(color: isActive ? color : color.withValues(alpha: 0.4), width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardForm(BuildContext context, Color textColor, Color cardBg, Color cardBorderColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Card Information',
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        // Card Number
        _buildTextField(
          context: context,
          hintText: '1234 5678 1234 5678',
          labelText: 'Card Number',
          icon: Icons.credit_card,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        // Expiry & CVV Row
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                context: context,
                hintText: 'MM/YY',
                labelText: 'Expiry Date',
                icon: Icons.calendar_month,
                keyboardType: TextInputType.datetime,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                context: context,
                hintText: '123',
                labelText: 'CVV',
                icon: Icons.lock_outline,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Name
        _buildTextField(
          context: context,
          hintText: 'John Doe',
          labelText: 'Cardholder Name',
          icon: Icons.person_outline,
          keyboardType: TextInputType.name,
        ),
        const SizedBox(height: 18),
        // Submit Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.tealAccent),
                      SizedBox(width: 8),
                      Text('Thank you! Donation successful.'),
                    ],
                  ),
                  backgroundColor: Color(0xFF1E3A2F),
                  duration: Duration(seconds: 3),
                ),
              );
              setState(() {
                _showCardForm = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Donate \$5.00',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required String hintText,
    required String labelText,
    required IconData icon,
    required TextInputType keyboardType,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final inputBg = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03);
    final border = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          keyboardType: keyboardType,
          style: TextStyle(color: textColor, fontSize: 13),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: textColor.withValues(alpha: 0.35), fontSize: 13),
            prefixIcon: Icon(icon, color: Colors.teal, size: 16),
            filled: true,
            fillColor: inputBg,
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.teal.withValues(alpha: 0.6), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
