import 'package:flutter/material.dart';

void main() {
  runApp(const ISpendApp());
}

class ISpendApp extends StatelessWidget {
  const ISpendApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iSpend',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: Scaffold(
        appBar: AppBar(title: const Text('iSpend')),
        body: const Center(child: Text('Welcome to iSpend')),
      ),
    );
  }
}
