import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:gal/gal.dart';
import 'dart:io';

class ResizeScreen extends StatefulWidget {
  const ResizeScreen({super.key});

  @override
  State<ResizeScreen> createState() => _ResizeScreenState();
}

class _ResizeScreenState extends State<ResizeScreen> {
  File? _image;
  File? _compressedImage;
  bool _isLoading = false;
  int _quality = 85;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _compressedImage = null;
      });
    }
  }

  Future<void> _compressImage() async {
    if (_image == null) return;
    setState(() => _isLoading = true);
    try {
      final targetPath = '${_image!.path}_compressed.jpg';
      final result = await FlutterImageCompress.compressAndGetFile(
        _image!.absolute.path,
        targetPath,
        quality: _quality,
      );
      if (result != null) {
        setState(() => _compressedImage = File(result.path));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveToGallery() async {
    if (_compressedImage == null) return;
    await Gal.putImage(_compressedImage!.path);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compressed image saved to gallery!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Batch Resizer')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text('Select Image'),
            ),
            const SizedBox(height: 16),
            if (_image != null) ...[
              Text('Quality: $_quality%'),
              Slider(
                value: _quality.toDouble(),
                min: 10,
                max: 100,
                divisions: 9,
                onChanged: (val) => setState(() => _quality = val.toInt()),
              ),
              ElevatedButton(
                onPressed: _isLoading ? null : _compressImage,
                child: _isLoading ? const CircularProgressIndicator() : const Text('Process & Compress'),
              ),
            ],
            const SizedBox(height: 20),
            if (_compressedImage != null) ...[
              const Text('Ready for Export', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _saveToGallery,
                icon: const Icon(Icons.download),
                label: const Text('Save to Gallery'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
