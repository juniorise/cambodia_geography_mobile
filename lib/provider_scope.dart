import 'package:cambodia_geography/app.dart';
import 'package:cambodia_geography/exports/exports.dart';
import 'package:cambodia_geography/models/apis/user_token_model.dart';
import 'package:cambodia_geography/providers/locale_provider.dart';
import 'package:cambodia_geography/providers/theme_provider.dart';
import 'package:cambodia_geography/providers/user_provider.dart';
import 'package:provider/provider.dart';

class ProviderScope extends StatelessWidget {
  const ProviderScope({
    Key? key,
    required this.initialIsDarkMode,
    required this.initialLocale,
    required this.userToken,
    required this.initialRoute,
  }) : super(key: key);

  final bool initialIsDarkMode;
  final Locale? initialLocale;
  final UserTokenModel? userToken;
  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider(initialIsDarkMode)),
        ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider(initialLocale)),
        ChangeNotifierProvider<UserProvider>(create: (_) => UserProvider(userToken)),
      ],
      child: App(initialRoute: initialRoute),
    );
  }
}
