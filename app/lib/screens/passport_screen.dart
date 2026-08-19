import 'package:flutter/material.dart';

class PassportScreen extends StatelessWidget {
  const PassportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Passport Photo Maker')),
      body: const Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Standard ID Specs:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 12),
            ListTile(leading: Icon(Icons.check_circle, color: Colors.green), title: Text('2x2 inches (US Visa / Passport)')),
            ListTile(leading: Icon(Icons.check_circle, color: Colors.green), title: Text('35x45 mm (EU / Schengen ID)')),
            ListTile(leading: Icon(Icons.check_circle, color: Colors.green), title: Text('Automatic face centering & background cleanup')),
          ],
        ),
      ),
    );
  }
}
