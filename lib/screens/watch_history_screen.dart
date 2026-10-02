import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/user_data_service.dart';
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

  double get _total => _watchMinutes.reduce((a, b) => a + b);

  String _fmt(double m) {
    final h = (m / 60).floor();
    final mn = (m % 60).round();
    return h > 0 ? '${h}h ${mn}m' : '${mn}m';
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    UserDataService.addListener(_onUserDataChanged);
  }

  @override
  void dispose() {
    UserDataService.removeListener(_onUserDataChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _onUserDataChanged() {
    if (mounted) setState(() {});
  }

  void _clearAllHistory() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Watch History?'),
        content: const Text(
            'This will clear your watch history from all devices.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await UserDataService.clearHistory();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Watch history cleared'),
                    backgroundColor: const Color(0xFF1A1A1A),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            child: const Text('Clear All',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F0F0F) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F3F3);
    final textColor = isDark ? Colors.white : Colors.black87;
    final history = UserDataService.watchHistory;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Watch History',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (history.isNotEmpty)
            TextButton(
              onPressed: _clearAllHistory,
              child: const Text(
                'Clear All',
                style: TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 72, color: Colors.grey[600]),
                      const SizedBox(height: 16),
                      Text(
                        'No watch history yet',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Videos you watch will appear here',
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 120),
                  children: [
                    _buildGraph(cardBg, textColor, isDark),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'RECENTLY WATCHED',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            '${history.length} videos',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...history.asMap().entries.map((entry) {
                      final i = entry.key;
                      final v = entry.value;
                      return VideoCard(
                        video: v,
                        animationIndex: i > 6 ? 0 : i,
                      );
                    }),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildGraph(Color cardBg, Color textColor, bool isDark) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Watch Time',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Last 7 days',
                      style: TextStyle(color: Colors.red[400], fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Total: ${_fmt(_total)}',
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            const SizedBox(height: 20),
            SizedBox(
              height: 140,
              child: BarChart(BarChartData(
                maxY: _watchMinutes.reduce((a, b) => a > b ? a : b) * 1.3,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchCallback: (_, res) => setState(() =>
                      _touchedIndex = res?.spot?.touchedBarGroupIndex ?? -1),
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => isDark
                        ? const Color(0xFF2A2A2A)
                        : const Color(0xFF424242),
                    getTooltipItem: (g, _, __, ___) => BarTooltipItem(
                      _fmt(_watchMinutes[g.x]),
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (v, _) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _days[v.toInt()],
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  _watchMinutes.length,
                  (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: _watchMinutes[i] * _ctrl.value,
                        color: i == _touchedIndex
                            ? Colors.redAccent
                            : Colors.red.withValues(alpha: 0.7),
                        width: 18,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                      )
                    ],
                  ),
                ),
              )),
            ),
          ],
        ),
      ),
    );
  }
}
