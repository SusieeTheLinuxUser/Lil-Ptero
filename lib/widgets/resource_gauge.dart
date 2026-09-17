import 'package:flutter/material.dart';

class ResourceGauge extends StatelessWidget {
  final String label;
  final double value; // 0..1
  final String valueLabel;

  const ResourceGauge({super.key, required this.label, required this.value, required this.valueLabel});

  @override
  Widget build(BuildContext context) {
    final clamped = value.isFinite ? value.clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(label), Text(valueLabel)],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: clamped, minHeight: 8),
          ),
        ],
      ),
    );
  }
}
