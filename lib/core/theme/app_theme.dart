import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF0F6B57);
  static const primaryDark = Color(0xFF092B29);
  static const ink = Color(0xFF123D36);
  static const mint = Color(0xFF4DDBC4);
  static const mintSurface = Color(0xFFE7F0EA);
  static const mintSoft = Color(0xFFF0FBF7);
  static const gold = Color(0xFFFFC857);
  static const goldSurface = Color(0xFFFFF5D9);
  static const violet = Color(0xFF7158E2);
  static const violetSurface = Color(0xFFF0ECFF);
  static const coral = Color(0xFFFF6B6B);
  static const coralSurface = Color(0xFFFFE8E6);
  static const blue = Color(0xFF3388FF);
  static const blueSurface = Color(0xFFE8F2FF);
  static const background = Color(0xFFF0F8F5);
  static const border = Color(0xFFD7E2DC);
  static const muted = Color(0xFF65716C);
}

abstract final class AppTheme {
  static ThemeData get authenticated {
    final base = light;
    final scheme = base.colorScheme.copyWith(
      secondary: AppColors.violet,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.violetSurface,
      onSecondaryContainer: const Color(0xFF2E2461),
      tertiary: AppColors.coral,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.coralSurface,
      onTertiaryContainer: const Color(0xFF6B2525),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFFFFBF4),
      surfaceContainer: const Color(0xFFF2FAF7),
      surfaceContainerHigh: AppColors.violetSurface,
      surfaceContainerHighest: AppColors.blueSurface,
    );

    return base.copyWith(
      colorScheme: scheme,
      cardTheme: base.cardTheme.copyWith(
        color: const Color(0xFFFFFEFC),
        elevation: 2,
        shadowColor: AppColors.violet.withValues(alpha: 0.18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFBFE9DD)),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: const Color(0xFFF5F2FF),
        prefixIconColor: AppColors.violet,
        suffixIconColor: AppColors.primary,
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: const Color(0xFFFFFCF7),
        shadowColor: AppColors.violet.withValues(alpha: 0.3),
        elevation: 18,
        iconColor: AppColors.violet,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: const BorderSide(color: Color(0xFFD9D0FF)),
        ),
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        backgroundColor: const Color(0xFFF2FCF8),
        modalBackgroundColor: const Color(0xFFF2FCF8),
        modalBarrierColor: AppColors.primaryDark.withValues(alpha: 0.38),
        elevation: 14,
        modalElevation: 18,
        dragHandleColor: AppColors.violet,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          side: BorderSide(color: Color(0xFF9DE1CF)),
        ),
      ),
      popupMenuTheme: base.popupMenuTheme.copyWith(
        color: const Color(0xFFFFFBF2),
        elevation: 12,
        shadowColor: AppColors.violet.withValues(alpha: 0.24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFFFD779)),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(Color(0xFFFFFBF2)),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(12),
          shadowColor: WidgetStatePropertyAll(
            AppColors.violet.withValues(alpha: 0.24),
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: Color(0xFFFFD779)),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: const TextStyle(
          color: AppColors.ink,
          fontWeight: FontWeight.w600,
        ),
        menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(Color(0xFFFFFBF2)),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          fillColor: AppColors.blueSurface,
        ),
      ),
      datePickerTheme: base.datePickerTheme.copyWith(
        backgroundColor: const Color(0xFFFFFCF7),
        headerBackgroundColor: AppColors.violet,
        headerForegroundColor: Colors.white,
        todayBackgroundColor: const WidgetStatePropertyAll(
          AppColors.coralSurface,
        ),
        todayForegroundColor: const WidgetStatePropertyAll(AppColors.coral),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: const BorderSide(color: Color(0xFFD9D0FF)),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: const Color(0xFFFFFCF7),
        hourMinuteColor: AppColors.violetSurface,
        hourMinuteTextColor: AppColors.violet,
        dayPeriodColor: AppColors.goldSurface,
        dayPeriodTextColor: AppColors.primaryDark,
        dialBackgroundColor: AppColors.blueSurface,
        dialHandColor: AppColors.violet,
        dialTextColor: AppColors.ink,
        entryModeIconColor: AppColors.coral,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: const BorderSide(color: Color(0xFFD9D0FF)),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: Color(0xFFF2FCF8),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
          side: BorderSide(color: Color(0xFF9DE1CF)),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.primaryDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gold),
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      bannerTheme: const MaterialBannerThemeData(
        backgroundColor: AppColors.goldSurface,
        surfaceTintColor: Colors.transparent,
        contentTextStyle: TextStyle(color: AppColors.ink),
        elevation: 2,
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        iconColor: AppColors.violet,
        collapsedIconColor: AppColors.primary,
        textColor: AppColors.violet,
        collapsedTextColor: AppColors.ink,
        backgroundColor: AppColors.violetSurface,
        collapsedBackgroundColor: Color(0xFFF2FCF8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.violet,
        linearTrackColor: AppColors.violetSurface,
        circularTrackColor: AppColors.blueSurface,
      ),
    );
  }

  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.mintSurface,
      onPrimaryContainer: AppColors.ink,
      secondary: AppColors.gold,
      onSecondary: AppColors.primaryDark,
      secondaryContainer: Color(0xFFFFF1C7),
      onSecondaryContainer: Color(0xFF5E4300),
      tertiary: AppColors.mint,
      onTertiary: AppColors.primaryDark,
      surface: Color(0xFFFFFEFA),
      onSurface: AppColors.ink,
      outline: AppColors.border,
      outlineVariant: Color(0xFFE8EEEA),
      error: Color(0xFFB3261E),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: 'Roboto',
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 64,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 2,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: AppColors.gold),
        shape: Border(bottom: BorderSide(color: AppColors.gold, width: 3)),
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFFFFFEFA),
        surfaceTintColor: Colors.transparent,
        shadowColor: Color(0x22092B29),
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          side: BorderSide(color: Color(0xFFB9E6D8)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.mintSoft,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        prefixIconColor: AppColors.primary,
        suffixIconColor: AppColors.muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Color(0xFFB3261E)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Color(0xFFB3261E), width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 50),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(48, 50),
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.primaryDark,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.goldSurface,
        elevation: 2,
        height: 72,
        indicatorColor: AppColors.mint,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600),
        ),
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: AppColors.primary),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.goldSurface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.muted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.goldSurface,
        selectedColor: AppColors.primary,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.primaryDark,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFFFFFEFA),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.mintSoft,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.primary,
        textColor: AppColors.ink,
        selectedColor: AppColors.primaryDark,
        selectedTileColor: AppColors.goldSurface,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      iconTheme: const IconThemeData(color: AppColors.primary),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.mintSurface,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: const RadioThemeData(
        fillColor: WidgetStatePropertyAll(AppColors.primary),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.gold
              : AppColors.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.mintSurface,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.goldSurface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Colors.white
                : AppColors.ink,
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.primary),
          ),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primaryDark,
        unselectedLabelColor: AppColors.muted,
        indicatorColor: AppColors.gold,
        dividerColor: AppColors.border,
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: AppColors.gold,
        textColor: AppColors.primaryDark,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: AppColors.goldSurface,
        surfaceTintColor: Colors.transparent,
      ),
      datePickerTheme: const DatePickerThemeData(
        backgroundColor: AppColors.mintSoft,
        headerBackgroundColor: AppColors.primary,
        headerForegroundColor: Colors.white,
      ),
    );
  }
}
