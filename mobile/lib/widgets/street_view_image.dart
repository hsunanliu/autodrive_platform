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
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/google_maps_config.dart';

class StreetViewImage extends StatefulWidget {
  const StreetViewImage({
    super.key,
    required this.latitude,
    required this.longitude,
    this.width = 600,
    this.height = 300,
    this.fov = 120, // 使用最大視野角度，顯示更廣範圍
    this.heading,
    this.pitch = -10, // 稍微向下看，能看到更多地面和周圍環境
    this.borderRadius = 12.0,
  });

  final double latitude;
  final double longitude;
  final int width; // 圖片寬度（px）
  final int height; // 圖片高度（px）
  final int fov; // Field of View (0-120)，數值越大視野越廣
  final double? heading; // 朝向角度 (0-360)
  final double pitch; // 俯仰角度 (-90 ~ 90)，負數向下看
  final double borderRadius;

  @override
  State<StreetViewImage> createState() => _StreetViewImageState();
}

class _StreetViewImageState extends State<StreetViewImage> {
  bool _hasError = false;
  String? _panoId; // 儲存從 Metadata API 獲取的 pano_id
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPanoId();
  }

  /// 先獲取 pano_id（避免直接使用經緯度導致 502 錯誤）
  Future<void> _fetchPanoId() async {
    final apiKey = GoogleMapsConfig.apiKey;
    final metadataUrl = 'https://maps.googleapis.com/maps/api/streetview/metadata'
        '?location=${widget.latitude},${widget.longitude}'
        '&key=$apiKey';

    try {
      final response = await http.get(Uri.parse(metadataUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['pano_id'] != null) {
          if (mounted) {
            setState(() {
              _panoId = data['pano_id'];
              _isLoading = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      print('❌ 街景 Metadata 獲取失敗: $e');
    }

    // 如果獲取失敗，標記為錯誤
    if (mounted) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  /// 生成 Street View Static API URL（使用 pano_id）
  String _getStreetViewUrl() {
    final apiKey = GoogleMapsConfig.apiKey;

    // 計算朝向（如果未指定，則面向正北）
    final heading = widget.heading ?? 0.0;

    // 使用 pano_id 而不是 location，避免 502 錯誤
    final url = 'https://maps.googleapis.com/maps/api/streetview'
        '?size=${widget.width}x${widget.height}'
        '&pano=$_panoId'
        '&fov=${widget.fov}'
        '&heading=$heading'
        '&pitch=${widget.pitch}'
        '&key=$apiKey';

    return url;
  }

  /// 打開 Google Maps 街景（完整互動式街景）
  Future<void> _openGoogleMapsStreetView() async {
    // Google Maps URL Scheme for Street View
    final mapsUrl = 'https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=${widget.latitude},${widget.longitude}';

    final uri = Uri.parse(mapsUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('無法打開 Google Maps')),
          );
        }
      }
    } catch (e) {
      print('打開 Google Maps 失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打開街景失敗: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 載入中或發生錯誤時顯示 placeholder
    if (_isLoading || _hasError || _panoId == null) {
      return _buildPlaceholder(isLoading: _isLoading);
    }

    return GestureDetector(
      onTap: _openGoogleMapsStreetView,
      child: Stack(
        children: [
          // 街景圖片
          ClipRRect(
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
                return _buildPlaceholder(isLoading: false);
              },
            ),
          ),

          // 右上角提示：點擊查看完整街景
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.open_in_new,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '點擊查看 360° 街景',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 建立預設 Placeholder
  Widget _buildPlaceholder({bool isLoading = false}) {
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
          if (isLoading)
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1DB954)),
            )
          else
            Icon(
              Icons.streetview,
              size: 48,
              color: Colors.grey.shade600,
            ),
          const SizedBox(height: 12),
          Text(
            isLoading ? '載入街景中...' : '街景圖片暫時無法載入',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!isLoading) ...[
            const SizedBox(height: 4),
            Text(
              '${widget.latitude.toStringAsFixed(5)}, ${widget.longitude.toStringAsFixed(5)}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
              ),
            ),
          ],
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
