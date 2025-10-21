import React, { useState, useEffect } from 'react';
import Layout from '../components/Layout';
import { tripAPI } from '../services/api';
import { MapPin, Search, Filter, User, Car, Calendar, DollarSign, AlertCircle, Eye, X, Clock, Navigation } from 'lucide-react';

const TripDetails = () => {
  const [trips, setTrips] = useState([]);
  const [allTrips, setAllTrips] = useState([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState('');
  const [searchType, setSearchType] = useState('trip_id');
  const [searchValue, setSearchValue] = useState('');
  const [selectedTrip, setSelectedTrip] = useState(null);
  const [modalOpen, setModalOpen] = useState(false);

  useEffect(() => {
    fetchAllTrips();
    fetchTrips();
  }, []);

  useEffect(() => {
    fetchTrips();
  }, [statusFilter]);

  const fetchAllTrips = async () => {
    try {
      const response = await tripAPI.getAll({});
      setAllTrips(response.data);
    } catch (error) {
      console.error('獲取行程統計失敗:', error);
    }
  };

  const fetchTrips = async (overrideParams = {}) => {
    try {
      setLoading(true);
      const params = {};
      
      const currentStatus = overrideParams.status !== undefined ? overrideParams.status : statusFilter;
      const currentSearchType = overrideParams.search_type !== undefined ? overrideParams.search_type : searchType;
      const currentSearchValue = overrideParams.search_value !== undefined ? overrideParams.search_value : searchValue;
      
      if (currentStatus && currentStatus.trim() !== '') {
        params.status = currentStatus;
      }
      
      if (currentSearchType && currentSearchValue && currentSearchValue.trim() !== '') {
        params.search_type = currentSearchType;
        params.search_value = currentSearchValue;
      }
      
      console.log('發送請求參數:', params);
      const response = await tripAPI.getAll(params);
      console.log('收到行程數據:', response.data);
      setTrips(response.data);
    } catch (error) {
      console.error('獲取行程列表失敗:', error);
      alert('載入行程資料失敗');
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = () => {
    fetchTrips({
      status: statusFilter,
      search_type: searchType,
      search_value: searchValue
    });
  };

  const handleViewTrip = async (trip) => {
    setSelectedTrip(trip);
    setModalOpen(true);
  };

  const getStatusBadge = (status) => {
    const statusMap = {
      requested: { label: '已建立', class: 'badge-info' },
      matched: { label: '已配對', class: 'badge-info' },
      accepted: { label: '已接受', class: 'badge-info' },
      picked_up: { label: '已接客', class: 'badge-warning' },
      in_progress: { label: '行程中', class: 'badge-warning' },
      completed: { label: '已完成', class: 'badge-success' },
      cancelled: { label: '已取消', class: 'badge-danger' },
    };
    const statusInfo = statusMap[status] || { label: status, class: 'badge-secondary' };
    return <span className={`badge ${statusInfo.class}`}>{statusInfo.label}</span>;
  };

  const getPaymentStatusBadge = (status) => {
    const paymentMap = {
      pending: { label: '待付款', class: 'badge-warning' },
      completed: { label: '已付款', class: 'badge-success' },
      failed: { label: '付款失敗', class: 'badge-danger' },
      refunded: { label: '已退款', class: 'badge-info' },
    };
    const paymentInfo = paymentMap[status] || { label: status || '未知', class: 'badge-secondary' };
    return <span className={`badge ${paymentInfo.class}`}>{paymentInfo.label}</span>;
  };

  const getStatusCounts = () => {
    return {
      total: allTrips.length,
      ongoing: allTrips.filter(t => ['requested', 'matched', 'accepted', 'picked_up', 'in_progress'].includes(t.status)).length,
      completed: allTrips.filter(t => t.status === 'completed').length,
      cancelled: allTrips.filter(t => t.status === 'cancelled').length,
    };
  };

  const statusCounts = getStatusCounts();

  const searchTypes = [
    { value: 'trip_id', label: '行程 ID' },
    { value: 'user_id', label: '乘客 ID' },
    { value: 'owner_id', label: '車主 ID' },
    { value: 'vehicle_id', label: '車輛 ID' },
    { value: 'user_name', label: '姓名' },
    { value: 'plate_number', label: '車牌號碼' },
    { value: 'vehicle_model', label: '車輛型號' }
  ];

  const statusCards = [
    {
      title: '總行程數',
      value: statusCounts.total,
      icon: MapPin,
      gradient: 'from-blue-500 to-blue-600',
      bgColor: '#eff6ff',
    },
    {
      title: '進行中',
      value: statusCounts.ongoing,
      icon: Navigation,
      gradient: 'from-orange-500 to-orange-600',
      bgColor: '#fff7ed',
    },
    {
      title: '已完成',
      value: statusCounts.completed,
      icon: Clock,
      gradient: 'from-green-500 to-green-600',
      bgColor: '#f0fdf4',
    },
    {
      title: '已取消',
      value: statusCounts.cancelled,
      icon: X,
      gradient: 'from-red-500 to-red-600',
      bgColor: '#fef2f2',
    },
  ];

  if (loading && trips.length === 0) {
    return (
      <Layout>
        <div className="loading">
          <div className="spinner-lg" />
          <p style={{ color: '#64748b', fontSize: '1.125rem', fontWeight: '600' }}>載入行程資料中...</p>
        </div>
      </Layout>
    );
  }

  return (
    <Layout>
      <div style={{ maxWidth: '1600px', margin: '0 auto' }}>
        {/* Header */}
        <div style={{
          background: 'linear-gradient(135deg, #1e40af 0%, #3b82f6 100%)',
          borderRadius: '24px',
          padding: '2.5rem',
          marginBottom: '2rem',
          color: 'white',
          boxShadow: '0 10px 40px rgba(30, 64, 175, 0.3)'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
            <div style={{
              padding: '12px',
              background: 'rgba(255, 255, 255, 0.2)',
              borderRadius: '16px',
              backdropFilter: 'blur(10px)'
            }}>
              <MapPin size={36} />
            </div>
            <div>
              <h1 style={{ fontSize: '2.5rem', fontWeight: '900', marginBottom: '0.25rem' }}>行程詳細</h1>
              <p style={{ fontSize: '1.125rem', opacity: 0.95 }}>查看和管理所有行程資訊</p>
            </div>
          </div>
        </div>

        {/* Statistics Cards */}
        <div style={{ 
          display: 'grid', 
          gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', 
          gap: '1.5rem',
          marginBottom: '2rem'
        }}>
          {statusCards.map((stat, index) => {
            const Icon = stat.icon;
            return (
              <div 
                key={index}
                className="card"
                style={{
                  cursor: 'pointer',
                  transition: 'all 0.3s ease'
                }}
                onClick={() => {
                  if (stat.title === '總行程數') {
                    setStatusFilter('');
                  } else if (stat.title === '進行中') {
                    setStatusFilter('in_progress');
                  } else if (stat.title === '已完成') {
                    setStatusFilter('completed');
                  } else if (stat.title === '已取消') {
                    setStatusFilter('cancelled');
                  }
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.transform = 'translateY(-4px)';
                  e.currentTarget.style.boxShadow = '0 12px 24px rgba(59, 130, 246, 0.15)';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.transform = 'translateY(0)';
                  e.currentTarget.style.boxShadow = '';
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                  <div style={{
                    padding: '12px',
                    borderRadius: '12px',
                    background: stat.bgColor,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center'
                  }}>
                    <Icon size={24} style={{ filter: 'brightness(0.8)' }} />
                  </div>
                  <div style={{ flex: 1 }}>
                    <p style={{ 
                      fontSize: '0.875rem', 
                      fontWeight: '600', 
                      color: '#64748b',
                      marginBottom: '0.25rem'
                    }}>
                      {stat.title}
                    </p>
                    <p style={{ fontSize: '2rem', fontWeight: '900', color: '#0f172a', lineHeight: '1' }}>
                      {stat.value}
                    </p>
                  </div>
                </div>
              </div>
            );
          })}
        </div>

        {/* Filters & Search */}
        <div className="card" style={{ marginBottom: '2rem' }}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))', gap: '1.5rem' }}>
            {/* Status Filter */}
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
                <span>行程狀態</span>
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

            {/* Search Type */}
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
                <span>搜尋類型</span>
              </label>
              <select
                value={searchType}
                onChange={(e) => setSearchType(e.target.value)}
                className="select-field"
              >
                {searchTypes.map(type => (
                  <option key={type.value} value={type.value}>{type.label}</option>
                ))}
              </select>
            </div>

            {/* Search Input */}
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
                <span>搜尋內容</span>
              </label>
              <div style={{ display: 'flex', gap: '0.75rem' }}>
                <input
                  type="text"
                  value={searchValue}
                  onChange={(e) => setSearchValue(e.target.value)}
                  onKeyPress={(e) => e.key === 'Enter' && handleSearch()}
                  className="input-field"
                  placeholder={`輸入${searchTypes.find(t => t.value === searchType)?.label}`}
                  style={{ flex: 1 }}
                />
                <button onClick={handleSearch} className="btn btn-primary">
                  <Search size={18} />
                  搜尋
                </button>
              </div>
            </div>
          </div>
        </div>

        {/* Results Count */}
        <div style={{ 
          marginBottom: '1.5rem',
          padding: '1rem 1.5rem',
          background: 'linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%)',
          borderRadius: '16px',
          border: '2px solid #bae6fd'
        }}>
          <p style={{ fontSize: '0.9375rem', fontWeight: '700', color: '#0c4a6e' }}>
            找到 <span style={{ fontSize: '1.25rem', color: '#0284c7' }}>{trips.length}</span> 趟行程
          </p>
        </div>

        {/* Trips Table */}
        <div className="table-container">
          <table>
            <thead>
              <tr>
                <th>行程 ID</th>
                <th>乘客</th>
                <th>司機</th>
                <th>車輛</th>
                <th>距離</th>
                <th>費用</th>
                <th>支付狀態</th>
                <th>狀態</th>
                <th>出發時間</th>
                <th>操作</th>
              </tr>
            </thead>
            <tbody>
              {trips.length === 0 ? (
                <tr>
                  <td colSpan="10" style={{ textAlign: 'center', padding: '3rem', color: '#94a3b8' }}>
                    <AlertCircle size={48} style={{ margin: '0 auto 1rem', opacity: 0.5 }} />
                    <p style={{ fontSize: '1.125rem', fontWeight: '600' }}>暫無行程資料</p>
                  </td>
                </tr>
              ) : (
                trips.map((trip) => (
                  <tr key={trip.trip_id}>
                    <td style={{ fontWeight: '700', color: '#1e40af' }}>#{trip.trip_id}</td>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                        <User size={16} color="#64748b" />
                        <span style={{ fontWeight: '600' }}>{trip.rider_name || `User ${trip.user_id}`}</span>
                      </div>
                    </td>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                        <User size={16} color="#64748b" />
                        <span style={{ fontWeight: '600' }}>{trip.driver_name || '未分配'}</span>
                      </div>
                    </td>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                        <Car size={16} color="#64748b" />
                        <span style={{ fontWeight: '600' }}>{trip.plate_number || '未分配'}</span>
                      </div>
                    </td>
                    <td style={{ fontWeight: '600' }}>
                      {trip.distance_km ? `${Number(trip.distance_km).toFixed(2)} km` : '-'}
                    </td>
                    <td style={{ fontWeight: '700', color: '#0f172a' }}>
                      {trip.total_amount != null
                        ? `${Number(trip.total_amount).toFixed(2)} SUI`
                        : trip.fare != null
                        ? `${Number(trip.fare).toFixed(2)} SUI`
                        : '-'}
                    </td>
                    <td>{getPaymentStatusBadge(trip.payment_status)}</td>
                    <td>{getStatusBadge(trip.status)}</td>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', fontSize: '0.875rem' }}>
                        <Calendar size={16} color="#64748b" />
                        <span>{trip.requested_at ? new Date(trip.requested_at).toLocaleString('zh-TW') : '-'}</span>
                      </div>
                    </td>
                    <td>
                      <button
                        onClick={() => handleViewTrip(trip)}
                        className="btn btn-primary"
                        style={{ padding: '0.5rem 1rem', fontSize: '0.875rem' }}
                      >
                        <Eye size={16} />
                        查看
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Trip Detail Modal */}
      {modalOpen && selectedTrip && (
        <div className="modal-overlay" onClick={() => setModalOpen(false)}>
          <div className="modal-content" style={{ maxWidth: '900px' }} onClick={(e) => e.stopPropagation()}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start', marginBottom: '2rem' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                <div style={{
                  width: '80px',
                  height: '80px',
                  borderRadius: '20px',
                  background: 'linear-gradient(135deg, #3b82f6 0%, #1e40af 100%)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: '2.25rem',
                  fontWeight: '900',
                  color: 'white',
                  boxShadow: '0 8px 24px rgba(59, 130, 246, 0.4)'
                }}>
                  <MapPin size={48} />
                </div>
                <div>
                  <h2 style={{ fontSize: '2rem', fontWeight: '900', color: '#0f172a', marginBottom: '0.5rem' }}>
                    行程 #{selectedTrip.trip_id}
                  </h2>
                  {getStatusBadge(selectedTrip.status)}
                </div>
              </div>
              <button
                onClick={() => setModalOpen(false)}
                style={{
                  padding: '0.75rem',
                  background: '#f1f5f9',
                  border: 'none',
                  borderRadius: '12px',
                  cursor: 'pointer',
                  transition: 'all 0.2s'
                }}
                onMouseEnter={(e) => e.currentTarget.style.background = '#e2e8f0'}
                onMouseLeave={(e) => e.currentTarget.style.background = '#f1f5f9'}
              >
                <X size={24} color="#64748b" />
              </button>
            </div>

            {/* Trip Info Grid */}
            <div style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
              gap: '1.5rem',
              marginBottom: '2rem'
            }}>
              <div style={{ padding: '1.25rem', background: '#f8fafc', borderRadius: '16px', border: '2px solid #e2e8f0' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '0.75rem' }}>
                  <User size={20} color="#3b82f6" />
                  <span style={{ fontSize: '0.875rem', fontWeight: '700', color: '#64748b' }}>乘客</span>
                </div>
                <p style={{ fontSize: '1.125rem', fontWeight: '800', color: '#0f172a', marginBottom: '0.25rem' }}>
                  {selectedTrip.rider_name || '未知'}
                </p>
                <p style={{ fontSize: '0.875rem', color: '#64748b' }}>
                  ID: {selectedTrip.user_id}
                </p>
                {selectedTrip.rider_phone && (
                  <p style={{ fontSize: '0.875rem', color: '#64748b' }}>
                    {selectedTrip.rider_phone}
                  </p>
                )}
              </div>

              <div style={{ padding: '1.25rem', background: '#f8fafc', borderRadius: '16px', border: '2px solid #e2e8f0' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '0.75rem' }}>
                  <User size={20} color="#10b981" />
                  <span style={{ fontSize: '0.875rem', fontWeight: '700', color: '#64748b' }}>司機</span>
                </div>
                <p style={{ fontSize: '1.125rem', fontWeight: '800', color: '#0f172a', marginBottom: '0.25rem' }}>
                  {selectedTrip.driver_name || '未分配'}
                </p>
                {selectedTrip.driver_phone && (
                  <p style={{ fontSize: '0.875rem', color: '#64748b' }}>
                    {selectedTrip.driver_phone}
                  </p>
                )}
              </div>

              <div style={{ padding: '1.25rem', background: '#f8fafc', borderRadius: '16px', border: '2px solid #e2e8f0' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '0.75rem' }}>
                  <Car size={20} color="#f59e0b" />
                  <span style={{ fontSize: '0.875rem', fontWeight: '700', color: '#64748b' }}>車輛</span>
                </div>
                <p style={{ fontSize: '1.125rem', fontWeight: '800', color: '#0f172a', marginBottom: '0.25rem' }}>
                  {selectedTrip.plate_number || '未分配'}
                </p>
                <p style={{ fontSize: '0.875rem', color: '#64748b' }}>
                  {selectedTrip.vehicle_model || '未知型號'}
                </p>
              </div>
            </div>

            {/* Location Info */}
            {(selectedTrip.pickup_lat && selectedTrip.pickup_lng) && (
              <div style={{ 
                padding: '1.5rem', 
                background: 'linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%)', 
                borderRadius: '16px',
                border: '2px solid #bae6fd',
                marginBottom: '2rem'
              }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start', marginBottom: '1rem' }}>
                  <div style={{ flex: 1 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '1rem' }}>
                      <MapPin size={24} color="#0284c7" />
                      <span style={{ fontSize: '1rem', fontWeight: '800', color: '#0c4a6e' }}>起點位置</span>
                    </div>
                    <p style={{ fontSize: '0.875rem', fontWeight: '600', color: '#0c4a6e' }}>
                      {selectedTrip.pickup_address || `緯度: ${selectedTrip.pickup_lat}, 經度: ${selectedTrip.pickup_lng}`}
                    </p>
                  </div>
                  <button
                    onClick={() => {
                      const url = `https://www.google.com/maps/search/?api=1&query=${selectedTrip.pickup_lat},${selectedTrip.pickup_lng}`;
                      window.open(url, '_blank');
                    }}
                    className="btn btn-primary"
                    style={{ 
                      display: 'flex',
                      alignItems: 'center',
                      gap: '0.5rem',
                      whiteSpace: 'nowrap',
                      fontSize: '0.875rem',
                      padding: '0.5rem 1rem'
                    }}
                  >
                    <MapPin size={16} />
                    起點
                  </button>
                </div>

                {(selectedTrip.dropoff_lat && selectedTrip.dropoff_lng) && (
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start', paddingTop: '1rem', borderTop: '2px solid #bae6fd' }}>
                    <div style={{ flex: 1 }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '1rem' }}>
                        <MapPin size={24} color="#0284c7" />
                        <span style={{ fontSize: '1rem', fontWeight: '800', color: '#0c4a6e' }}>終點位置</span>
                      </div>
                      <p style={{ fontSize: '0.875rem', fontWeight: '600', color: '#0c4a6e' }}>
                        {selectedTrip.dropoff_address || `緯度: ${selectedTrip.dropoff_lat}, 經度: ${selectedTrip.dropoff_lng}`}
                      </p>
                    </div>
                    <button
                      onClick={() => {
                        const url = `https://www.google.com/maps/search/?api=1&query=${selectedTrip.dropoff_lat},${selectedTrip.dropoff_lng}`;
                        window.open(url, '_blank');
                      }}
                      className="btn btn-primary"
                      style={{ 
                        display: 'flex',
                        alignItems: 'center',
                        gap: '0.5rem',
                        whiteSpace: 'nowrap',
                        fontSize: '0.875rem',
                        padding: '0.5rem 1rem'
                      }}
                    >
                      <MapPin size={16} />
                      終點
                    </button>
                  </div>
                )}
              </div>
            )}

            {/* Trip Details */}
            <div style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))',
              gap: '1.5rem',
              marginBottom: '2rem'
            }}>
              <div style={{ padding: '1.25rem', background: '#f8fafc', borderRadius: '16px', border: '2px solid #e2e8f0' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '0.75rem' }}>
                  <Navigation size={20} color="#3b82f6" />
                  <span style={{ fontSize: '0.875rem', fontWeight: '700', color: '#64748b' }}>距離</span>
                </div>
                <p style={{ fontSize: '1.5rem', fontWeight: '900', color: '#0f172a' }}>
                  {selectedTrip.distance_km ? `${selectedTrip.distance_km} km` : '未知'}
                </p>
              </div>

              <div style={{ padding: '1.25rem', background: '#f8fafc', borderRadius: '16px', border: '2px solid #e2e8f0' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '0.75rem' }}>
                  <DollarSign size={20} color="#10b981" />
                  <span style={{ fontSize: '0.875rem', fontWeight: '700', color: '#64748b' }}>費用</span>
                </div>
                <p style={{ fontSize: '1.5rem', fontWeight: '900', color: '#0f172a' }}>
                  {selectedTrip.total_amount != null
                    ? `${Number(selectedTrip.total_amount).toFixed(2)} SUI`
                    : selectedTrip.fare != null
                    ? `${Number(selectedTrip.fare).toFixed(2)} SUI`
                    : '未知'}
                </p>
              </div>

              <div style={{ padding: '1.25rem', background: '#f8fafc', borderRadius: '16px', border: '2px solid #e2e8f0' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '0.75rem' }}>
                  <DollarSign size={20} color="#f59e0b" />
                  <span style={{ fontSize: '0.875rem', fontWeight: '700', color: '#64748b' }}>支付狀態</span>
                </div>
                <div style={{ marginTop: '0.5rem' }}>
                  {getPaymentStatusBadge(selectedTrip.payment_status)}
                </div>
              </div>
            </div>

            {/* Time Info */}
            <div style={{
              padding: '1.5rem',
              background: '#f8fafc',
              borderRadius: '16px',
              border: '2px solid #e2e8f0'
            }}>
              <h3 style={{ fontSize: '1.25rem', fontWeight: '900', color: '#0f172a', marginBottom: '1rem' }}>
                時間資訊
              </h3>
              <div style={{ display: 'grid', gap: '0.75rem' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ fontSize: '0.875rem', fontWeight: '600', color: '#64748b' }}>請求時間：</span>
                  <span style={{ fontSize: '0.9375rem', fontWeight: '700', color: '#0f172a' }}>
                    {new Date(selectedTrip.requested_at).toLocaleString('zh-TW')}
                  </span>
                </div>
                {selectedTrip.picked_up_at && (
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ fontSize: '0.875rem', fontWeight: '600', color: '#64748b' }}>接客時間：</span>
                    <span style={{ fontSize: '0.9375rem', fontWeight: '700', color: '#0f172a' }}>
                      {new Date(selectedTrip.picked_up_at).toLocaleString('zh-TW')}
                    </span>
                  </div>
                )}
                {selectedTrip.dropped_off_at && (
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ fontSize: '0.875rem', fontWeight: '600', color: '#64748b' }}>完成時間：</span>
                    <span style={{ fontSize: '0.9375rem', fontWeight: '700', color: '#0f172a' }}>
                      {new Date(selectedTrip.dropped_off_at).toLocaleString('zh-TW')}
                    </span>
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      )}
    </Layout>
  );
};

export default TripDetails;
