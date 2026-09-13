import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'routes/app_routes.dart';
import 'routes/app_pages.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zhnpfgqbnxmfvueuzlot.supabase.co',
    anonKey: 'sb_publishable_QAwO_LRv9PurbDoYU0FSdA_oW-tkEX8',
  );

  runApp(const VividlyAdminApp());
}

class VividlyAdminApp extends StatelessWidget {
  const VividlyAdminApp({super.key});

      @override
      Widget build(BuildContext context) {
        return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vividly Admin',

      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
      ),

      initialRoute: AppRoutes.admin,

      routes: AppPages.routes,

      onGenerateRoute: AppPages.onGenerateRoute,
    );
  }
}