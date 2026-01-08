import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';

// --- COLORS ---
const Color kBackgroundColor = Color(0xFF1A1A1A);
const Color kCardColor = Color(0xFF2C2C2C);
const Color kPrimaryColor = Color(0xFFFF5722); // Orange
const Color kSecondaryColor = Color(0xFFE64A19); // Darker Orange
const Color kTextColor = Colors.white;
const Color kSubTextColor = Colors.grey;

// --- GRADIENT LINE CHART ---
class GradientLineChart extends StatelessWidget {
  final List<double> dataPoints;
  final double height;

  const GradientLineChart({super.key, required this.dataPoints, this.height = 60});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(
        painter: _GradientLineChartPainter(dataPoints),
      ),
    );
  }
}

class _GradientLineChartPainter extends CustomPainter {
  final List<double> dataPoints;

  _GradientLineChartPainter(this.dataPoints);

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [kPrimaryColor.withOpacity(0.8), kSecondaryColor.withOpacity(0.2)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [kPrimaryColor.withOpacity(0.25), kSecondaryColor.withOpacity(0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    double maxY = dataPoints.reduce((a, b) => a > b ? a : b);
    double minY = dataPoints.reduce((a, b) => a < b ? a : b);
    double rangeY = maxY - minY;
    if (rangeY == 0) rangeY = maxY == 0 ? 1 : maxY; // Avoid division by zero when all values equal

    const double topPadding = 8.0;
    const double bottomPadding = 8.0;
    final double availHeight = size.height - topPadding - bottomPadding;

    double xStep = dataPoints.length == 1 ? 0 : size.width / (dataPoints.length - 1);

    // Keep track of the computed points so we can draw markers and labels
    final List<Offset> points = [];

    for (int i = 0; i < dataPoints.length; i++) {
      final double x = dataPoints.length == 1 ? size.width / 2 : i * xStep;
      final double normalized = (dataPoints[i] - minY) / rangeY;
      final double y = topPadding + (1 - normalized) * availHeight;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(0, size.height);
        fillPath.lineTo(x, y);
      } else {
        final double prevX = points.last.dx;
        final double prevY = points.last.dy;
        final double controlX1 = prevX + (x - prevX) / 2;
        final double controlY1 = prevY;
        final double controlX2 = prevX + (x - prevX) / 2;
        final double controlY2 = y;

        path.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
        fillPath.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
      }

      points.add(Offset(x, y));
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Draw filled area
    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    canvas.drawPath(path, paint);

    // Draw markers and value labels for each point
    final markerPaint = Paint()..color = kPrimaryColor;
    const double markerRadius = 4.0;

    const textStyle = TextStyle(color: kSubTextColor, fontSize: 10);

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      canvas.drawCircle(p, markerRadius, markerPaint);

      // Draw value label above point (if value > 0 or small number of points)
      if (dataPoints[i] > 0 || dataPoints.length <= 6) {
        final tp = TextPainter(
          text: TextSpan(text: dataPoints[i].toStringAsFixed(dataPoints[i] % 1 == 0 ? 0 : 1), style: textStyle),
          textDirection: ui.TextDirection.ltr,
        );
        tp.layout();
        tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy - markerRadius - tp.height - 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GradientLineChartPainter oldDelegate) => !listEquals(oldDelegate.dataPoints, dataPoints);
}

// --- BAR CHART ---
class BarChart extends StatelessWidget {
  final List<double> dataPoints;
  final List<String> labels;
  final double height;

  const BarChart({super.key, required this.dataPoints, required this.labels, this.height = 150});

  @override
  Widget build(BuildContext context) {
    double maxY = dataPoints.isEmpty ? 1 : dataPoints.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: height,
      child: Column(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(dataPoints.length, (index) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(dataPoints[index]),
                        style: const TextStyle(color: kSubTextColor, fontSize: 10)),
                    const SizedBox(height: 5),
                    Container(
                      width: 12,
                      height: (dataPoints[index] / maxY) * (height - 30), // Adjust height
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [kPrimaryColor, kSecondaryColor],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(labels.length, (index) {
              return Text(labels[index], style: const TextStyle(color: kSubTextColor, fontSize: 10));
            }),
          ),
        ],
      ),
    );
  }
}

// --- CUSTOM CARD ---
class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const CustomCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

// --- CUSTOM BOTTOM NAVIGATION BAR ---
class CustomBottomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final VoidCallback onAddTapped;

  const CustomBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    required this.onAddTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      height: 86,
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(38),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(Icons.home, 0),
          _buildAddButton(),
          _buildNavItem(Icons.analytics, 1),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    return GestureDetector(
      onTap: () => onItemTapped(index),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selectedIndex == index ? kPrimaryColor.withOpacity(0.1) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: selectedIndex == index ? kPrimaryColor : kSubTextColor,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: onAddTapped,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [kPrimaryColor, kSecondaryColor]),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: kPrimaryColor.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5)),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }
}