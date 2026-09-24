import 'package:flutter/material.dart';

class CmykChannelControl extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;
  final VoidCallback? onReset;

  const CmykChannelControl({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = value.clamp(-100.0, 100.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white24,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              normalized.toStringAsFixed(0),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              '%',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
            if (onReset != null)
              IconButton(
                tooltip: 'Reset $label',
                visualDensity: VisualDensity.compact,
                onPressed: onReset,
                icon: const Icon(
                  Icons.refresh,
                  size: 18,
                ),
              ),
          ],
        ),
        Slider(
          value: normalized,
          min: -100,
          max: 100,
          divisions: 200,
          label: normalized.toStringAsFixed(0),
          onChanged: onChanged,
        ),
        Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              '-100',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
            Text(
              '0',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
            Text(
              '+100',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
