import 'package:flutter/material.dart';

import 'models.dart';

class UsageBarData {
  final String label;
  final double pct; // 0..100
  final String reset;
  const UsageBarData(this.label, this.pct, this.reset);
}

String resetLabel(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final t = DateTime.tryParse(iso)?.toLocal();
  if (t == null) return '';
  final diff = t.difference(DateTime.now());
  if (diff.inSeconds <= 0) return 'Resets soon';
  if (diff.inHours < 24) {
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return h > 0 ? 'Resets in $h hr $m min' : 'Resets in $m min';
  }
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final hh = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final ampm = t.hour < 12 ? 'AM' : 'PM';
  final mm = t.minute.toString().padLeft(2, '0');
  return 'Resets ${days[t.weekday - 1]} $hh:$mm $ampm';
}

class _Style {
  final Color bg;
  final Gradient? gradient;
  final Color title;
  final Color subtitle;
  final Color track;
  final Color fill;
  final bool striped;
  final bool glow;
  final String? font;
  final double radius;
  final Border? border;
  const _Style({
    required this.bg,
    this.gradient,
    required this.title,
    required this.subtitle,
    required this.track,
    required this.fill,
    this.striped = false,
    this.glow = false,
    this.font,
    this.radius = 20,
    this.border,
  });
}

_Style _styleFor(WidgetTheme t) {
  switch (t) {
    case WidgetTheme.minimalist:
      return const _Style(
        bg: Color(0xFFF7F7F8),
        title: Color(0xFF111111),
        subtitle: Color(0xFF8A8A8E),
        track: Color(0xFFE6E6EA),
        fill: Color(0xFF3355FF),
        radius: 22,
      );
    case WidgetTheme.elegant:
      return const _Style(
        bg: Color(0xFFFBF7F0),
        title: Color(0xFF2E2A24),
        subtitle: Color(0xFF9A8B76),
        track: Color(0xFFEBE2D2),
        fill: Color(0xFFC9A24B),
        font: 'serif',
        radius: 20,
        border: Border.fromBorderSide(BorderSide(color: Color(0x33C9A24B))),
      );
    case WidgetTheme.futuristic:
      return const _Style(
        bg: Color(0xFF0A0E14),
        gradient: LinearGradient(
          colors: [Color(0xFF0A0E14), Color(0xFF0E1A24)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        title: Color(0xFF19E6C1),
        subtitle: Color(0xFF6FE9D6),
        track: Color(0xFF13303A),
        fill: Color(0xFF19E6C1),
        glow: true,
        font: 'monospace',
        radius: 14,
        border: Border.fromBorderSide(BorderSide(color: Color(0x5519E6C1))),
      );
    case WidgetTheme.neumorphic:
      return const _Style(
        bg: Color(0xFFE6E7EE),
        title: Color(0xFF3A3D4D),
        subtitle: Color(0xFF9498A6),
        track: Color(0xFFD2D4DE),
        fill: Color(0xFF6C74C4),
        radius: 26,
      );
    case WidgetTheme.retro:
      return const _Style(
        bg: Color(0xFF14142A),
        title: Color(0xFF00FF66),
        subtitle: Color(0xFFFFCC00),
        track: Color(0xFF2A2A4A),
        fill: Color(0xFF00FF66),
        font: 'monospace',
        radius: 4,
        border: Border.fromBorderSide(BorderSide(color: Color(0xFF00FF66), width: 2)),
      );
    case WidgetTheme.adaptive:
      return const _Style(
        bg: Color(0xFFEEF0FF),
        gradient: LinearGradient(
          colors: [Color(0xFFEEF0FF), Color(0xFFDCE0FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        title: Color(0xFF1B1B4B),
        subtitle: Color(0xFF5B5B8A),
        track: Color(0xFFCFD3F5),
        fill: Color(0xFF4B54E0),
        radius: 24,
      );
    case WidgetTheme.caution:
      return const _Style(
        bg: Color(0xFF0A0A0A),
        title: Color(0xFFFFD400),
        subtitle: Color(0xFFBFA500),
        track: Color(0xFF1F1F1F),
        fill: Color(0xFFFFD400),
        striped: true,
        font: 'monospace',
        radius: 8,
        border: Border.fromBorderSide(BorderSide(color: Color(0xFFFFD400), width: 2)),
      );
  }
}

// The widget rendered to an image by home_widget and shown on the home screen.
Widget buildWidgetCanvas({
  required WidgetTheme theme,
  required String title,
  String? subtitle,
  required List<UsageBarData> bars,
}) {
  final s = _styleFor(theme);
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Container(
      decoration: BoxDecoration(
        color: s.gradient == null ? s.bg : null,
        gradient: s.gradient,
        borderRadius: BorderRadius.circular(s.radius),
        border: s.border,
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: s.title,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              fontFamily: s.font,
              shadows: s.glow ? [Shadow(color: s.title.withOpacity(0.6), blurRadius: 8)] : null,
            ),
          ),
          if (subtitle != null && subtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: s.subtitle, fontSize: 11, fontFamily: s.font),
              ),
            ),
          const SizedBox(height: 10),
          if (bars.isEmpty)
            Text('Tap to sync', style: TextStyle(color: s.subtitle, fontSize: 12, fontFamily: s.font))
          else
            for (int i = 0; i < bars.length; i++)
              Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 10), child: _barRow(s, bars[i])),
        ],
      ),
    ),
  );
}

Widget _barRow(_Style s, UsageBarData b) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(b.label,
              style: TextStyle(
                  color: s.title, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: s.font)),
          Text('${b.pct.round()}%',
              style: TextStyle(
                  color: s.subtitle, fontSize: 12, fontWeight: FontWeight.w700, fontFamily: s.font)),
        ],
      ),
      const SizedBox(height: 4),
      SizedBox(
        width: double.infinity,
        height: s.striped ? 12 : 9,
        child: CustomPaint(painter: _BarPainter(s, (b.pct / 100).clamp(0.0, 1.0))),
      ),
      if (b.reset.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(b.reset, style: TextStyle(color: s.subtitle, fontSize: 9, fontFamily: s.font)),
        ),
    ],
  );
}

class _BarPainter extends CustomPainter {
  final _Style s;
  final double frac;
  _BarPainter(this.s, this.frac);

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(s.striped ? 2 : size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = s.track,
    );
    final w = (size.width * frac).clamp(0.0, size.width);
    if (w <= 0) return;
    final fillRect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, size.height), radius);
    canvas.save();
    canvas.clipRRect(fillRect);
    if (s.striped) {
      canvas.drawRect(Rect.fromLTWH(0, 0, w, size.height), Paint()..color = s.fill);
      final stripe = Paint()
        ..color = const Color(0xFF0A0A0A)
        ..strokeWidth = 5;
      for (double x = -size.height; x < w + size.height; x += 11) {
        canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), stripe);
      }
    } else {
      canvas.drawRect(Rect.fromLTWH(0, 0, w, size.height), Paint()..color = s.fill);
      if (s.glow) {
        canvas.drawRect(
          Rect.fromLTWH(0, 0, w, size.height),
          Paint()
            ..color = s.fill.withOpacity(0.4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BarPainter oldDelegate) => true;
}
