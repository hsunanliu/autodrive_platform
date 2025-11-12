import React, { useState, useEffect } from 'react';
import Layout from '../components/Layout';
import { tripAPI } from '../services/api';
import {
  ShoppingCart, Search, Filter, Calendar, DollarSign,
  MapPin, User, Car, Clock, CheckCircle, XCircle,
  AlertCircle, RefreshCw, Eye, ChevronDown, ChevronUp
} from 'lucide-react';
import DualCurrencyDisplay from '../components/DualCurrencyDisplay';

const OrderCenter = () => {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState('');
  const [roleFilter, setRoleFilter] = useState(''); // passenger or driver
  const [timeFilter, setTimeFilter] = useState('all'); // all, today, week, month
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedOrder, setSelectedOrder] = useState(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [expandedOrder, setExpandedOrder] = useState(null);

  useEffect(() => {
    fetchOrders();
  }, [statusFilter, roleFilter, timeFilter]);

  const fetchOrders = async () => {
    try {
      setLoading(true);
      const params = {};

      if (statusFilter) params.status = statusFilter;
      if (roleFilter) params.role = roleFilter;

      // 時間過濾
      if (timeFilter !== 'all') {
        const now = new Date();
        let startDate;

        if (timeFilter === 'today') {
          startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        } else if (timeFilter === 'week') {
          startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        } else if (timeFilter === 'month') {
          startDate = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
        }

        if (startDate) {
          params.start_date = startDate.toISOString();
        }
      }

      const response = await tripAPI.getAll(params);
      setOrders(response.data || []);
    } catch (error) {
      console.error('獲取訂單失敗:', error);
      alert('載入訂單資料失敗');
    } finally {
      setLoading(false);
    }
  };

  // 篩選訂單（本地搜尋）
  const filteredOrders = orders.filter(order => {
    if (!searchQuery) return true;

    const query = searchQuery.toLowerCase();
    return (
      order.trip_id?.toString().includes(query) ||
      order.rider_name?.toLowerCase().includes(query) ||
      order.driver_name?.toLowerCase().includes(query) ||
      order.pickup_address?.toLowerCase().includes(query) ||
      order.dropoff_address?.toLowerCase().includes(query) ||
      order.plate_number?.toLowerCase().includes(query)
    );
  });

  // 訂單統計
  const getOrderStats = () => {
    const total = orders.length;
    const ongoing = orders.filter(o =>
      ['requested', 'matched', 'accepted', 'picked_up', 'in_progress'].includes(o.status)
    ).length;
    const completed = orders.filter(o => o.status === 'completed').length;
    const cancelled = orders.filter(o => o.status === 'cancelled').length;
    const totalRevenue = orders
      .filter(o => o.status === 'completed')
      .reduce((sum, o) => sum + (Number(o.total_amount) || 0), 0);

    return { total, ongoing, completed, cancelled, totalRevenue };
  };

  const stats = getOrderStats();

  // 狀態標籤
  const getStatusBadge = (status) => {
    const statusMap = {
      requested: { label: '已建立', class: 'badge-info', icon: Clock },
      matched: { label: '已配對', class: 'badge-info', icon: RefreshCw },
      accepted: { label: '已接受', class: 'badge-warning', icon: CheckCircle },
      picked_up: { label: '已接客', class: 'badge-warning', icon: User },
      in_progress: { label: '行程中', class: 'badge-warning', icon: Car },
      completed: { label: '已完成', class: 'badge-success', icon: CheckCircle },
      cancelled: { label: '已取消', class: 'badge-danger', icon: XCircle },
    };

    const statusInfo = statusMap[status] || { label: status, class: 'badge-secondary', icon: AlertCircle };
    const Icon = statusInfo.icon;

    return (
      <span className={`badge ${statusInfo.class}`} style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
        <Icon size={14} />
        {statusInfo.label}
      </span>
    );
  };

  // 支付狀態標籤
  const getPaymentBadge = (status) => {
    const paymentMap = {
      pending: { label: '待付款', class: 'badge-warning' },
      completed: { label: '已付款', class: 'badge-success' },
      failed: { label: '付款失敗', class: 'badge-danger' },
      refunded: { label: '已退款', class: 'badge-info' },
    };

    const paymentInfo = paymentMap[status] || { label: status || '未知', class: 'badge-secondary' };
    return <span className={`badge ${paymentInfo.class}`}>{paymentInfo.label}</span>;
  };

  // 展開/收起訂單詳情
  const toggleExpand = (orderId) => {
    setExpandedOrder(expandedOrder === orderId ? null : orderId);
  };

  if (loading && orders.length === 0) {
    return (
      <Layout>
        <div className="loading">
          <div className="spinner-lg" />
          <p style={{ color: '#64748b', fontSize: '1.125rem', fontWeight: '600' }}>載入訂單資料中...</p>
        </div>
      </Layout>
    );
  }

  return (
    <Layout>
      <div style={{ maxWidth: '1600px', margin: '0 auto' }}>
        {/* Header */}
        <div style={{
          background: 'linear-gradient(135deg, #8b5cf6 0%, #6366f1 100%)',
          borderRadius: '24px',
          padding: '2.5rem',
          marginBottom: '2rem',
          color: 'white',
          boxShadow: '0 10px 40px rgba(139, 92, 246, 0.3)'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
            <div style={{
              padding: '12px',
              background: 'rgba(255, 255, 255, 0.2)',
              borderRadius: '16px',
              backdropFilter: 'blur(10px)'
            }}>
              <ShoppingCart size={36} />
            </div>
            <div>
              <h1 style={{ fontSize: '2.5rem', fontWeight: '900', marginBottom: '0.25rem' }}>訂單中心</h1>
              <p style={{ fontSize: '1.125rem', opacity: 0.95 }}>統一管理所有乘客與車主訂單</p>
            </div>
          </div>
        </div>

        {/* 統計卡片 */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
          gap: '1.5rem',
          marginBottom: '2rem'
        }}>
          <StatCard title="總訂單數" value={stats.total} icon={ShoppingCart} color="#8b5cf6" bgColor="#f5f3ff" />
          <StatCard title="進行中" value={stats.ongoing} icon={RefreshCw} color="#f59e0b" bgColor="#fffbeb" />
          <StatCard title="已完成" value={stats.completed} icon={CheckCircle} color="#10b981" bgColor="#f0fdf4" />
          <StatCard title="已取消" value={stats.cancelled} icon={XCircle} color="#ef4444" bgColor="#fef2f2" />
          <StatCard
            title="總營收"
            value={stats.totalRevenue}
            valueType="currency"
            icon={DollarSign}
            color="#3b82f6"
            bgColor="#eff6ff"
          />
        </div>

        {/* 過濾器 */}
        <div className="card" style={{ marginBottom: '2rem' }}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1.5rem' }}>
            {/* 訂單狀態過濾 */}
            <div>
              <label style={{
                display: 'flex',
                alignItems: 'center',
                gap: '0.5rem',
                fontSize: '0.875rem',
                fontWeight: '700',
                color: '#334155',
                marginBottom: '0.5rem'
              }}>
                <Filter size={18} />
                <span>訂單狀態</span>
              </label>
              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                className="select-field"
              >
                <option value="">全部狀態</option>
                <option value="requested">已建立</option>
                <option value="matched">已配對</option>
                <option value="accepted">已接受</option>
                <option value="picked_up">已接客</option>
                <option value="in_progress">行程中</option>
                <option value="completed">已完成</option>
                <option value="cancelled">已取消</option>
              </select>
            </div>

            {/* 角色過濾 */}
            <div>
              <label style={{
                display: 'flex',
                alignItems: 'center',
                gap: '0.5rem',
                fontSize: '0.875rem',
                fontWeight: '700',
                color: '#334155',
                marginBottom: '0.5rem'
              }}>
                <User size={18} />
                <span>角色</span>
              </label>
              <select
                value={roleFilter}
                onChange={(e) => setRoleFilter(e.target.value)}
                className="select-field"
              >
                <option value="">全部角色</option>
                <option value="passenger">乘客訂單</option>
                <option value="driver">車主訂單</option>
              </select>
            </div>

            {/* 時間過濾 */}
            <div>
              <label style={{
                display: 'flex',
                alignItems: 'center',
                gap: '0.5rem',
                fontSize: '0.875rem',
                fontWeight: '700',
                color: '#334155',
                marginBottom: '0.5rem'
              }}>
                <Calendar size={18} />
                <span>時間範圍</span>
              </label>
              <select
                value={timeFilter}
                onChange={(e) => setTimeFilter(e.target.value)}
                className="select-field"
              >
                <option value="all">全部時間</option>
                <option value="today">今天</option>
                <option value="week">最近7天</option>
                <option value="month">最近30天</option>
              </select>
            </div>

            {/* 搜尋 */}
            <div>
              <label style={{
                display: 'flex',
                alignItems: 'center',
                gap: '0.5rem',
                fontSize: '0.875rem',
                fontWeight: '700',
                color: '#334155',
                marginBottom: '0.5rem'
              }}>
                <Search size={18} />
                <span>搜尋</span>
              </label>
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="input-field"
                placeholder="訂單 ID、姓名、地址、車牌..."
              />
            </div>
          </div>
        </div>

        {/* 結果統計 */}
        <div style={{
          marginBottom: '1.5rem',
          padding: '1rem 1.5rem',
          background: 'linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%)',
          borderRadius: '16px',
          border: '2px solid #bbf7d0'
        }}>
          <p style={{ fontSize: '0.9375rem', fontWeight: '700', color: '#15803d' }}>
            找到 <span style={{ fontSize: '1.25rem', color: '#16a34a' }}>{filteredOrders.length}</span> 筆訂單
          </p>
        </div>

        {/* 訂單列表 */}
        <div>
          {filteredOrders.length === 0 ? (
            <div className="card" style={{ textAlign: 'center', padding: '3rem' }}>
              <AlertCircle size={48} style={{ margin: '0 auto 1rem', opacity: 0.5, color: '#94a3b8' }} />
              <p style={{ fontSize: '1.125rem', fontWeight: '600', color: '#475569' }}>暫無訂單資料</p>
            </div>
          ) : (
            filteredOrders.map((order) => (
              <OrderCard
                key={order.trip_id}
                order={order}
                expanded={expandedOrder === order.trip_id}
                onToggle={() => toggleExpand(order.trip_id)}
                getStatusBadge={getStatusBadge}
                getPaymentBadge={getPaymentBadge}
              />
            ))
          )}
        </div>
      </div>
    </Layout>
  );
};

// 統計卡片組件
const StatCard = ({ title, value, valueType, icon: Icon, color, bgColor }) => (
  <div className="card" style={{ borderLeft: `4px solid ${color}` }}>
    <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
      <div style={{
        padding: '12px',
        borderRadius: '12px',
        background: bgColor,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center'
      }}>
        <Icon size={24} style={{ color }} />
      </div>
      <div style={{ flex: 1 }}>
        <p style={{
          fontSize: '0.875rem',
          fontWeight: '600',
          color: '#64748b',
          marginBottom: '0.25rem'
        }}>
          {title}
        </p>
        <p style={{ fontSize: '1.75rem', fontWeight: '900', color: '#0f172a', lineHeight: '1' }}>
          {valueType === 'currency' ? (
            <DualCurrencyDisplay suiAmount={value} />
          ) : (
            value
          )}
        </p>
      </div>
    </div>
  </div>
);

// 訂單卡片組件
const OrderCard = ({ order, expanded, onToggle, getStatusBadge, getPaymentBadge }) => (
  <div className="card" style={{ marginBottom: '1rem' }}>
    {/* 訂單標題列（可點擊展開） */}
    <div
      onClick={onToggle}
      style={{
        cursor: 'pointer',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        paddingBottom: expanded ? '1rem' : '0',
        borderBottom: expanded ? '2px solid #e2e8f0' : 'none',
        marginBottom: expanded ? '1rem' : '0'
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: '1rem', flex: 1 }}>
        <div>
          <p style={{ fontSize: '1.25rem', fontWeight: '900', color: '#1e40af', marginBottom: '0.25rem' }}>
            訂單 #{order.trip_id}
          </p>
          <p style={{ fontSize: '0.875rem', color: '#64748b' }}>
            {new Date(order.requested_at).toLocaleString('zh-TW')}
          </p>
        </div>
      </div>

      <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
        {getStatusBadge(order.status)}
        {getPaymentBadge(order.payment_status)}
        <div style={{ fontSize: '1.125rem', fontWeight: '900', color: '#0f172a' }}>
          {order.total_amount ? (
            <DualCurrencyDisplay suiAmount={Number(order.total_amount)} />
          ) : (
            '-'
          )}
        </div>
        {expanded ? <ChevronUp size={20} /> : <ChevronDown size={20} />}
      </div>
    </div>

    {/* 展開的訂單詳情 */}
    {expanded && (
      <div style={{ marginTop: '1rem' }}>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))', gap: '1.5rem' }}>
          {/* 乘客資訊 */}
          <InfoSection
            icon={User}
            title="乘客"
            items={[
              { label: '姓名', value: order.rider_name || '未知' },
              { label: 'ID', value: order.user_id },
              { label: '電話', value: order.rider_phone || '-' }
            ]}
          />

          {/* 司機資訊 */}
          <InfoSection
            icon={Car}
            title="司機"
            items={[
              { label: '姓名', value: order.driver_name || '未分配' },
              { label: '車牌', value: order.plate_number || '-' },
              { label: '車型', value: order.vehicle_model || '-' }
            ]}
          />

          {/* 行程資訊 */}
          <InfoSection
            icon={MapPin}
            title="行程"
            items={[
              { label: '距離', value: order.distance_km ? `${Number(order.distance_km).toFixed(2)} km` : '-' },
              { label: '費用', value: order.total_amount, valueType: 'currency' },
              { label: '支付', value: order.payment_status || '-' }
            ]}
          />
        </div>

        {/* 地址資訊 */}
        <div style={{ marginTop: '1.5rem', padding: '1rem', background: '#f8fafc', borderRadius: '12px' }}>
          <div style={{ marginBottom: '0.75rem' }}>
            <p style={{ fontSize: '0.875rem', fontWeight: '700', color: '#64748b', marginBottom: '0.5rem' }}>
              📍 上車點
            </p>
            <p style={{ fontSize: '0.9375rem', color: '#0f172a' }}>
              {order.pickup_address || `${order.pickup_lat}, ${order.pickup_lng}`}
            </p>
          </div>
          {order.dropoff_lat && order.dropoff_lng && (
            <div>
              <p style={{ fontSize: '0.875rem', fontWeight: '700', color: '#64748b', marginBottom: '0.5rem' }}>
                🏁 下車點
              </p>
              <p style={{ fontSize: '0.9375rem', color: '#0f172a' }}>
                {order.dropoff_address || `${order.dropoff_lat}, ${order.dropoff_lng}`}
              </p>
            </div>
          )}
        </div>
      </div>
    )}
  </div>
);

// 資訊區塊組件
const InfoSection = ({ icon: Icon, title, items }) => (
  <div style={{ padding: '1rem', background: '#f8fafc', borderRadius: '12px' }}>
    <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.75rem' }}>
      <Icon size={18} color="#6366f1" />
      <p style={{ fontSize: '0.875rem', fontWeight: '700', color: '#64748b' }}>{title}</p>
    </div>
    {items.map((item, index) => (
      <div key={index} style={{ marginBottom: '0.5rem' }}>
        <p style={{ fontSize: '0.75rem', color: '#94a3b8' }}>{item.label}</p>
        <p style={{ fontSize: '0.9375rem', fontWeight: '600', color: '#0f172a' }}>
          {item.valueType === 'currency' ? (
            item.value ? <DualCurrencyDisplay suiAmount={Number(item.value)} /> : '-'
          ) : (
            item.value
          )}
        </p>
      </div>
    ))}
  </div>
);

export default OrderCenter;
