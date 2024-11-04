import 'dart:async';
import 'package:bluetooth_projesi/sensors.dart';
import 'package:flutter/material.dart';

import 'deviceProfile.dart';

class TemperatureProvider with ChangeNotifier {
  List<ChartData> temperatureData = [];
  double currentTemperature = 0.0; // Başlangıç sıcaklığı


  TemperatureProvider() {
    temperatureData = TemperatureManager().getTemperatureHistory();
    // Veriyi düzenli olarak güncelleyen bir timer başlatıyoruz.
    Timer.periodic(Duration(seconds: 6), (timer) {
      _updateTemperature();
    });
  }

  void _updateTemperature() {
    currentTemperature = TemperatureManager().getTemperature(); // Örneğin sensörden veri alıyorsunuz
    DateTime nextTime = temperatureData.isNotEmpty
        ? temperatureData.last.time.add(Duration(seconds: 6))
        : DateTime.now();
    temperatureData.add(ChartData(nextTime, currentTemperature));

    if (temperatureData.length > 120) {
      temperatureData.removeAt(0); // Eski verileri çıkar
    }

    notifyListeners();
  }
}
