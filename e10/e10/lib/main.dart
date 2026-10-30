
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'app.dart';
import 'core/network/trusted_roots.dart';
import 'app_prefs.dart';
import 'school_store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installTrustedRoots();

  // Fonts ship in assets/google_fonts/. Fetching them from fonts.gstatic.com
  // on first launch delayed every screen's text on slow mobile data and
  // failed outright offline.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Use Android's system Photo Picker for image selection; it grants access
  // only to items selected by the user and needs no broad media permission.
  final imagePicker = ImagePickerPlatform.instance;
  if (imagePicker is ImagePickerAndroid) {
    imagePicker.useAndroidPhotoPicker = true;
  }

  // Load the centralized API/environment configuration.
  // A missing/unreadable .env must not leave the app stuck on the launch
  // screen; ApiConfig falls back to the live API URL.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    dotenv.testLoad(fileInput: '');
  }

  runApp(const E10Root());
}

class E10Root extends StatefulWidget {
  const E10Root({super.key});

  @override
  State<E10Root> createState() => _E10RootState();
}

class _E10RootState extends State<E10Root> {
  final store = SchoolStore();
  final prefs = AppPrefs();

  @override
  void initState() {
    super.initState();
    prefs.load();
  }

  @override
  Widget build(BuildContext context) {
    return AppPrefsScope(
      prefs: prefs,
      child: SchoolScope(
        store: store,
        child: ListenableBuilder(
          listenable: Listenable.merge([prefs, store]),
          builder: (context, child) {
            final dark = prefs.dark;

            final overlay = SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              systemNavigationBarColor:
                  dark ? AppColors.night : AppColors.navLight,
              systemNavigationBarIconBrightness:
                  dark ? Brightness.light : Brightness.dark,
              systemNavigationBarDividerColor:
                  dark ? AppColors.night : AppColors.navLight,
            );

            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: overlay,
              child: MaterialApp(
                title: 'e10 School Systems',
                debugShowCheckedModeBanner: false,

                theme: AppTheme.build(
                  brightness: Brightness.light,
                  seed: store.themeSeed ?? prefs.accent,
                  accent: store.accentSeed,
                ),

                darkTheme: AppTheme.build(
                  brightness: Brightness.dark,
                  seed: store.themeSeed ?? prefs.accent,
                  accent: store.accentSeed,
                ),

                themeMode:
                    prefs.dark ? ThemeMode.dark : ThemeMode.light,

                builder: (context, appChild) {
                  final wide = MediaQuery.sizeOf(context).width > 460;
                  final shell = appChild ?? const SizedBox.shrink();

                  // Phones/tablets fill the whole screen in either orientation;
                  // only the desktop web build keeps the centred phone frame.
                  if (!kIsWeb) {
                    return ColoredBox(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      // Landscape: keep content clear of the notch/camera cutout.
                      child: SafeArea(top: false, bottom: false, child: shell),
                    );
                  }

                  return ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 448,
                        ),
                        child: Padding(
                          padding: wide
                              ? const EdgeInsets.symmetric(
                                  vertical: 10,
                                )
                              : EdgeInsets.zero,
                          child: ClipRRect(
                            borderRadius: wide
                                ? BorderRadius.circular(
                                    AppRadius.sheet,
                                  )
                                : BorderRadius.zero,
                            child: shell,
                          ),
                        ),
                      ),
                    ),
                  );
                },

                home: child,
              ),
            );
          },
          child: const E10App(),
        ),
      ),
    );
  }
}
