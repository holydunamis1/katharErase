import 'package:flutter/material.dart';

class ResizeScreen extends StatelessWidget {
  const ResizeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Batch Resizer')),
      body: const Center(child: Text('Batch Resizer Workspace')),
    );
  }
}
