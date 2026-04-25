import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/vital_status.dart';

class VitalCard extends StatefulWidget {
  final String label;
  final String value;
  final String unit;
  final VitalStatus status;
  final IconData icon;
  final bool isPulsing;

  const VitalCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.status,
    required this.icon,
    this.isPulsing = false,
  });

  @override
  State<VitalCard> createState() => _VitalCardState();
}

class _VitalCardState extends State<VitalCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    if (widget.isPulsing) _pulseCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(VitalCard old) {
    super.didUpdateWidget(old);
    if (widget.isPulsing && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!widget.isPulsing && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forStatus(widget.status);
    final bgColor = AppColors.bgForStatus(widget.status);
    final borderColor = AppColors.borderForStatus(widget.status);

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: icon + status chip
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, color: color, size: 17),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.status.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    color: color,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Value
          Text(
            widget.value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.1,
            ),
          ),
          // Label + unit
          Text(
            widget.unit.isNotEmpty
                ? '${widget.label} Â· ${widget.unit}'
                : widget.label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    if (widget.isPulsing) {
      return ScaleTransition(scale: _pulseScale, child: card);
    }
    return card;
  }
}
