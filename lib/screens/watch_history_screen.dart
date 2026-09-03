import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/video.dart';
import '../widgets/video_card.dart';

class WatchHistoryScreen extends StatefulWidget {
  const WatchHistoryScreen({super.key});

  @override
  State<WatchHistoryScreen> createState() => _WatchHistoryScreenState();
}

class _WatchHistoryScreenState extends State<WatchHistoryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  final List<double> _watchMinutes = [45, 120, 30, 90, 200, 75, 150];
  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  int _touchedIndex = -1;

  final Map<String, List<Map<String, dynamic>>> _history = {
    'Today': [
      {'type': 'video', 'data': 0},
      {'type': 'short', 'data': 0},
      {'type': 'video', 'data': 1},
    ],
    'Yesterday': [
      {'type': 'video', 'data': 2},
      {'type': 'short', 'data': 1},
    ],
    '2 days ago': [
      {'type': 'video', 'data': 3},
      {'type': 'video', 'data': 4},
    ],
  };

  double get _total => _watchMinutes.reduce((a, b) => a + b);

  String _fmt(double m) {
    final h = (m / 60).floor();
    final mn = (m % 60).round();
    return h > 0 ? '${h}h ${mn}m' : '${mn}m';
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Watch History',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [TextButton(onPressed: () {}, child: const Text('Clear All', style: TextStyle(color: Colors.grey, fontSize: 13)))],
      ),
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              _buildGraph(),
              ..._history.entries.expand((entry) {
                final shorts = entry.value.where((i) => i['type'] == 'short').toList();
                final videos = entry.value.where((i) => i['type'] == 'video').toList();
                return [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text(entry.key, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  ),
                  if (shorts.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 8),
                      child: Row(children: [
                        const Icon(Icons.bolt, color: Colors.red, size: 14),
                        const SizedBox(width: 4),
                        Text('Shorts', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                      ]),
                    ),
                    SizedBox(
                      height: 160,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: shorts.length,
                        itemBuilder: (ctx, i) {
                          final v = Video.getShortsVideos()[shorts[i]['data'] as int];
                          return _ShortCard(video: v);
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  ...videos.map((item) {
                    final v = Video.sampleVideos[item['data'] as int];
                    return VideoCard(video: v, animationIndex: 0);
                  }),
                ];
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGraph() {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Watch Time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                child: Text('Last 7 days', style: TextStyle(color: Colors.red[300], fontSize: 11)),
              ),
            ]),
            const SizedBox(height: 4),
            Text('Total: ${_fmt(_total)}', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            const SizedBox(height: 20),
            SizedBox(
              height: 150,
              child: BarChart(BarChartData(
                maxY: _watchMinutes.reduce((a, b) => a > b ? a : b) * 1.3,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchCallback: (_, res) => setState(() => _touchedIndex = res?.spot?.touchedBarGroupIndex ?? -1),
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF2A2A2A),
                    getTooltipItem: (g, _, __, ___) => BarTooltipItem(_fmt(_watchMinutes[g.x]), const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1)),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24, getTitlesWidget: (v, _) => Padding(padding: const EdgeInsets.only(top: 6), child: Text(_days[v.toInt()], style: TextStyle(color: Colors.grey[500], fontSize: 10))))),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(_watchMinutes.length, (i) => BarChartGroupData(
                  x: i,
                  barRods: [BarChartRodData(
                    toY: _watchMinutes[i] * _ctrl.value,
                    color: i == _touchedIndex ? Colors.redAccent : Colors.red.withOpacity(0.7),
                    width: 18,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  )],
                )),
              )),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortCard extends StatelessWidget {
  final Video video;
  const _ShortCard({required this.video});

  @override
  Widget build(BuildContext context) => Container(
    width: 95,
    margin: const EdgeInsets.only(right: 10),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: const Color(0xFF1A1A1A)),
    clipBehavior: Clip.antiAlias,
    child: Stack(fit: StackFit.expand, children: [
      Image.network(video.thumbnailUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey[900])),
      Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Colors.black.withOpacity(0.7)], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
      const Positioned(top: 6, right: 6, child: Icon(Icons.bolt, color: Colors.white, size: 14)),
      Positioned(bottom: 6, left: 6, right: 6, child: Text(video.title, maxLines: 2, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500))),
    ]),
  );
}
