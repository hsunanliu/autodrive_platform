// mobile/lib/widgets/street_view_image.dart
/**
 * Google Street View Static API 圖片小部件
 *
 * 功能：
 * 1. 根據經緯度載入 Street View 靜態圖片
 * 2. 失敗時顯示預設 placeholder 圖片
 * 3. 支援自訂寬高、FOV、Heading 等參數
 * 4. 緩存處理（由 Image.network 自動處理）
 */

import 'package:flutter/material.dart';
import '../config/google_maps_config.dart';

class StreetViewImage extends StatefulWidget {
  const StreetViewImage({
    super.key,
    required this.latitude,
    required this.longitude,
    this.width = 600,
    this.height = 300,
    this.fov = 90,
    this.heading,
    this.pitch = 0,
    this.borderRadius = 12.0,
  });

  final double latitude;
  final double longitude;
  final int width; // 圖片寬度（px）
  final int height; // 圖片高度（px）
  final int fov; // Field of View (0-120)
  final double? heading; // 朝向角度 (0-360)
  final double pitch; // 俯仰角度 (-90 ~ 90)
  final double borderRadius;

  @override
  State<StreetViewImage> createState() => _StreetViewImageState();
}

class _StreetViewImageState extends State<StreetViewImage> {
  bool _hasError = false;

  /// 生成 Street View Static API URL
  String _getStreetViewUrl() {
    final apiKey = GoogleMapsConfig.apiKey;

    // 計算朝向（如果未指定，則面向正北）
    final heading = widget.heading ?? 0.0;

    final url = 'https://maps.googleapis.com/maps/api/streetview'
        '?size=${widget.width}x${widget.height}'
        '&location=${widget.latitude},${widget.longitude}'
        '&fov=${widget.fov}'
        '&heading=$heading'
        '&pitch=${widget.pitch}'
        '&key=$apiKey';

    return url;
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildPlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Image.network(
        _getStreetViewUrl(),
        width: double.infinity,
        height: widget.height.toDouble(),
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return Container(
            height: widget.height.toDouble(),
            color: const Color(0xFF2A2A2A),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1DB954)),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          // 載入失敗時顯示 placeholder
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _hasError = true);
            }
          });
          return _buildPlaceholder();
        },
      ),
    );
  }

  /// 建立預設 Placeholder
  Widget _buildPlaceholder() {
    return Container(
      height: widget.height.toDouble(),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.streetview,
            size: 48,
            color: Colors.grey.shade600,
          ),
          const SizedBox(height: 12),
          Text(
            '街景圖片暫時無法載入',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.latitude.toStringAsFixed(5)}, ${widget.longitude.toStringAsFixed(5)}',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}


/// 可展開的 Street View 卡片
class ExpandableStreetViewCard extends StatefulWidget {
  const ExpandableStreetViewCard({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.title,
    this.subtitle,
  });

  final double latitude;
  final double longitude;
  final String title;
  final String? subtitle;

  @override
  State<ExpandableStreetViewCard> createState() => _ExpandableStreetViewCardState();
}

class _ExpandableStreetViewCardState extends State<ExpandableStreetViewCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // 標題列（可點擊展開/收起）
          InkWell(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.streetview,
                    color: const Color(0xFF1DB954),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle!,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 可展開的街景圖片
          SizeTransition(
            sizeFactor: _animation,
            axisAlignment: -1.0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: StreetViewImage(
                latitude: widget.latitude,
                longitude: widget.longitude,
                width: 600,
                height: 200,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
