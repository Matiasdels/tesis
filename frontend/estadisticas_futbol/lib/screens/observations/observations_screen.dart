// TODO Implement this library.
import 'package:flutter/material.dart';

class ObservationsScreen extends StatelessWidget {
  const ObservationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Observaciones Técnicas'),
      ),
      body: const Center(
        child: Text(
          'Pantalla de Observaciones\n(Próximamente)',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}