import 'package:flutter/material.dart';

class StateMigrationNextPage extends StatelessWidget {
  const StateMigrationNextPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Another Page')),
      body: const Center(
        child: Text(
          'The live player remains in the PiP window.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
