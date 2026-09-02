import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';

import 'presentation/player_pip_demo_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const PlayerPipDemoApp());
}
