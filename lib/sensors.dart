import 'dart:async';
import 'package:bluetooth_projesi/deviceProfile.dart';
import 'package:bluetooth_projesi/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'databaseHelper.dart';
import 'device.dart';

class SensorsPage extends StatefulWidget {
  @override
  _SensorsPageState createState() => _SensorsPageState();
}

class _SensorsPageState extends State<SensorsPage> {
  List<Device> addedDevices = [];
  late double lastTemp;
  late StreamSubscription<BluetoothConnectionState> _subscription;
  final StreamController<double> _temperatureStreamController = StreamController<double>.broadcast();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final Color primaryColor = Colors.blueAccent;
  final Color accentColor = Colors.orangeAccent;
  final Color backgroundColor = Colors.grey.shade200;
  final Color cardBackgroundColor = Colors.white;

  @override
  void initState() {
    super.initState();
    loadAddedDevices();

    // TemperatureManager'dan sıcaklık verilerini dinle
    TemperatureManager().temperatureStream.listen((temperature) {
      setState(() {
        lastTemp = temperature;
      });
    });
  }

  Future<void> loadAddedDevices() async {
    try {
      addedDevices = await _databaseHelper.getDevices();
      for (var device in addedDevices) {
        if (device.isConnected == 2) {
          await connectAndFetchTemperature(device);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Cihazlar yüklenirken hata oluştu: $e")),
      );
    }
    setState(() {});
  }

  Future<void> connectAndFetchTemperature(Device device) async {
    try {
      await device.bluetoothDevice.connect();
      setState(() {
        device.isConnected = 1;  // Bağlantı başarılı
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Cihaz ${device.name} bağlantısı kuruldu.")),
      );
      await fetchTemperatureForDevice(device);
    } catch (e) {
      setState(() {
        device.isConnected = 2;  // Bağlantı başarısızsa yeniden denenecek
      });
      _retryConnection(device);  // Yeniden bağlanma fonksiyonunu çağır
    }
  }

  Future<void> fetchTemperatureForDevice(Device device) async {
    const String temperatureServiceUuid = "00001809-0000-1000-8000-00805f9b34fb";
    const String temperatureCharacteristicUuid = "00002a1c-0000-1000-8000-00805f9b34fb";

    try {
      List<BluetoothService> services = await device.discoverServices();

      var temperatureService = services.firstWhere(
            (service) => service.uuid == Guid(temperatureServiceUuid),
        orElse: () => throw Exception("Sıcaklık servisi bulunamadı."),
      );

      var temperatureCharacteristic = temperatureService.characteristics.firstWhere(
            (characteristic) => characteristic.uuid == Guid(temperatureCharacteristicUuid),
        orElse: () => throw Exception("Sıcaklık karakteristiği bulunamadı."),
      );

      if (temperatureCharacteristic.properties.notify || temperatureCharacteristic.properties.indicate) {
        await temperatureCharacteristic.setNotifyValue(true);

        // Throttle the stream to emit values every 6 seconds
        final throttledStream = temperatureCharacteristic.lastValueStream.throttleTime(Duration(seconds: 6));

        // Listen to the throttled stream
        throttledStream.listen((value) {
          double temperature = processTemperatureData(value, device);
          TemperatureManager().updateTemperature(temperature); // Veriyi TemperatureManager üzerinden yay
          updateDeviceTemperature(device, temperature);
        });
      } else {
        throw Exception("Bu karakteristik ne notify ne de indicate özelliğini desteklemiyor.");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Cihaz ${device.name} sıcaklık verisi alınırken hata oluştu: $e")),
      );
    }
  }

  void updateDeviceTemperature(Device device, double temperature) {
    try {
      setState(() {
        addedDevices = addedDevices.map((d) {
          if (d.uuid == device.uuid.toString()) {
            return Device(
              uuid: d.uuid,
              name: d.name,
              temperature: d.lastReceivedTemperature ?? temperature,
              temperatureHistory: [...d.temperatureHistory, temperature],
              isConnected: 1,
              bluetoothDevice: d.bluetoothDevice,
            );
          }
          return d;
        }).toList();
      });
    } catch (e, stacktrace) {
      print("Hata updateDeviceTemperature: $e\nStacktrace: $stacktrace");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Sıcaklık güncelleme hatası: $e")),
      );
    }
  }

  double processTemperatureData(List<int> data, Device device) {
    try {
      int temperatureRaw = data[1];
      if (temperatureRaw == 0) {
        return lastTemp;
      }
      double a = 32;
      int b = temperatureRaw ~/ 24;
      double temperature = a - b;
      lastTemp = temperature;
      return temperature;
    } catch (e) {
      return lastTemp;
    }
  }

  void _removeDevice(Device device) async {
    setState(() {
      addedDevices.remove(device);
    });
    await _databaseHelper.deleteDevice(device.uuid);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("${device.name} cihazı kaldırıldı.")),
    );
  }

  void _retryConnection(Device device) {
    Timer.periodic(Duration(seconds: 10), (timer) async {
      if (device.isConnected != 2) {
        timer.cancel();  // Bağlantı kurulduysa denemeyi durdur
      } else {
        await connectAndFetchTemperature(device);  // Yeniden bağlantı dene
      }
    });
  }

  String sicaklik(Device device) {
    if (device.isConnected == 1) {
      return 'Sıcaklık: ${device.temperature.toStringAsFixed(2)} °C';
    } else if (device.isConnected == 2) {
      return 'Sıcaklık: Bağlantı Yeniden Deneniyor...';
    } else {
      return 'Sıcaklık: 0.00 °C';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sensörlerim'),
        backgroundColor: primaryColor,
        centerTitle: true,
      ),
      backgroundColor: backgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView.builder(
          itemCount: addedDevices.length,
          itemBuilder: (context, index) {
            final device = addedDevices[index];
            return _buildDeviceCard(device);
          },
        ),
      ),
    );
  }

  Widget _buildDeviceCard(Device device) {
    return Card(
      color: cardBackgroundColor,
      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: () async {
          // Cihaz profili ekranına yönlendir
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DeviceProfilePage(device: device),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    backgroundColor: device.isConnected == 1
                        ? Colors.green
                        : Colors.redAccent,
                    radius: 25,
                    child: Icon(
                      Icons.bluetooth,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Bağlantı Durumu: ' +
                              (device.isConnected == 1 ? 'Bağlı' : 'Bağlı Değil'),
                          style: TextStyle(
                            color: device.isConnected == 1
                                ? Colors.green
                                : Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () {
                      // Cihazı silme işlemi
                      _removeDevice(device);
                    },
                  ),
                ],
              ),
              Divider(color: Colors.grey.shade300),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Sıcaklık: ${device.temperature.toStringAsFixed(2)} °C',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: accentColor,
                  ),
                ),
              ),
              // İleride başka bilgiler eklemek isterseniz buraya ekleyebilirsiniz.
            ],
          ),
        ),
      ),
    );
  }
}

class TemperatureManager {
  static final TemperatureManager _instance = TemperatureManager._internal();
  double _temperature = 0.0;
  List<ChartData> _temperatureHistory = []; // Sıcaklık geçmişini ChartData tipinde tutacak liste
  bool _isOpen = false;

  factory TemperatureManager() {
    return _instance;
  }

  bool get isOpen => _isOpen; // Getter for isOpen

  set isOpen(bool value) {
    _isOpen = value;
  }

  TemperatureManager._internal();

  double get temperature => _temperature;

  final StreamController<double> _temperatureStreamController =
  StreamController<double>.broadcast();

  Stream<double> get temperatureStream => _temperatureStreamController.stream;

  // Yeni sıcaklık güncelleme
  void updateTemperature(double newTemperature) {
    _temperature = newTemperature;
    if (isOpen == false) {
      _temperatureHistory.add(ChartData(DateTime.now(), newTemperature));
    }
  }

  // ChartData tipiyle sıcaklık geçmişini döndür
  List<ChartData> getTemperatureHistory() {
    return _temperatureHistory;
  }

  // Güncel sıcaklık değerini döndür
  double getTemperature() {
    return _temperature;
  }
}
