import 'package:flutter/material.dart';

import 'driver_earnings_page.dart';
import 'services/api_service.dart';
import 'session_manager.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.session});

  final UserSession? session;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  String? _error;

  UserSession? get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (_session == null) {
      setState(() {
        _isLoading = false;
        _error = '帳戶尚未登入';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await ApiService.getUserProfile(_session!.userId);
    if (!mounted) return;

    if (result['success'] == true && result['data'] is Map) {
      setState(() {
        _profile = result['data'] as Map<String, dynamic>;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _error = result['error']?.toString() ?? '載入失敗';
      });
    }
  }

  Future<void> _logout() async {
    await SessionManager.clearSession();
    ApiService.clearToken();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/role_select', (route) => false);
  }

  void _openEarnings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DriverEarningsPage(session: _session)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('個人檔案'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadProfile,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1DB954)));
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    final profile = _profile ?? {};
    final session = _session;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _ProfileHeader(profile: profile, session: session),
        const SizedBox(height: 24),
        _InfoTile(
          icon: Icons.wallet,
          label: '錢包地址',
          value: profile['wallet_address'] ?? session?.walletAddress ?? '--',
        ),
        _InfoTile(
          icon: Icons.phone,
          label: '手機',
          value: profile['phone_number'] ?? session?.phoneNumber ?? '--',
        ),
        _InfoTile(
          icon: Icons.email,
          label: '電子郵件',
          value: profile['email'] ?? session?.email ?? '--',
        ),
        _InfoTile(
          icon: Icons.badge,
          label: '使用者名稱',
          value: profile['username'] ?? session?.username ?? '--',
        ),
        _InfoTile(
          icon: Icons.security,
          label: '角色',
          value: profile['user_type'] ?? session?.role ?? '--',
        ),
        const SizedBox(height: 24),
        if ((profile['user_type'] ?? session?.role) == 'driver' || (profile['user_type'] ?? session?.role) == 'both')
          ElevatedButton.icon(
            onPressed: _openEarnings,
            icon: const Icon(Icons.bar_chart, color: Colors.black),
            label: const Text('查看車輛收益', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DB954),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout, color: Colors.white),
          label: const Text('登出'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E2E2E),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile, required this.session});

  final Map<String, dynamic> profile;
  final UserSession? session;

  @override
  Widget build(BuildContext context) {
    final displayName = profile['display_name'] ?? profile['username'] ?? session?.username ?? '用戶';
    final createdAt = profile['created_at']?.toString();
    final reputation = profile['reputation_score'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: Color(0xFF1DB954),
                child: Icon(Icons.person, color: Colors.black, size: 36),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    if (createdAt != null)
                      Text(
                        '加入時間：$createdAt',
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (reputation != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber),
                const SizedBox(width: 8),
                Text('信譽分數：$reputation',
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                Text(value, style: const TextStyle(color: Colors.white70, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
