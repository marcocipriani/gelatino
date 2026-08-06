import 'package:flutter/material.dart';

class Flavor {
  final String id;
  final String name;
  final String? colorHex;

  Flavor({
    required this.id,
    required this.name,
    this.colorHex,
  });

  /// Parsed pill color from [colorHex] (#RRGGBB), or null if unset/invalid.
  Color? get color {
    final h = colorHex;
    if (h == null || h.isEmpty) return null;
    var s = h.replaceFirst('#', '').trim();
    if (s.length == 6) s = 'FF$s';
    final v = int.tryParse(s, radix: 16);
    return v == null ? null : Color(v);
  }

  factory Flavor.fromMap(Map<String, dynamic> data, String id) {
    return Flavor(
      id: id,
      name: data['name'] ?? '',
      colorHex: data['color_hex'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'color_hex': colorHex,
    };
  }
}
