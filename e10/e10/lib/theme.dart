import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const honey = Color(0xFF2D8CDE);
  static const honeyDark = Color(0xFF1668B7);
  static const honeyDeep = Color(0xFF0B4F91);
  static const honeyLight = Color(0xFFB9E2FF);
  static const ink = Color(0xFF063B73);
  static const inkMid = Color(0xFF0A579E);
  static const inkBlue = Color(0xFF1676D2);
  static const inkGlow = Color(0xFF59B8F5);
  static const navy = Color(0xFF073E78);
  static const navyMid = Color(0xFF0A579E);
  static const navyLight = Color(0xFF2D8CDE);
  static const sky = Color(0xFF39A9E8);
  static const skyLight = Color(0xFF9AD7F7);
  static const blue = Color(0xFF1676D2);
  static const icon = Color(0xFF1676D2);
  // These carry meaning (success/error/warning/category), not brand — they
  // must stay visually distinct from each other and from the school's own
  // brand/accent colour no matter what that brand colour is, or a status
  // badge or a form's error state silently loses its meaning. A previous
  // pass collapsed every one of these onto near-identical shades of blue
  // (e.g. `error: AppColors.rose` in AppTheme.build() below was rendering
  // form/validation errors in light blue); restored to their own hues.
  static const emerald = Color(0xFF10B981);
  static const teal = Color(0xFF14B8A6);
  static const tealDark = Color(0xFF0D9488);
  static const rose = Color(0xFFF43F5E);
  static const roseDark = Color(0xFFE11D48);
  static const amber = Color(0xFFF59E0B);
  static const orange = Color(0xFFF97316);
  static const violet = Color(0xFF8B5CF6);

  /// Distinct colours for dashboard icons, so each tile is easy to tell apart.
  static const iconPalette = [blue, emerald, orange, rose, violet, teal];
  static const purple = Color(0xFFA855F7);
  static const indigo = Color(0xFF6366F1);

  static const slate50 = Color.fromARGB(255, 248, 250, 252);
  static const slate100 = Color.fromARGB(255, 241, 245, 249);
  static const slate200 = Color.fromARGB(255, 226, 232, 240);
  static const slate300 = Color.fromARGB(255, 203, 213, 225  );
  static const slate400 = Color.fromARGB(255, 148, 163, 184);
  static const slate500 = Color.fromARGB(255, 100, 116, 139);
  static const slate600 = Color.fromARGB(255, 71, 85, 105);
  static const slate700 = Color.fromARGB(255, 51, 65, 85);
  static const slate800 = Color.fromARGB(255, 30, 41, 59);

  static const border = Color.fromARGB(255, 229, 231, 235);
  static const card = Colors.white;
  static const page = Color(0xFFF1F8FE);
  static const accent = Color(0xFF1676D2);
  static const accentSoft = Color(0xFFE2F2FE);
  static const navLight = Color(0xFFF1F8FE);
  static const night = Color(0xFF062D56);
  static const nightCard = Color(0xFF073E78);
  static const nightLine = Color(0xFF0A579E);
  static const headerStart = Color(0xFF1676D2);
  static const headerMid = Color(0xFF2D8CDE);
  static const headerEnd = Color(0xFF59B8F5);
  static const jumpA = Color(0xFF1676D2);
  static const jumpB = Color(0xFF39A9E8);
  static const jumpC = Color(0xFF2D8CDE);
  static const jumpD = Color(0xFF9AD7F7);
}

class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
}

class AppRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 18.0;
  static const xl = 22.0;
  static const sheet = 26.0;
}

class AppSurface {
  static bool dark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

  static Color page(BuildContext context) => dark(context) ? AppColors.night : AppColors.page;

  static Color card(BuildContext context) => dark(context) ? AppColors.night : Colors.white;

  static Color cardSoft(BuildContext context) => dark(context) ? AppColors.night : const Color(0xFFF7F8FA);

  static Color line(BuildContext context) => dark(context) ? AppColors.night : AppColors.border;

  static Color text(BuildContext context) => dark(context) ? const Color(0xFFF1F5FF) : AppColors.slate800;

  /// Dashboard text: plain black (light in dark mode so it stays readable).
  static Color ink(BuildContext context) => dark(context) ? const Color(0xFFF1F5FF) : Colors.black;

  static Color muted(BuildContext context) => dark(context) ? const Color(0xFFD5E2F5) : AppColors.slate500;

