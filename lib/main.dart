import 'package:bluetooth_projesi/provider.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'sensors.dart';
import 'addSensorPage.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => TemperatureProvider(),
        ),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    SensorsPage(), // Sensörlerim sayfası
    AddSensorPage(), // Sensör ekle sayfası
  ];

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index; // Seçili sayfa index'ini güncelle
    });
  }

  @override
  void initState() {
    super.initState();
    requestPermissions(); // İzinleri al
  }

  void requestPermissions() async {
    var bluetoothConnectStatus = await Permission.bluetoothConnect.status;
    if (!bluetoothConnectStatus.isGranted) {
      await Permission.bluetoothConnect.request();
    }
    var bluetoothScanStatus = await Permission.bluetoothScan.status;
    if (!bluetoothScanStatus.isGranted) {
      await Permission.bluetoothScan.request();
    }
    var locationStatus = await Permission.location.status;
    if (!locationStatus.isGranted) {
      await Permission.location.request();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex], // Seçilen sayfayı göster
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Sensörlerim',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add),
            label: 'Sensör Ekle',
          ),
        ],
        currentIndex: _currentIndex, // Seçili olan index
        onTap: _onItemTapped, // Tıklama olayını işleyen fonksiyon
        selectedItemColor: Colors.black, // Seçili öğe rengi
        unselectedItemColor: Colors.black, // Seçili olmayan öğe rengi
        backgroundColor: Colors.white, // Arka plan rengi
      ),
    );
  }
}