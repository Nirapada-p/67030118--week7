import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class SellItemPage extends StatefulWidget {
  const SellItemPage({super.key});

  @override
  State<SellItemPage> createState() => _SellItemPageState();
}

class _SellItemPageState extends State<SellItemPage> {
  // รูปที่เลือก (null = ยังไม่ได้เลือก)
  File? _selectedImage;

  Future<void> pickImage() async {
    final XFile? result = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );

    // ผู้ใช้กดยกเลิก -> ออกทันที
    if (result == null) return;

    setState(() {
      _selectedImage = File(result.path);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ขายสินค้า')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_selectedImage != null)
              Image.file(_selectedImage!, height: 250, fit: BoxFit.cover)
            else
              Container(
                height: 250,
                color: Colors.grey.shade300,
                child: const Icon(Icons.image, size: 80, color: Colors.grey),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: pickImage,
              child: const Text('เลือกรูปภาพสินค้า'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                // TODO: เชื่อมกับ GeminiService ในขั้นตอนที่ 4.3
              },
              child: const Text('ให้ AI ช่วยแนะนำ'),
            ),
          ],
        ),
      ),
    );
  }
}