  static Color iconOnCard(BuildContext context) => dark(context) ? const Color(0xFFF1F5FF) : brand(context);

  /// The school's own brand colour (admin's `primary_color`/`accent_color`
  /// on the website, threaded into the app's ColorScheme seed in main.dart)
  /// — the dynamic replacement for the old hardcoded `AppColors.icon` /
  /// `AppColors.honeyDark` / `AppColors.headerStart` blue used for icons,
  /// links and accents throughout the app.
  static Color brand(BuildContext context) => Theme.of(context).colorScheme.primary;
}

class AppIconSize {
  static const sidebar = 20.0;
  static const button = 18.0;
  static const table = 18.0;
  static const page = 20.0;
  static const card = 20.0;
}

class AppLayout {
  static const wideBreakpoint = 960.0;
  static const sheetBreakpoint = 720.0;

  static bool wide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wideBreakpoint;

  static bool useSheet(BuildContext context) =>
      MediaQuery.sizeOf(context).width < sheetBreakpoint;

  static int statColumns(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 1100) return 3;
    if (w >= 700) return 3;
    return 2;
  }

  static EdgeInsets page(BuildContext context) {
    return EdgeInsets.fromLTRB(16, 12, 16, 24);
  }
}

class AppGradients {
  static const header = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.headerStart, AppColors.headerMid, AppColors.headerEnd],
  );

  static const honey = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.jumpA, AppColors.jumpC, AppColors.sky],
  );

  static const chrome = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.ink, AppColors.inkMid, AppColors.headerStart],
  );

  static const chromeBar = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.navy, AppColors.navyMid, AppColors.ink],
  );

  static const navy = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.ink, AppColors.inkMid, AppColors.inkBlue],
    stops: [0, 0.5, 1],
  );

  static const sky = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.sky, AppColors.blue],
  );

  static const emerald = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.emerald, AppColors.tealDark],
  );

  static const rose = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.rose, AppColors.roseDark],
  );

  static const amber = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.amber, AppColors.orange],
  );

  static const violet = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.violet, AppColors.indigo],
  );

  static const qrCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
  );
}

