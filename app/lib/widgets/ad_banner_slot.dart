import 'package:flutter/material.dart';

class AdBannerSlot extends StatelessWidget {
  const AdBannerSlot({super.key, this.personalized = false});
  final bool personalized;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      color: Colors.grey[200],
      alignment: Alignment.center,
      child: const Text('Ad Banner Slot', style: TextStyle(color: Colors.grey, fontSize: 12)),
    );
  }
}
