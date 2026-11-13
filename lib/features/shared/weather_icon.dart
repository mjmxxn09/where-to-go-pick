import 'package:flutter/material.dart';

import '../../core/life/life_repository.dart';

class WeatherIcon extends StatelessWidget {
  const WeatherIcon({super.key, required this.sky, this.size = 20});

  final Sky sky;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (sky) {
      Sky.sunny => (Icons.wb_sunny_outlined, const Color(0xFFB07A00), '맑음'),
      Sky.cloudy => (Icons.cloud_outlined, const Color(0xFF5E6072), '흐림'),
      Sky.rainy => (Icons.umbrella_outlined, const Color(0xFF2A63D4), '비'),
      Sky.snowy => (Icons.ac_unit, const Color(0xFF4FB8CB), '눈'),
    };
    return Icon(icon, size: size, color: color, semanticLabel: label);
  }
}

String skyLabel(Sky sky) => switch (sky) {
      Sky.sunny => '맑음',
      Sky.cloudy => '흐림',
      Sky.rainy => '비',
      Sky.snowy => '눈',
    };