class AppShadows {
  static List<BoxShadow> get card => [
        BoxShadow(
          color: const Color(0xFF0F2744).withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get blueGlow => [
        BoxShadow(
          color: AppColors.accent.withValues(alpha: 0.35),
          blurRadius: 14,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get honeyGlow => [
        BoxShadow(
          color: AppColors.honey.withValues(alpha: 0.18),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get skyGlow => [
        BoxShadow(
          color: AppColors.sky.withValues(alpha: 0.16),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];
}

class AppText {
  static TextStyle display({
    double size = 18,
    FontWeight weight = FontWeight.w600,
    Color? color,
    double height = 1.25,
    double? letterSpacing,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.4,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle label({
    double size = 13,
    FontWeight weight = FontWeight.w500,
    Color? color,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: 0.1,
      height: 1.25,
    );
  }
}

class AppType {
  static TextStyle get pageTitle => AppText.display(size: 20, weight: FontWeight.w700);
  static TextStyle get section => AppText.display(size: 16, weight: FontWeight.w700);
  static TextStyle get cardTitle => AppText.body(size: 15, weight: FontWeight.w600);
  static TextStyle get body => AppText.body(size: 14);
  static TextStyle get table => AppText.body(size: 13);
  static TextStyle get sidebar => AppText.body(size: 14);
  static TextStyle get button => AppText.body(size: 14, weight: FontWeight.w600);
  static TextStyle get formLabel => AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.slate600);
  static TextStyle get caption => AppText.body(size: 12, weight: FontWeight.w500, color: AppColors.slate500);
  static TextStyle get number => AppText.display(size: 20, weight: FontWeight.w700);
}

class AppTheme {
  static ThemeData get light => build(brightness: Brightness.light, seed: AppColors.blue);

  static ThemeData get dark => build(brightness: Brightness.dark, seed: AppColors.blue);

  static ThemeData build({required Brightness brightness, required Color seed, Color? accent}) {
    final dark = brightness == Brightness.dark;
    final page = dark ? AppColors.night : AppColors.page;
    final surface = dark ? AppColors.night : Colors.white;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: page,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
        primary: seed,
        secondary: accent,
        surface: surface,
        error: AppColors.rose,
      ),
    );
    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(textStyle: base.textTheme.displayLarge),
        displayMedium: GoogleFonts.plusJakartaSans(textStyle: base.textTheme.displayMedium),
        displaySmall: GoogleFonts.plusJakartaSans(textStyle: base.textTheme.displaySmall),
        headlineLarge: GoogleFonts.plusJakartaSans(textStyle: base.textTheme.headlineLarge),
        headlineMedium: GoogleFonts.plusJakartaSans(textStyle: base.textTheme.headlineMedium),
        headlineSmall: GoogleFonts.plusJakartaSans(textStyle: base.textTheme.headlineSmall),
        titleLarge: GoogleFonts.plusJakartaSans(textStyle: base.textTheme.titleLarge),
      ).apply(
        bodyColor: dark ? const Color(0xFFE2E8F0) : AppColors.slate700,
        displayColor: dark ? Colors.white : AppColors.slate800,
      ),
      splashFactory: InkRipple.splashFactory,
      dividerColor: dark ? AppColors.night : AppColors.border,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: dark ? AppColors.night : AppColors.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        insetPadding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        titleTextStyle: AppText.display(size: 17, weight: FontWeight.w600, color: dark ? Colors.white : AppColors.navy),
        contentTextStyle: AppText.body(size: 14, color: dark ? const Color(0xFF94A3B8) : AppColors.slate500),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        insetPadding: EdgeInsets.fromLTRB(12, 8, 12, 12),
        elevation: 2,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surface,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      iconTheme: IconThemeData(color: seed, size: 18),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: seed,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          highlightColor: seed.withValues(alpha: 0.08),
          padding: const EdgeInsets.all(6),
          minimumSize: const Size(36, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          iconSize: 20,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        prefixIconColor: seed,
        prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        filled: true,
        fillColor: dark ? const Color(0xFF12243F) : Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        hintStyle: AppText.body(size: 14, color: AppColors.slate400),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: dark ? const Color(0xFF1E3A5F) : AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: dark ? const Color(0xFF1E3A5F) : AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: seed, width: 1.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: seed,
          foregroundColor: Colors.white,
          textStyle: AppType.button,
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: seed,
          textStyle: AppText.body(size: 14, weight: FontWeight.w500),
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: AppText.body(size: 13, weight: FontWeight.w500, color: AppColors.slate500),
        dataTextStyle: AppType.table,
        headingRowHeight: 36,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 44,
        headingRowColor: WidgetStatePropertyAll(dark ? const Color(0xFF12243F) : AppColors.slate50),
        dividerThickness: 0.6,
      ),
    );
  }
}

class Tone {
  final Color from;
  final Color to;
  final Color text;
  final Color softBg;
  final Color softText;

  const Tone({
    required this.from,
    required this.to,
    required this.text,
    required this.softBg,
    required this.softText,
  });

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [from, to],
      );

  static const sky = Tone(
    from: AppColors.sky,
    to: AppColors.blue,
    text: AppColors.sky,
    softBg: Color(0xFFF1F5F9),
    softText: AppColors.slate600,
  );
  static const emerald = Tone(
    from: AppColors.emerald,
    to: AppColors.teal,
    text: AppColors.emerald,
    softBg: Color(0xFFECFDF5),
    softText: AppColors.emerald,
  );
  static const honey = Tone(
    from: AppColors.headerStart,
    to: AppColors.headerEnd,
    text: AppColors.headerMid,
    softBg: AppColors.accentSoft,
    softText: AppColors.headerEnd,
  );
  static const rose = Tone(
    from: AppColors.rose,
    to: AppColors.roseDark,
    text: AppColors.roseDark,
    softBg: Color(0xFFFFE4E6),
    softText: AppColors.roseDark,
  );
  static const violet = Tone(
    from: AppColors.violet,
    to: AppColors.indigo,
    text: AppColors.indigo,
    softBg: Color(0xFFF3E8FF),
    softText: AppColors.indigo,
  );
  static const slate = Tone(
    from: AppColors.slate400,
    to: AppColors.slate600,
    text: AppColors.slate600,
    softBg: AppColors.slate100,
    softText: AppColors.slate600,
  );

  static Tone named(String name) {
    switch (name) {
      case 'sky':
        return sky;
      case 'emerald':
        return emerald;
      case 'honey':
      case 'amber':
        return honey;
      case 'rose':
        return rose;
      case 'violet':
      case 'purple':
        return violet;
      default:
        return slate;
    }
  }
}
