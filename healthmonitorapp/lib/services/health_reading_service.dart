import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitality/models/health_reading.dart';

class HealthReadingService {
  static const String _readingsKey = 'health_readings';

  Future<List<HealthReading>> getReadings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readingsJson = prefs.getString(_readingsKey);

      if (readingsJson == null) {
        final sampleReadings = _createSampleReadings();
        await _saveReadings(sampleReadings);
        return sampleReadings;
      }

      final List<dynamic> decoded = jsonDecode(readingsJson);
      final readings = decoded
          .map((json) {
            try {
              return HealthReading.fromJson(json);
            } catch (e) {
              debugPrint('Error parsing reading: $e');
              return null;
            }
          })
          .whereType<HealthReading>()
          .toList();

      if (readings.isEmpty && decoded.isNotEmpty) {
        final sampleReadings = _createSampleReadings();
        await _saveReadings(sampleReadings);
        return sampleReadings;
      }

      return readings;
    } catch (e) {
      debugPrint('Error getting readings: $e');
      final sampleReadings = _createSampleReadings();
      await _saveReadings(sampleReadings);
      return sampleReadings;
    }
  }

  Future<void> addReading(HealthReading reading) async {
    try {
      final readings = await getReadings();
      readings.add(reading);
      await _saveReadings(readings);
    } catch (e) {
      debugPrint('Error adding reading: $e');
    }
  }

  Future<void> updateReading(HealthReading reading) async {
    try {
      final readings = await getReadings();
      final index = readings.indexWhere((r) => r.id == reading.id);
      if (index != -1) {
        readings[index] = reading.copyWith(updatedAt: DateTime.now());
        await _saveReadings(readings);
      }
    } catch (e) {
      debugPrint('Error updating reading: $e');
    }
  }

  Future<void> deleteReading(String id) async {
    try {
      final readings = await getReadings();
      readings.removeWhere((r) => r.id == id);
      await _saveReadings(readings);
    } catch (e) {
      debugPrint('Error deleting reading: $e');
    }
  }

  Future<List<HealthReading>> getReadingsByType(ReadingType type) async {
    final readings = await getReadings();
    return readings.where((r) => r.type == type).toList();
  }

  Future<List<HealthReading>> getReadingsByDateRange(
      DateTime start, DateTime end) async {
    final readings = await getReadings();
    return readings
        .where((r) => r.timestamp.isAfter(start) && r.timestamp.isBefore(end))
        .toList();
  }

  Future<void> _saveReadings(List<HealthReading> readings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readingsJson = readings.map((r) => r.toJson()).toList();
      await prefs.setString(_readingsKey, jsonEncode(readingsJson));
    } catch (e) {
      debugPrint('Error saving readings: $e');
    }
  }

  List<HealthReading> _createSampleReadings() {
    final now = DateTime.now();
    const userId = 'user_001';

    return [
      HealthReading(
        id: 'reading_001',
        userId: userId,
        type: ReadingType.bloodSugar,
        value: 95,
        unit: 'mg/dL',
        notes: 'Fasting reading',
        timestamp: now.subtract(const Duration(hours: 2)),
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ),
      HealthReading(
        id: 'reading_002',
        userId: userId,
        type: ReadingType.bloodPressureSystolic,
        value: 118,
        unit: 'mmHg',
        notes: 'Morning reading',
        timestamp: now.subtract(const Duration(hours: 3)),
        createdAt: now.subtract(const Duration(hours: 3)),
        updatedAt: now.subtract(const Duration(hours: 3)),
      ),
      HealthReading(
        id: 'reading_003',
        userId: userId,
        type: ReadingType.bloodPressureDiastolic,
        value: 78,
        unit: 'mmHg',
        notes: 'Morning reading',
        timestamp: now.subtract(const Duration(hours: 3)),
        createdAt: now.subtract(const Duration(hours: 3)),
        updatedAt: now.subtract(const Duration(hours: 3)),
      ),
      HealthReading(
        id: 'reading_004',
        userId: userId,
        type: ReadingType.heartRate,
        value: 72,
        unit: 'bpm',
        timestamp: now.subtract(const Duration(hours: 4)),
        createdAt: now.subtract(const Duration(hours: 4)),
        updatedAt: now.subtract(const Duration(hours: 4)),
      ),
      HealthReading(
        id: 'reading_005',
        userId: userId,
        type: ReadingType.weight,
        value: 72.5,
        unit: 'kg',
        timestamp: now.subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      HealthReading(
        id: 'reading_006',
        userId: userId,
        type: ReadingType.bloodSugar,
        value: 110,
        unit: 'mg/dL',
        notes: 'After lunch',
        timestamp: now.subtract(const Duration(days: 1, hours: 5)),
        createdAt: now.subtract(const Duration(days: 1, hours: 5)),
        updatedAt: now.subtract(const Duration(days: 1, hours: 5)),
      ),
      HealthReading(
        id: 'reading_007',
        userId: userId,
        type: ReadingType.oxygenSaturation,
        value: 98,
        unit: '%',
        timestamp: now.subtract(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      HealthReading(
        id: 'reading_008',
        userId: userId,
        type: ReadingType.temperature,
        value: 36.8,
        unit: '°C',
        timestamp: now.subtract(const Duration(days: 2)),
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      HealthReading(
        id: 'reading_009',
        userId: userId,
        type: ReadingType.bloodSugar,
        value: 92,
        unit: 'mg/dL',
        notes: 'Fasting',
        timestamp: now.subtract(const Duration(days: 2, hours: 8)),
        createdAt: now.subtract(const Duration(days: 2, hours: 8)),
        updatedAt: now.subtract(const Duration(days: 2, hours: 8)),
      ),
      HealthReading(
        id: 'reading_010',
        userId: userId,
        type: ReadingType.heartRate,
        value: 68,
        unit: 'bpm',
        timestamp: now.subtract(const Duration(days: 2)),
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      HealthReading(
        id: 'reading_011',
        userId: userId,
        type: ReadingType.bloodPressureSystolic,
        value: 120,
        unit: 'mmHg',
        timestamp: now.subtract(const Duration(days: 3)),
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 3)),
      ),
      HealthReading(
        id: 'reading_012',
        userId: userId,
        type: ReadingType.bloodPressureDiastolic,
        value: 80,
        unit: 'mmHg',
        timestamp: now.subtract(const Duration(days: 3)),
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 3)),
      ),
      HealthReading(
        id: 'reading_013',
        userId: userId,
        type: ReadingType.weight,
        value: 72.8,
        unit: 'kg',
        timestamp: now.subtract(const Duration(days: 4)),
        createdAt: now.subtract(const Duration(days: 4)),
        updatedAt: now.subtract(const Duration(days: 4)),
      ),
      HealthReading(
        id: 'reading_014',
        userId: userId,
        type: ReadingType.bloodSugar,
        value: 105,
        unit: 'mg/dL',
        notes: 'Post-meal',
        timestamp: now.subtract(const Duration(days: 4, hours: 6)),
        createdAt: now.subtract(const Duration(days: 4, hours: 6)),
        updatedAt: now.subtract(const Duration(days: 4, hours: 6)),
      ),
      HealthReading(
        id: 'reading_015',
        userId: userId,
        type: ReadingType.heartRate,
        value: 75,
        unit: 'bpm',
        timestamp: now.subtract(const Duration(days: 5)),
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now.subtract(const Duration(days: 5)),
      ),
      HealthReading(
        id: 'reading_016',
        userId: userId,
        type: ReadingType.oxygenSaturation,
        value: 97,
        unit: '%',
        timestamp: now.subtract(const Duration(days: 5)),
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now.subtract(const Duration(days: 5)),
      ),
      HealthReading(
        id: 'reading_017',
        userId: userId,
        type: ReadingType.bloodPressureSystolic,
        value: 115,
        unit: 'mmHg',
        timestamp: now.subtract(const Duration(days: 6)),
        createdAt: now.subtract(const Duration(days: 6)),
        updatedAt: now.subtract(const Duration(days: 6)),
      ),
      HealthReading(
        id: 'reading_018',
        userId: userId,
        type: ReadingType.bloodPressureDiastolic,
        value: 75,
        unit: 'mmHg',
        timestamp: now.subtract(const Duration(days: 6)),
        createdAt: now.subtract(const Duration(days: 6)),
        updatedAt: now.subtract(const Duration(days: 6)),
      ),
      HealthReading(
        id: 'reading_019',
        userId: userId,
        type: ReadingType.bloodSugar,
        value: 98,
        unit: 'mg/dL',
        notes: 'Fasting',
        timestamp: now.subtract(const Duration(days: 7)),
        createdAt: now.subtract(const Duration(days: 7)),
        updatedAt: now.subtract(const Duration(days: 7)),
      ),
      HealthReading(
        id: 'reading_020',
        userId: userId,
        type: ReadingType.weight,
        value: 73.0,
        unit: 'kg',
        timestamp: now.subtract(const Duration(days: 7)),
        createdAt: now.subtract(const Duration(days: 7)),
        updatedAt: now.subtract(const Duration(days: 7)),
      ),
      HealthReading(
        id: 'reading_021',
        userId: userId,
        type: ReadingType.heartRate,
        value: 70,
        unit: 'bpm',
        timestamp: now.subtract(const Duration(days: 8)),
        createdAt: now.subtract(const Duration(days: 8)),
        updatedAt: now.subtract(const Duration(days: 8)),
      ),
      HealthReading(
        id: 'reading_022',
        userId: userId,
        type: ReadingType.temperature,
        value: 36.7,
        unit: '°C',
        timestamp: now.subtract(const Duration(days: 9)),
        createdAt: now.subtract(const Duration(days: 9)),
        updatedAt: now.subtract(const Duration(days: 9)),
      ),
      HealthReading(
        id: 'reading_023',
        userId: userId,
        type: ReadingType.bloodSugar,
        value: 88,
        unit: 'mg/dL',
        notes: 'Before breakfast',
        timestamp: now.subtract(const Duration(days: 10)),
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 10)),
      ),
      HealthReading(
        id: 'reading_024',
        userId: userId,
        type: ReadingType.oxygenSaturation,
        value: 99,
        unit: '%',
        timestamp: now.subtract(const Duration(days: 10)),
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 10)),
      ),
      HealthReading(
        id: 'reading_025',
        userId: userId,
        type: ReadingType.bloodPressureSystolic,
        value: 122,
        unit: 'mmHg',
        timestamp: now.subtract(const Duration(days: 12)),
        createdAt: now.subtract(const Duration(days: 12)),
        updatedAt: now.subtract(const Duration(days: 12)),
      ),
      HealthReading(
        id: 'reading_026',
        userId: userId,
        type: ReadingType.bloodPressureDiastolic,
        value: 82,
        unit: 'mmHg',
        timestamp: now.subtract(const Duration(days: 12)),
        createdAt: now.subtract(const Duration(days: 12)),
        updatedAt: now.subtract(const Duration(days: 12)),
      ),
    ];
  }
}
