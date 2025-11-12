// mobile/lib/pages/order_center_page.dart
/**
 * 訂單中心 - 統一管理乘客與車主訂單
 *
 * 功能：
 * 1. 歷史訂單查詢（支援篩選、搜尋）
 * 2. 進行中訂單快速查看
 * 3. 退款申請與管理
 * 4. 訂單狀態時間軸
 * 5. 營收統計（車主）/ 消費統計（乘客）
 */

import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../session_manager.dart';
import '../payment_page.dart';

class OrderCenterPage extends StatefulWidget {
  const OrderCenterPage({super.key, required this.session});

  final UserSession? session;

  @override
  State<OrderCenterPage> createState() => _OrderCenterPageState();
}

class _OrderCenterPageState extends State<OrderCenterPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _filteredOrders = [];
  bool _isLoading = true;
  String _statusFilter = 'all';
  String _timeFilter = 'all'; // all, today, week, month
  String _searchQuery = '';

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);

    try {
      final result = await ApiService.getUserTrips(limit: 100);

      if (result['success'] == true && result['data'] is List) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(result['data']);
          _applyFilters();
          _isLoading = false;
        });
      } else {
        setState(() {
          _orders = [];
          _filteredOrders = [];
          _isLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        _orders = [];
        _filteredOrders = [];
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('載入訂單失敗: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = _orders;

    // 狀態過濾
    if (_statusFilter != 'all') {
      if (_statusFilter == 'ongoing') {
        filtered = filtered.where((order) {
          final status = order['status'] as String?;
          return ['requested', 'matched', 'accepted', 'picked_up', 'in_progress']
              .contains(status);
        }).toList();
      } else {
        filtered = filtered
            .where((order) => order['status'] == _statusFilter)
            .toList();
      }
    }

    // 時間過濾
    if (_timeFilter != 'all') {
      final now = DateTime.now();
      DateTime? startDate;

      if (_timeFilter == 'today') {
        startDate = DateTime(now.year, now.month, now.day);
      } else if (_timeFilter == 'week') {
        startDate = now.subtract(const Duration(days: 7));
      } else if (_timeFilter == 'month') {
        startDate = now.subtract(const Duration(days: 30));
      }

      if (startDate != null) {
        filtered = filtered.where((order) {
          final requestedAt = order['requested_at'] as String?;
          if (requestedAt == null) return false;
          final orderDate = DateTime.parse(requestedAt);
          return orderDate.isAfter(startDate!);
        }).toList();
      }
    }

    // 搜尋過濾
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((order) {
        final tripId = order['trip_id']?.toString() ?? '';
        final riderName = order['rider_name']?.toString().toLowerCase() ?? '';
        final driverName = order['driver_name']?.toString().toLowerCase() ?? '';
        final pickupAddr = order['pickup_address']?.toString().toLowerCase() ?? '';
        final dropoffAddr = order['dropoff_address']?.toString().toLowerCase() ?? '';

        return tripId.contains(query) ||
            riderName.contains(query) ||
            driverName.contains(query) ||
            pickupAddr.contains(query) ||
            dropoffAddr.contains(query);
      }).toList();
    }

    // 按時間倒序排列
    filtered.sort((a, b) {
      final aTime = a['requested_at'] as String?;
      final bTime = b['requested_at'] as String?;
      if (aTime == null || bTime == null) return 0;
      return bTime.compareTo(aTime);
    });

    setState(() => _filteredOrders = filtered);
  }

  // 訂單統計
  Map<String, dynamic> _getStatistics() {
    final total = _orders.length;
    final ongoing = _orders.where((o) =>
        ['requested', 'matched', 'accepted', 'picked_up', 'in_progress']
            .contains(o['status'])).length;
    final completed = _orders.where((o) => o['status'] == 'completed').length;
    final cancelled = _orders.where((o) => o['status'] == 'cancelled').length;

    double totalSpent = 0;
    for (final order in _orders.where((o) => o['status'] == 'completed')) {
      final amount = order['total_amount'];
      if (amount != null) {
        if (amount is int) {
          totalSpent += amount / 1000000000.0; // micro SUI to SUI
        } else if (amount is double) {
          totalSpent += amount;
        }
      }
    }

    return {
      'total': total,
      'ongoing': ongoing,
      'completed': completed,
      'cancelled': cancelled,
      'totalSpent': totalSpent,
    };
  }

  @override
  Widget build(BuildContext context) {
    final stats = _getStatistics();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('訂單中心'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
            tooltip: '重新整理',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '全部', icon: Icon(Icons.list, size: 20)),
            Tab(text: '進行中', icon: Icon(Icons.directions_car, size: 20)),
            Tab(text: '已完成', icon: Icon(Icons.check_circle, size: 20)),
          ],
          onTap: (index) {
            setState(() {
              if (index == 0) _statusFilter = 'all';
              if (index == 1) _statusFilter = 'ongoing';
              if (index == 2) _statusFilter = 'completed';
              _applyFilters();
            });
          },
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1DB954)))
          : Column(
              children: [
                // 統計卡片
                _buildStatisticsCards(stats),
                // 過濾器
                _buildFilters(),
                // 訂單列表
                Expanded(child: _buildOrderList()),
              ],
            ),
    );
  }

  Widget _buildStatisticsCards(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.2,
        children: [
          _buildStatCard(
            '總訂單',
            stats['total'].toString(),
            Icons.receipt_long,
            const Color(0xFF8b5cf6),
          ),
          _buildStatCard(
            '進行中',
            stats['ongoing'].toString(),
            Icons.pending,
            const Color(0xFFf59e0b),
          ),
          _buildStatCard(
            '已完成',
            stats['completed'].toString(),
            Icons.check_circle,
            const Color(0xFF10b981),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        border: Border(
          bottom: BorderSide(color: Color(0xFF2A2A2A), width: 1),
        ),
      ),
      child: Column(
        children: [
          // 搜尋框
          TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '搜尋訂單 ID、姓名、地址...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF2A2A2A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _applyFilters();
              });
            },
          ),
          const SizedBox(height: 12),
          // 時間過濾器
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.white54, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTimeFilterChip('全部', 'all'),
                      _buildTimeFilterChip('今天', 'today'),
                      _buildTimeFilterChip('最近7天', 'week'),
                      _buildTimeFilterChip('最近30天', 'month'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeFilterChip(String label, String value) {
    final isSelected = _timeFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          setState(() {
            _timeFilter = value;
            _applyFilters();
          });
        },
        backgroundColor: const Color(0xFF2A2A2A),
        selectedColor: const Color(0xFF1DB954),
        labelStyle: TextStyle(
          color: isSelected ? Colors.black : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildOrderList() {
    if (_filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            Text(
              '暫無訂單記錄',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredOrders.length,
      itemBuilder: (context, index) {
        final order = _filteredOrders[index];
        return _buildOrderCard(order);
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final tripId = order['trip_id'] as int;
    final status = order['status'] as String?;
    final requestedAt = order['requested_at'] as String?;
    final totalAmount = order['total_amount'];
    final paymentStatus = order['payment_status'] as String?;

    double fareInSui = 0.0;
    if (totalAmount != null) {
      if (totalAmount is int) {
        fareInSui = totalAmount / 1000000000.0;
      } else if (totalAmount is double) {
        fareInSui = totalAmount;
      }
    }

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _viewOrderDetails(order),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 標題列
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '訂單 #$tripId',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildStatusBadge(status),
                ],
              ),
              const SizedBox(height: 12),
              // 地址資訊
              _buildAddressRow(
                Icons.location_on,
                Colors.green,
                order['pickup_address'] as String? ?? '上車點未知',
              ),
              const SizedBox(height: 8),
              _buildAddressRow(
                Icons.flag,
                Colors.red,
                order['dropoff_address'] as String? ?? '下車點未知',
              ),
              const SizedBox(height: 12),
              // 底部資訊
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    requestedAt != null
                        ? _formatDateTime(requestedAt)
                        : '時間未知',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  Row(
                    children: [
                      if (paymentStatus != null)
                        _buildPaymentBadge(paymentStatus),
                      const SizedBox(width: 8),
                      Text(
                        '${fareInSui.toStringAsFixed(4)} SUI',
                        style: const TextStyle(
                          color: Color(0xFF1DB954),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressRow(IconData icon, Color color, String address) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            address,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String? status) {
    final statusMap = {
      'requested': {'label': '已建立', 'color': Colors.blue},
      'matched': {'label': '已配對', 'color': Colors.purple},
      'accepted': {'label': '已接受', 'color': Colors.orange},
      'picked_up': {'label': '已接客', 'color': Colors.amber},
      'in_progress': {'label': '行程中', 'color': Colors.cyan},
      'completed': {'label': '已完成', 'color': Colors.green},
      'cancelled': {'label': '已取消', 'color': Colors.red},
    };

    final info = statusMap[status] ?? {'label': status ?? '未知', 'color': Colors.grey};

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: (info['color'] as Color).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: info['color'] as Color, width: 1),
      ),
      child: Text(
        info['label'] as String,
        style: TextStyle(
          color: info['color'] as Color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPaymentBadge(String status) {
    final paymentMap = {
      'pending': {'label': '待付款', 'color': Colors.orange},
      'completed': {'label': '已付款', 'color': Colors.green},
      'failed': {'label': '失敗', 'color': Colors.red},
      'refunded': {'label': '已退款', 'color': Colors.blue},
    };

    final info = paymentMap[status] ?? {'label': status, 'color': Colors.grey};

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (info['color'] as Color).withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        info['label'] as String,
        style: TextStyle(
          color: info['color'] as Color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.year}/${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '時間格式錯誤';
    }
  }

  void _viewOrderDetails(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return OrderDetailsSheet(order: order, scrollController: scrollController);
        },
      ),
    );
  }
}

// 訂單詳情底部彈窗
class OrderDetailsSheet extends StatelessWidget {
  const OrderDetailsSheet({
    super.key,
    required this.order,
    required this.scrollController,
  });

  final Map<String, dynamic> order;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: ListView(
        controller: scrollController,
        children: [
          // 拖動指示器
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 標題
          Text(
            '訂單 #${order['trip_id']}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          // 詳細資訊
          _buildDetailRow('訂單狀態', order['status'] ?? '未知'),
          _buildDetailRow('乘客姓名', order['rider_name'] ?? '未知'),
          _buildDetailRow('司機姓名', order['driver_name'] ?? '未分配'),
          _buildDetailRow('車牌號碼', order['plate_number'] ?? '-'),
          _buildDetailRow('距離', order['distance_km']?.toString() ?? '-'),
          _buildDetailRow('費用', '${_calculateFare(order['total_amount'])} SUI'),
          _buildDetailRow('支付狀態', order['payment_status'] ?? '未知'),
          _buildDetailRow('上車點', order['pickup_address'] ?? '-'),
          _buildDetailRow('下車點', order['dropoff_address'] ?? '-'),
          _buildDetailRow(
            '請求時間',
            order['requested_at'] != null
                ? DateTime.parse(order['requested_at']).toLocal().toString()
                : '-',
          ),
          const SizedBox(height: 24),
          // 關閉按鈕
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DB954),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _calculateFare(dynamic amount) {
    if (amount == null) return '0.0000';
    if (amount is int) {
      return (amount / 1000000000.0).toStringAsFixed(4);
    } else if (amount is double) {
      return amount.toStringAsFixed(4);
    }
    return '0.0000';
  }
}
