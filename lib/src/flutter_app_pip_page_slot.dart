import 'package:flutter/widgets.dart';

import 'flutter_app_pip_content_host.dart';
import 'flutter_app_pip_controller.dart';

class FlutterAppPipPageSlot extends StatelessWidget {
  const FlutterAppPipPageSlot({
    super.key,
    required this.controller,
    required this.builder,
    this.placeholder = const SizedBox.shrink(),
  });

  final FlutterAppPipController controller;
  final FlutterAppPipContentBuilder builder;
  final Widget placeholder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FlutterAppPipContentHost>(
      valueListenable: controller.contentHost,
      builder: (context, host, child) {
        if (host == FlutterAppPipContentHost.page) {
          return builder(context, controller.contentKey);
        }
        return child!;
      },
      child: placeholder,
    );
  }
}
