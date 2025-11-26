enum ReadingType {
  bloodSugar,
  bloodPressureSystolic,
  bloodPressureDiastolic,
  heartRate,
  weight,
  temperature,
  oxygenSaturation,
}

extension ReadingTypeExtension on ReadingType {
  String get displayName {
    switch (this) {
      case ReadingType.bloodSugar:
        return 'Blood Sugar';
      case ReadingType.bloodPressureSystolic:
        return 'Blood Pressure (Systolic)';
      case ReadingType.bloodPressureDiastolic:
        return 'Blood Pressure (Diastolic)';
      case ReadingType.heartRate:
        return 'Heart Rate';
      case ReadingType.weight:
        return 'Weight';
      case ReadingType.temperature:
        return 'Temperature';
      case ReadingType.oxygenSaturation:
        return 'Oxygen Saturation';
    }
  }

  String get unit {
    switch (this) {
      case ReadingType.bloodSugar:
        return 'mg/dL';
      case ReadingType.bloodPressureSystolic:
      case ReadingType.bloodPressureDiastolic:
        return 'mmHg';
      case ReadingType.heartRate:
        return 'bpm';
      case ReadingType.weight:
        return 'kg';
      case ReadingType.temperature:
        return '°C';
      case ReadingType.oxygenSaturation:
        return '%';
    }
  }

  String get icon {
    switch (this) {
      case ReadingType.bloodSugar:
        return '🩸';
      case ReadingType.bloodPressureSystolic:
      case ReadingType.bloodPressureDiastolic:
        return '💉';
      case ReadingType.heartRate:
        return '❤️';
      case ReadingType.weight:
        return '⚖️';
      case ReadingType.temperature:
        return '🌡️';
      case ReadingType.oxygenSaturation:
        return '🫁';
    }
  }
}

class HealthReading {
  final String id;
  final String userId;
  final ReadingType type;
  final double value;
  final String unit;
  final String? notes;
  final DateTime timestamp;
  final DateTime createdAt;
  final DateTime updatedAt;

  HealthReading({
    required this.id,
    required this.userId,
    required this.type,
    required this.value,
    required this.unit,
    this.notes,
    required this.timestamp,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'type': type.name,
        'value': value,
        'unit': unit,
        'notes': notes,
        'timestamp': timestamp.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory HealthReading.fromJson(Map<String, dynamic> json) => HealthReading(
        id: json['id'] as String,
        userId: json['userId'] as String,
        type: ReadingType.values.firstWhere((e) => e.name == json['type']),
        value: (json['value'] as num).toDouble(),
        unit: json['unit'] as String,
        notes: json['notes'] as String?,
        timestamp: DateTime.parse(json['timestamp'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  HealthReading copyWith({
    String? id,
    String? userId,
    ReadingType? type,
    double? value,
    String? unit,
    String? notes,
    DateTime? timestamp,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      HealthReading(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        type: type ?? this.type,
        value: value ?? this.value,
        unit: unit ?? this.unit,
        notes: notes ?? this.notes,
        timestamp: timestamp ?? this.timestamp,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
