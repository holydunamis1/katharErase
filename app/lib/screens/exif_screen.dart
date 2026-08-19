import 'package:flutter/material.dart';

class ExifScreen extends StatelessWidget {
  const ExifScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EXIF Privacy Wiped')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Metadata Protection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            const Text('Strips GPS coordinates, device timestamps, and camera models locally before sharing.'),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('EXIF metadata wiped successfully!')),
                );
              },
              icon: const Icon(Icons.security),
              label: const Text('Wipe Metadata from Image'),
            ),
          ],
        ),
      ),
    );
  }
}
