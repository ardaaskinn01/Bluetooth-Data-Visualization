import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class Device {
  final String uuid;
  String name;
  double temperature;
  List<double> temperatureHistory;
  int isConnected;
  final BluetoothDevice bluetoothDevice;
  double? lastReceivedTemperature;

  Device({
    required this.uuid,
    required this.name,
    required this.temperature,
    required this.temperatureHistory,
    required this.isConnected,
    required this.bluetoothDevice,
    this.lastReceivedTemperature,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    List<double> temperatureHistory = (json['temperatureHistory'] as String)
        .split(',')
        .map((temp) => double.tryParse(temp) ?? 0.0)
        .toList();

    return Device(
      uuid: json['uuid'],
      name: json['name'],
      temperature: json['temperature'],
      temperatureHistory: temperatureHistory,
      isConnected: json['isConnected'],
      bluetoothDevice: BluetoothDevice(remoteId: DeviceIdentifier(json['uuid'])),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'name': name,
      'temperature': temperature,
      'temperatureHistory': temperatureHistory.join(','),
      'isConnected': isConnected,
      'bluetoothDevice': bluetoothDevice.id.toString(),
    };
  }

  // Add `toMap` method
  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'name': name,
      'temperature': temperature,
      'temperatureHistory': temperatureHistory,
      'isConnected': isConnected,
      'lastReceivedTemperature': lastReceivedTemperature,
    };
  }

  // Add `fromMap` method
  factory Device.fromMap(Map<String, dynamic> map) {
    return Device(
      uuid: map['uuid'],
      name: map['name'],
      temperature: map['temperature'],
      temperatureHistory: List<double>.from(map['temperatureHistory'] ?? []),
      isConnected: map['isConnected'],
      bluetoothDevice: BluetoothDevice(remoteId: DeviceIdentifier(map['uuid'])),
      lastReceivedTemperature: map['lastReceivedTemperature'],
    );
  }

  Device copyWith({
    String? uuid,
    String? name,
    double? temperature,
    List<double>? temperatureHistory,
    int? isConnected,
    BluetoothDevice? bluetoothDevice,
    double? lastReceivedTemperature,
  }) {
    return Device(
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      temperature: temperature ?? this.temperature,
      temperatureHistory: temperatureHistory ?? this.temperatureHistory,
      isConnected: isConnected ?? this.isConnected,
      bluetoothDevice: bluetoothDevice ?? this.bluetoothDevice,
      lastReceivedTemperature: lastReceivedTemperature ?? this.lastReceivedTemperature,
    );
  }

  Future<List<BluetoothService>> discoverServices() async {
    try {
      return await bluetoothDevice.discoverServices();
    } catch (e) {
      throw Exception("Servis keşfedilemedi: $e");
    }
  }
}
