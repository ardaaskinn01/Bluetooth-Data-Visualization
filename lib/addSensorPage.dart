import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:io';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'databaseHelper.dart';
import 'device.dart'; // Cihaz modelini ekle

class AddSensorPage extends StatefulWidget {
  @override
  _AddSensorPageState createState() => _AddSensorPageState();
}

class _AddSensorPageState extends State<AddSensorPage> {
  List<BluetoothDevice> devicesList = [];
  bool isScanning = false;
  late StreamSubscription<BluetoothAdapterState> _adapterStateSubscription;
  late StreamSubscription<List<ScanResult>> _scanResultSubscription;
  final DatabaseHelper databaseHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
      if (state == BluetoothAdapterState.on) {
        startScan();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Bluetooth kapalı, lütfen açın.")),
        );
      }
    });
  }

  @override
  void dispose() {
    _adapterStateSubscription.cancel();
    _scanResultSubscription.cancel();
    super.dispose();
  }

  void startScan() async {
    if (await FlutterBluePlus.isSupported == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Bu cihaz Bluetooth'u desteklemiyor.")),
      );
      return;
    }

    if (Platform.isAndroid) {
      await FlutterBluePlus.turnOn();
    }

    setState(() {
      isScanning = true;
      devicesList.clear(); // Tarama öncesi cihaz listesini temizle
    });

    try {
      await FlutterBluePlus.adapterState.where((val) => val == BluetoothAdapterState.on).first;

      _scanResultSubscription = FlutterBluePlus.onScanResults.listen((results) {
        if (results.isNotEmpty) {
          for (var r in results) {
            if (!devicesList.contains(r.device)) {
              setState(() {
                devicesList.add(r.device);
              });
            }
          }
        }
      }, onError: (e) => print(e));

      await FlutterBluePlus.startScan(timeout: Duration(seconds: 12));
      await FlutterBluePlus.isScanning.where((val) => val == false).first;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Tarama sırasında bir hata oluştu: $e")),
      );
    } finally {
      setState(() {
        isScanning = false;
      });
      FlutterBluePlus.stopScan();
    }
  }

  void connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      var newDevice = Device(
        uuid: device.id.toString(),
        name: device.name,
        temperature: 0.0,
        temperatureHistory: [],
        isConnected: 2,
        bluetoothDevice: device,
      );

      // Cihazı yalnızca başarılı bir şekilde bağlandıktan sonra kaydedin
      await addDevice(newDevice);

    } catch (e) {
      // Bağlanırken bir hata oluşursa
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Bağlanırken bir hata oluştu: $e")),
      );
    }
  }

  Future<void> saveDeviceToDatabase(Device device) async {
    await databaseHelper.insertDevice(device);
  }

  Future<bool> checkIfDeviceExists(Device device) async {
    return await databaseHelper.deviceExists(device.name);
  }

  Future<void> addDevice(Device device) async {
    try {
      // Burada veritabanına kayıt işlemi yapılacak.
      // Örneğin, SQLite veritabanı kullanıyorsanız ilgili ekleme kodlarını buraya ekleyin.
      bool deviceExists = await checkIfDeviceExists(device);

      // Eğer cihaz daha önce eklenmemişse, ekle
      if (!deviceExists) {
        await saveDeviceToDatabase(device); // Cihazı veritabanına kaydet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cihaz başarıyla kaydedildi.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Cihaz zaten mevcut: ${device.name}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Cihaz kaydedilirken hata: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bluetooth Cihazlarını Tara'),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: isScanning ? null : startScan,
              child: Text(
                isScanning ? 'Taranıyor...' : 'Cihazları Tara',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: EdgeInsets.symmetric(vertical: 15.0, horizontal: 30.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: devicesList.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: EdgeInsets.all(8.0),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                  child: ListTile(
                    title: Text(
                      devicesList[index].name.isNotEmpty ? devicesList[index].name : 'N/A',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(devicesList[index].remoteId.toString()),
                    onTap: () => connectToDevice(devicesList[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}