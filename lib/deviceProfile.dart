import 'dart:async';
import 'package:bluetooth_projesi/provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'device.dart';
import 'databaseHelper.dart';
import 'package:intl/intl.dart';
import 'sensors.dart';

class DeviceProfilePage extends StatefulWidget {
  final Device device;

  DeviceProfilePage({required this.device});

  @override
  _DeviceProfilePageState createState() => _DeviceProfilePageState();
}

class _DeviceProfilePageState extends State<DeviceProfilePage> {
  late String deviceName = " ";
  late Device currentDevice;
  List<ChartData> temperatureData = [];
  DateTime initialTime = DateTime.now();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TemperatureManager _temperatureManager = TemperatureManager(); // TemperatureManager örneği

  @override
  void initState() {
    super.initState();
    currentDevice = widget.device;
    _loadDeviceName();

    // TemperatureManager isOpen değerini true olarak ayarla
    _temperatureManager.isOpen = true;

    // Initialize temperature data with the current temperature
    temperatureData.add(ChartData(DateTime.now(), currentDevice.temperature));
    // Timer for periodic updates
  }

  Future<void> _loadDeviceName() async {
    deviceName =
        await _dbHelper.getDeviceName(widget.device.uuid) ?? widget.device.name;
    setState(() {});
  }

  Future<void> _saveDeviceName(String newName) async {
    await _dbHelper.insertDeviceName(widget.device.uuid, newName);
  }

  void updateDeviceTemperature(double newTemperature) {
    setState(() {
      currentDevice.temperature = newTemperature;

      // Calculate the next time point based on the previous data point
      DateTime nextTime;
      if (temperatureData.isNotEmpty) {
        nextTime = temperatureData.last.time
            .add(Duration(seconds: 6)); // Increment by 6 seconds
      } else {
        nextTime = DateTime.now();
      }

      temperatureData.add(ChartData(nextTime, newTemperature));

      if (temperatureData.length > 120) {
        temperatureData.removeAt(0);
      }
    });
  }

  void _editDeviceName() {
    showDialog(
      context: context,
      builder: (context) {
        String newName = deviceName;
        return AlertDialog(
          title: Text('Cihaz Adını Düzenle'),
          content: TextField(
            onChanged: (value) {
              newName = value;
            },
            decoration: InputDecoration(
              hintText: "Yeni cihaz adı",
              filled: true,
              fillColor: Colors.grey[100],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("İptal"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () {
                _saveDeviceName(newName);
                Navigator.pop(context);
              },
              child: Text("Kaydet"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final temperatureProvider = Provider.of<TemperatureProvider>(context);

    return Scaffold(
      backgroundColor: Colors.teal[50],
      appBar: AppBar(
        title: Text(deviceName),
        backgroundColor: Colors.teal[400],
        elevation: 4.0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    deviceName,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[700]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.teal),
                  onPressed: _editDeviceName,
                ),
              ],
            ),
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.15),
                    spreadRadius: 3,
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.thermostat_rounded, color: Colors.teal, size: 28),
                  SizedBox(width: 10),
                  Text(
                    'Sıcaklık: ${temperatureProvider.currentTemperature} °C',
                    style: TextStyle(fontSize: 20, color: Colors.teal[700]),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: SfCartesianChart(
                zoomPanBehavior: ZoomPanBehavior(
                  enablePanning: true,
                  enablePinching: true,
                  zoomMode: ZoomMode.x,
                ),
                plotAreaBackgroundColor: Colors.white,  // Grafik arka planını beyaz yapar
                plotAreaBorderWidth: 0,
                primaryXAxis: DateTimeAxis(
                  minimum: temperatureProvider.temperatureData.isNotEmpty
                      ? temperatureProvider.temperatureData.first.time
                      : DateTime.now(),
                  intervalType: DateTimeIntervalType.minutes,
                  dateFormat: DateFormat.Hm(),
                  autoScrollingDelta: 30,
                  autoScrollingMode: AutoScrollingMode.end,
                  majorGridLines: MajorGridLines(width: 0),
                ),
                primaryYAxis: NumericAxis(
                  minimum: 18,
                  maximum: 35,
                  interval: 1,
                  axisLine: AxisLine(width: 0),
                  majorTickLines: MajorTickLines(size: 0),
                  labelStyle: TextStyle(
                      color: Colors.teal[600], fontWeight: FontWeight.w600),
                ),
                series: <LineSeries<ChartData, DateTime>>[
                  LineSeries<ChartData, DateTime>(
                    dataSource: temperatureProvider.temperatureData,
                    xValueMapper: (ChartData data, _) => data.time,
                    yValueMapper: (ChartData data, _) => data.temperature,
                    color: Colors.redAccent,
                    width: 2,
                    markerSettings: MarkerSettings(
                      isVisible: true,
                      shape: DataMarkerType.circle,
                      borderColor: Colors.white,
                      borderWidth: 1,
                      color: Colors.teal,  // Veri noktalarını teal rengine ayarladık
                      width: 6,
                      height: 6,
                    ),
                  ),
                ],
                tooltipBehavior: TooltipBehavior(
                  enable: true,
                  header: '',
                  canShowMarker: true,
                  format: 'point.y °C',
                  textStyle: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChartData {
  final DateTime time;
  final double temperature;

  ChartData(this.time, this.temperature);
}
