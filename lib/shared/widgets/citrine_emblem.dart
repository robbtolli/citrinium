import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Vector emblem of Citrine (`FR-15`): a faceted yellow-gold citrine crystal
/// with a stylized fountain pen in front of it.
class CitrineEmblem extends StatelessWidget {
  const CitrineEmblem({this.size = 64, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CitrineEmblemPainter(),
        isComplex: true,
      ),
    );
  }
}

class _CitrineEmblemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Rounded badge background (deep fountain-pen navy)
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: s, height: s),
      Radius.circular(s * 0.22),
    );
    canvas.drawRRect(
      bgRect,
      Paint()..color = const Color(0xFF18202C),
    );

    // Subtle warm radial glow behind the crystal
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFBBF24).withValues(alpha: 0.28),
          const Color(0xFFF59E0B).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: s * 0.44));
    canvas.drawCircle(Offset(cx, cy), s * 0.44, glowPaint);

    // Faceted Citrine Crystal (hexagonal prism with pointed crown & base)
    final top = Offset(cx, cy - s * 0.36);
    final upperLeft = Offset(cx - s * 0.23, cy - s * 0.16);
    final upperRight = Offset(cx + s * 0.23, cy - s * 0.16);
    final lowerLeft = Offset(cx - s * 0.21, cy + s * 0.18);
    final lowerRight = Offset(cx + s * 0.21, cy + s * 0.18);
    final bottom = Offset(cx, cy + s * 0.35);

    final innerTop = Offset(cx, cy - s * 0.19);
    final innerLeft = Offset(cx - s * 0.10, cy - s * 0.05);
    final innerRight = Offset(cx + s * 0.10, cy - s * 0.05);
    final innerBottom = Offset(cx, cy + s * 0.18);

    void drawFacet(List<Offset> pts, Color color) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = color);
    }

    // Left crown & body facets (brightest gold)
    drawFacet([top, upperLeft, innerLeft, innerTop], const Color(0xFFFDE047));
    drawFacet([top, innerTop, innerRight, upperRight], const Color(0xFFFACC15));
    drawFacet([upperLeft, lowerLeft, innerLeft], const Color(0xFFF59E0B));
    // Center table facet
    drawFacet(
      [innerTop, innerRight, innerBottom, innerLeft],
      const Color(0xFFFBBF24),
    );
    // Right & bottom facets (rich amber)
    drawFacet([upperRight, innerRight, lowerRight], const Color(0xFFD97706));
    drawFacet([lowerLeft, bottom, innerBottom, innerLeft], const Color(0xFFD97706));
    drawFacet([innerBottom, bottom, lowerRight, innerRight], const Color(0xFFB45309));

    // Crisp facet edge highlight
    final outline = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(upperRight.dx, upperRight.dy)
      ..lineTo(lowerRight.dx, lowerRight.dy)
      ..lineTo(bottom.dx, bottom.dy)
      ..lineTo(lowerLeft.dx, lowerLeft.dy)
      ..lineTo(upperLeft.dx, upperLeft.dy)
      ..close();
    canvas.drawPath(
      outline,
      Paint()
        ..color = const Color(0xFFFEF08A).withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.018,
    );

    // Stylized Fountain Pen angled diagonally in front of the crystal
    canvas.save();
    canvas.translate(cx + s * 0.04, cy + s * 0.04);
    canvas.rotate(-math.pi / 4); // 45 deg nib pointing bottom-left

    // Pen barrel (deep ink slate with subtle highlight)
    final barrelRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(s * 0.12, 0),
        width: s * 0.36,
        height: s * 0.085,
      ),
      Radius.circular(s * 0.03),
    );
    canvas.drawRRect(barrelRect, Paint()..color = const Color(0xFF0F172A));
    canvas.drawRRect(
      barrelRect,
      Paint()
        ..color = const Color(0xFF94A3B8).withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.012,
    );

    // Gold collar ring
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(-s * 0.06, 0),
        width: s * 0.035,
        height: s * 0.095,
      ),
      Paint()..color = const Color(0xFFFDE047),
    );

    // Fountain pen nib (pointing left in rotated coordinates)
    final nibPath = Path()
      ..moveTo(-s * 0.075, -s * 0.045)
      ..lineTo(-s * 0.24, 0)
      ..lineTo(-s * 0.075, s * 0.045)
      ..close();
    canvas.drawPath(nibPath, Paint()..color = const Color(0xFFFEF3C7));
    canvas.drawPath(
      nibPath,
      Paint()
        ..color = const Color(0xFF92400E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.012,
    );

    // Nib slit + breather hole
    canvas.drawLine(
      Offset(-s * 0.23, 0),
      Offset(-s * 0.13, 0),
      Paint()
        ..color = const Color(0xFF1E293B)
        ..strokeWidth = s * 0.012,
    );
    canvas.drawCircle(
      Offset(-s * 0.125, 0),
      s * 0.013,
      Paint()..color = const Color(0xFF1E293B),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
