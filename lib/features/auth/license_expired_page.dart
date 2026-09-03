// lib/features/auth/license_expired_page.dart
// 授權到期頁

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/lk_auth_service.dart';

class LicenseExpiredPage extends StatelessWidget {
  final String message;
  const LicenseExpiredPage({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.red.shade900,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_outline,
                      color: Colors.white, size: 44),
                ),
                const SizedBox(height: 24),
                const Text(
                  '授權已失效',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: const TextStyle(color: Colors.white60, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () async {
                    // LkAuthService 的清除 session 方法叫 logout()（等同舊
                    // WebAuthService.clearSession()：清掉 SharedPreferences
                    // 中的 session，但保留 device id）。
                    await LkAuthService.logout();
                    if (context.mounted) context.go('/lk');
                  },
                  icon: const Icon(Icons.logout, color: Colors.white54),
                  label: const Text('重新驗證身份',
                      style: TextStyle(color: Colors.white54)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
