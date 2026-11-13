import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(WhereToGoPickApp(config: AppConfig.fromEnvironment()));
}
