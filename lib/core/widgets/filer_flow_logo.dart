import 'package:flutter/material.dart';

class FilerFlowLogo extends StatelessWidget {
  const FilerFlowLogo({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/app_logo_splash_gold.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
    );
  }
}
