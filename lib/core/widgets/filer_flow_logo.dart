import 'package:fbr_tax_helper/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class FilerFlowLogo extends StatelessWidget {
  const FilerFlowLogo({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + 28,
      height: size + 28,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 28,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 20,
            child: Container(
              width: size * 0.48,
              height: size * 0.52,
              decoration: BoxDecoration(
                color: const Color(0xFFF6F7F4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.description_outlined,
                color: AppColors.primary,
              ),
            ),
          ),
          Positioned(
            left: 17,
            right: 17,
            bottom: 17,
            height: size * 0.50,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Align(
                alignment: Alignment(-0.45, 0),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              width: size * 0.34,
              height: size * 0.34,
              decoration: const BoxDecoration(
                color: AppColors.gold,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.trending_up_rounded,
                color: AppColors.primaryDark,
                size: 23,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
