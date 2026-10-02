import 'package:flutter/material.dart';
import 'home_page.dart'; // HomePage ที่สร้างไว้แล้วในส่วนที่ 0 (ไม่ต้องแก้ไข) — อยู่โฟลเดอร์เดียวกัน ไม่ต้องใส่ screens/ นำหน้า
import 'sell_item_page.dart'; // SellItemPage จากขั้นตอนที่ 3.2 — อยู่โฟลเดอร์เดียวกันเช่นกัน
import '../repositories/item_repository.dart';

class MainScaffold extends StatefulWidget {
  final ItemRepository repository;
  const MainScaffold({super.key, required this.repository});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // ตัวอย่าง: มี 2 Tab ในสัปดาห์นี้ (Home, ลงประกาศขาย) — จะเพิ่ม Tab ใหม่ในสัปดาห์ถัดไป
    final pages = [
      HomePage(repository: widget.repository),
      const SellItemPage(),
    ];

    return Scaffold(
      // IndexedStack เก็บ State ของทุก Tab ไว้พร้อมกัน สลับ Tab แล้วข้อมูลที่กรอก/เลือกไว้ไม่หาย
      // (ต่างจากการสร้าง Widget ใหม่ทุกครั้งที่สลับ Tab ซึ่งจะรีเซ็ต State ทุกครั้ง)
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.storefront), label: 'หน้าหลัก'),
          BottomNavigationBarItem(icon: Icon(Icons.add_a_photo), label: 'ลงประกาศขาย'),
        ],
      ),
    );
  }
}
