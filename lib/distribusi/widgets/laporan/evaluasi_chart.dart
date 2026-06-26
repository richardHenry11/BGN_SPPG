import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:bgn/distribusi/theme/colors.dart';

class EvaluasiChart extends StatelessWidget {
  const EvaluasiChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _WeeklyChart(),
        const SizedBox(height: 12),
        _SuccessRate(),
        const SizedBox(height: 12),
        _FeedbackSection(),
      ],
    );
  }
}

// ── Weekly Bar Chart ──────────────────────────────────────

class _WeeklyChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const data = [
      _BarData(hari: 'Sen', total: 118, height: 80, isToday: false),
      _BarData(hari: 'Sel', total: 122, height: 88, isToday: false),
      _BarData(hari: 'Rab', total: 115, height: 76, isToday: false),
      _BarData(hari: 'Kam', total: 130, height: 96, isToday: false),
      _BarData(hari: 'Jum', total: 128, height: 92, isToday: false),
      _BarData(hari: 'Sab', total: 110, height: 68, isToday: false),
      _BarData(hari: 'Min', total: 125, height: 100, isToday: true),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BGNColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pengiriman 7 hari terakhir',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: BGNColors.textPrimary),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.map((d) {
                final maxHeight = 120.0 - 24;
                final barHeight = (d.height / 100) * maxHeight;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${d.total}',
                            style: const TextStyle(fontSize: 9, color: BGNColors.textHint, height: 1)),
                        const SizedBox(height: 4),
                        Container(
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: d.isToday ? BGNColors.primary : BGNColors.primaryLight,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          d.hari,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: d.isToday ? FontWeight.w600 : FontWeight.w400,
                            color: d.isToday ? BGNColors.primary : BGNColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarData {
  final String hari;
  final int total;
  final double height;
  final bool isToday;

  const _BarData({
    required this.hari,
    required this.total,
    required this.height,
    required this.isToday,
  });
}

// ── Success Rate ──────────────────────────────────────────

class _SuccessRate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const items = [
      _RateItem(label: 'Tepat sasaran', persen: 98.5, icon: TablerIcons.target, color: BGNColors.primary),
      _RateItem(label: 'Tepat waktu', persen: 94.4, icon: TablerIcons.clock, color: BGNColors.success),
      _RateItem(label: 'Tepat jumlah', persen: 96.8, icon: TablerIcons.box, color: BGNColors.warning),
      _RateItem(label: 'Tanpa komplain', persen: 90.4, icon: TablerIcons.message_circle, color: BGNColors.danger),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BGNColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tingkat keberhasilan',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: BGNColors.textPrimary),
          ),
          const SizedBox(height: 16),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(item.icon, size: 14, color: item.color),
                            const SizedBox(width: 6),
                            Text(item.label,
                                style: const TextStyle(fontSize: 11, color: BGNColors.textSecondary)),
                          ],
                        ),
                        Text('${item.persen}%',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: item.color)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: item.persen / 100,
                        backgroundColor: BGNColors.border,
                        valueColor: AlwaysStoppedAnimation(item.color),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _RateItem {
  final String label;
  final double persen;
  final IconData icon;
  final Color color;

  const _RateItem({required this.label, required this.persen, required this.icon, required this.color});
}

// ── Feedback Section ──────────────────────────────────────

class _FeedbackSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const items = [
      _FeedbackData(label: 'Puas', count: 108, icon: TablerIcons.mood_happy, color: BGNColors.primary, bgColor: BGNColors.primaryLight),
      _FeedbackData(label: 'Cukup', count: 14, icon: TablerIcons.mood_smile, color: BGNColors.warning, bgColor: BGNColors.warningLight),
      _FeedbackData(label: 'Tidak\npuas', count: 3, icon: TablerIcons.mood_sad, color: BGNColors.danger, bgColor: BGNColors.dangerLight),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BGNColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Feedback penerima',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: BGNColors.textPrimary),
          ),
          const SizedBox(height: 16),
          Row(
            children: items.map((item) => Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: item.bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(item.icon, size: 24, color: item.color),
                    const SizedBox(height: 6),
                    Text('${item.count}',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: item.color)),
                    const SizedBox(height: 2),
                    Text(item.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, color: item.color, height: 1.2)),
                  ],
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _FeedbackData {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _FeedbackData({required this.label, required this.count, required this.icon, required this.color, required this.bgColor});
}
