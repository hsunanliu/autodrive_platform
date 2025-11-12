import 'dart:async';
import 'package:flutter/material.dart';
import '../services/price_service.dart';

/// 新行程推送通知卡片
class NewTripNotificationCard extends StatefulWidget {
  const NewTripNotificationCard({
    super.key,
    required this.tripId,
    required this.distanceToPickup,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.distanceKm,
    required this.estimatedFareSui,
    required this.timeoutSeconds,
    required this.onAccept,
    required this.onDismiss,
    this.passengerCount = 1,
    this.priority = 2,
    this.surgeReason,
  });

  final int tripId;
  final double distanceToPickup;
  final String pickupAddress;
  final String dropoffAddress;
  final double distanceKm;
  final double estimatedFareSui;
  final int timeoutSeconds;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;
  final int passengerCount;
  final int priority;
  final String? surgeReason;

  @override
  State<NewTripNotificationCard> createState() => _NewTripNotificationCardState();
}

class _NewTripNotificationCardState extends State<NewTripNotificationCard> {
  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.timeoutSeconds;
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _remainingSeconds--;
      });

      if (_remainingSeconds <= 0) {
        timer.cancel();
        // 自動關閉
        widget.onDismiss();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPriority = widget.priority == 1;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPriority ? const Color(0xFF1DB954) : Colors.orange,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (isPriority ? const Color(0xFF1DB954) : Colors.orange)
                  .withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 標題
            Row(
              children: [
                Icon(
                  isPriority ? Icons.flash_on : Icons.local_taxi,
                  color: isPriority ? const Color(0xFF1DB954) : Colors.orange,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPriority ? '快速叫車！' : '新行程！',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '行程 #${widget.tripId}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // 倒計時
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _remainingSeconds <= 10 ? Colors.red : Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_remainingSeconds 秒',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 距離信息
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.near_me, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '距離您 ${widget.distanceToPickup.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 起點
            _buildLocationRow(
              Icons.location_on,
              Colors.green,
              '起點',
              widget.pickupAddress,
            ),

            const SizedBox(height: 12),

            // 終點
            _buildLocationRow(
              Icons.flag,
              Colors.red,
              '終點',
              widget.dropoffAddress,
            ),

            const SizedBox(height: 16),

            // 行程信息
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoChip(
                  Icons.straighten,
                  '${widget.distanceKm.toStringAsFixed(1)} km',
                  Colors.blue,
                ),
                _buildInfoChip(
                  Icons.person,
                  '${widget.passengerCount} 人',
                  Colors.purple,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 費用（雙幣種）
            FutureBuilder<String>(
              future: PriceService.formatDualCurrency(widget.estimatedFareSui),
              builder: (context, snapshot) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1DB954)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.payments,
                        color: Color(0xFF1DB954),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        snapshot.data ?? '${widget.estimatedFareSui.toStringAsFixed(4)} SUI',
                        style: const TextStyle(
                          color: Color(0xFF1DB954),
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // 加價提示
            if (widget.surgeReason != null && widget.surgeReason!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.surgeReason!,
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // 按鈕
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onDismiss,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('稍後再說'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: widget.onAccept,
                    icon: const Icon(Icons.check_circle, size: 24),
                    label: const Text('接受行程'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, Color color, String label, String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
