// lib/main.dart — App entry point
// Dev: rahulpr2000 | RAHUL PR | Marrty LLC

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/network/api_client.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ApiClient.instance.init();
  runApp(
    const ProviderScope(
      child: MarrtyApp(),
    ),
  );
}
