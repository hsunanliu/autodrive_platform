import React, { useState, useEffect } from 'react';
import Layout from '../components/Layout';
import { vehicleAPI } from '../services/api';
import { Car, Search, Battery, MapPin, User, Calendar, AlertCircle, Eye, X, Edit, Activity, Zap } from 'lucide-react';

const VehicleManagement = () => {
  const [vehicles, setVehicles] = useState([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState('');
  const [searchType, setSearchType] = useState('plate_number');
  const [searchValue, setSearchValue] = useState('');
  const [selectedVehicle, setSelectedVehicle] = useState(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [editStatusMode, setEditStatusMode] = useState(false);
  const [newStatus, setNewStatus] = useState('');
  const [allVehicles, setAllVehicles] = useState([]); // 用於統計

  useEffect(() => {
    fetchAllVehicles(); // 獲取所有車輛用於統計
    fetchVehicles();
  }, [statusFilter]);

  const fetchAllVehicles = async () => {
    try {
      const response = await vehicleAPI.getAll({});
      setAllVehicles(response.data);
    } catch (error) {
      console.error('獲取車輛統計失敗:', error);
    }
  };

  const fetchVehicles = async () => {
    try {
      setLoading(true);
      const params = { status: statusFilter };
      const response = await vehicleAPI.getAll(params);
      setVehicles(response.data);
    } catch (error) {
      console.error('獲取車輛列表失敗:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = async () => {
    if (!searchValue.trim()) {
      fetchVehicles();
      return;
    }

    try {
      setLoading(true);
      const params = {
        status: statusFilter,
        search_type: searchType,
        search_value: searchValue
      };
      const response = await vehicleAPI.getAll(params);
      setVehicles(response.data);
    } catch (error) {
      console.error('搜尋失敗:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleViewVehicle = async (vehicle) => {
    setSelectedVehicle(vehicle);
    setNewStatus(vehicle.status);
    setModalOpen(true);
    setEditStatusMode(false);
  };

  const handleUpdateStatus = async () => {
    try {
      await vehicleAPI.updateStatus(selectedVehicle.vehicle_id, newStatus);
      setModalOpen(false);
      setEditStatusMode(false);
      fetchAllVehicles(); // 重新獲取統計
      fetchVehicles();
      alert('車輛狀態已更新！');
    } catch (error) {
      console.error('更新狀態失敗:', error);
      alert('更新失敗，請稍後再試');
    }
  };

  const getStatusBadge = (status) => {
    const statusMap = {
      available: { label: '可用', class: 'badge-success' },
      on_trip: { label: '行程中', class: 'badge-info' },
      maintenance: { label: '維護中', class: 'badge-warning' },
      offline: { label: '離線', class: 'badge-secondary' },
    };
    const statusInfo = statusMap[status] || { label: status, class: 'badge-secondary' };
    return <span className={`badge ${statusInfo.class}`}>{statusInfo.label}</span>;
  };

  const getBatteryColor = (percent) => {
    if (!percent) return '#94a3b8';
    if (percent >= 80) return '#10b981';
    if (percent >= 50) return '#f59e0b';
    if (percent >= 20) return '#f97316';
    return '#ef4444';
  };

  // 計算各狀態的車輛數量
  const getStatusCounts = () => {
    return {
      total: allVehicles.length,
      available: allVehicles.filter(v => v.status === 'available').length,
      on_trip: allVehicles.filter(v => v.status === 'on_trip').length,
      maintenance: allVehicles.filter(v => v.status === 'maintenance').length,
      offline: allVehicles.filter(v => v.status === 'offline').length,
    };
  };

  const statusCounts = getStatusCounts();

  const searchTypes = [
    { value: 'plate_number', label: '車牌號碼' },
    { value: 'model', label: '車輛型號' },
    { value: 'owner_name', label: '車主名稱' },
    { value: 'owner_id', label: '車主 ID' }
  ];

  const statusCards = [
    {
      title: '總車輛數',
      value: statusCounts.total,
      icon: Car,
      gradient: 'from-blue-500 to-blue-600',
      bgColor: '#eff6ff',
    },
    {
      title: '可用',
      value: statusCounts.available,
      icon: Activity,
      gradient: 'from-green-500 to-green-600',
      bgColor: '#f0fdf4',
    },
    {
      title: '行程中',
      value: statusCounts.on_trip,
      icon: Car,
      gradient: 'from-cyan-500 to-cyan-600',
      bgColor: '#ecfeff',
    },
    {
      title: '維護中',
      value: statusCounts.maintenance,
      icon: Zap,
      gradient: 'from-yellow-500 to-yellow-600',
      bgColor: '#fefce8',
    },
    {
      title: '離線',
      value: statusCounts.offline,
      icon: AlertCircle,
      gradient: 'from-gray-500 to-gray-600',
      bgColor: '#f9fafb',
    },
  ];

  if (loading && vehicles.length === 0) {
    return (
      <Layout>
        <div className="loading">
          <div className="spinner-lg" />
          <p style={{ color: '#64748b', fontSize: '1.125rem', fontWeight: '600' }}>載入車輛資料中...</p>
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
              <Car size={36} />
            </div>
            <div>
              <h1 style={{ fontSize: '2.5rem', fontWeight: '900', marginBottom: '0.25rem' }}>車輛管理</h1>
              <p style={{ fontSize: '1.125rem', opacity: 0.95 }}>管理平台所有車輛資料</p>
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
                  if (stat.title === '總車輛數') {
                    setStatusFilter('');
                  } else if (stat.title === '可用') {
                    setStatusFilter('available');
                  } else if (stat.title === '行程中') {
                    setStatusFilter('on_trip');
                  } else if (stat.title === '維護中') {
                    setStatusFilter('maintenance');
                  } else if (stat.title === '離線') {
                    setStatusFilter('offline');
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
                    <Icon size={24} color={`linear-gradient(135deg, ${stat.gradient})`} style={{
                      filter: 'brightness(0.8)'
                    }} />
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
                <Car size={18} />
                <span>車輛狀態</span>
              </label>
              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                className="select-field"
              >
                <option value="">全部狀態</option>
                <option value="available">可用</option>
                <option value="on_trip">行程中</option>
                <option value="maintenance">維護中</option>
                <option value="offline">離線</option>
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
            找到 <span style={{ fontSize: '1.25rem', color: '#0284c7' }}>{vehicles.length}</span> 輛車輛
          </p>
        </div>

        {/* Vehicles Table */}
        <div className="table-container">
          <table>
            <thead>
              <tr>
                <th>車輛 ID</th>
                <th>車牌號碼</th>
                <th>型號</th>
                <th>車主</th>
                <th>電池狀態</th>
                <th>當前電量</th>
                <th>狀態</th>
                <th>更新時間</th>
                <th>操作</th>
              </tr>
            </thead>
            <tbody>
              {vehicles.length === 0 ? (
                <tr>
                  <td colSpan="9" style={{ textAlign: 'center', padding: '3rem', color: '#94a3b8' }}>
                    <AlertCircle size={48} style={{ margin: '0 auto 1rem', opacity: 0.5 }} />
                    <p style={{ fontSize: '1.125rem', fontWeight: '600' }}>暫無車輛資料</p>
                  </td>
                </tr>
              ) : (
                vehicles.map((vehicle) => (
                  <tr key={vehicle.vehicle_id}>
                    <td style={{ fontWeight: '700', color: '#1e40af' }}>#{vehicle.vehicle_id}</td>
                    <td>
                      <div style={{
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: '0.5rem',
                        padding: '0.5rem 1rem',
                        background: 'linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%)',
                        borderRadius: '10px'
                      }}>
                        <Car size={18} color="#1e40af" />
                        <span style={{ fontWeight: '800', color: '#1e40af', fontSize: '1rem' }}>
                          {vehicle.plate_number}
                        </span>
                      </div>
                    </td>
                    <td style={{ fontWeight: '600', color: '#0f172a' }}>
                      {vehicle.model || '未知型號'}
                    </td>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                        <User size={16} color="#64748b" />
                        <span style={{ fontWeight: '600' }}>
                          {vehicle.owner_name || `Owner ${vehicle.owner_id}`}
                        </span>
                      </div>
                    </td>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                        <Battery size={20} color={getBatteryColor(vehicle.battery_capacity_kWh)} />
                        <span style={{ fontWeight: '600' }}>
                          {vehicle.battery_capacity_kWh ? `${vehicle.battery_capacity_kWh} kWh` : '未設定'}
                        </span>
                      </div>
                    </td>
                    <td>
                      {vehicle.current_charge_percent ? (
                        <div style={{ 
                          display: 'flex', 
                          alignItems: 'center', 
                          gap: '0.75rem'
                        }}>
                          <div style={{
                            width: '100px',
                            height: '8px',
                            background: '#e2e8f0',
                            borderRadius: '4px',
                            overflow: 'hidden'
                          }}>
                            <div style={{
                              width: `${vehicle.current_charge_percent}%`,
                              height: '100%',
                              background: getBatteryColor(vehicle.current_charge_percent),
                              transition: 'width 0.3s'
                            }}></div>
                          </div>
                          <span style={{ 
                            fontWeight: '700',
                            color: getBatteryColor(vehicle.current_charge_percent)
                          }}>
                            {vehicle.current_charge_percent}%
                          </span>
                        </div>
                      ) : (
                        <span style={{ color: '#94a3b8' }}>未知</span>
                      )}
                    </td>
                    <td>{getStatusBadge(vehicle.status)}</td>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', fontSize: '0.875rem' }}>
                        <Calendar size={16} color="#64748b" />
                        <span>{new Date(vehicle.updated_at).toLocaleString('zh-TW')}</span>
                      </div>
                    </td>
                    <td>
                      <button
                        onClick={() => handleViewVehicle(vehicle)}
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

      {/* Vehicle Detail Modal */}
      {modalOpen && selectedVehicle && (
        <div className="modal-overlay" onClick={() => setModalOpen(false)}>
          <div className="modal-content" style={{ maxWidth: '800px' }} onClick={(e) => e.stopPropagation()}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start', marginBottom: '2rem' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                <div style={{
                  width: '80px',
                  height: '80px',
                  borderRadius: '20px',
                  background: 'linear-gradient(135deg, #10b981 0%, #059669 100%)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: '2.25rem',
                  fontWeight: '900',
                  color: 'white',
                  boxShadow: '0 8px 24px rgba(16, 185, 129, 0.4)'
                }}>
                  <Car size={48} />
                </div>
                <div>
                  <h2 style={{ fontSize: '2rem', fontWeight: '900', color: '#0f172a', marginBottom: '0.5rem' }}>
                    {selectedVehicle.plate_number}
                  </h2>
                  <p style={{ fontSize: '1.125rem', color: '#64748b', fontWeight: '600' }}>
                    {selectedVehicle.model || '未知型號'}
                  </p>
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

            {/* Vehicle Info Grid */}
            <div style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
              gap: '1.5rem',
              marginBottom: '2rem'
            }}>
              <div style={{ padding: '1.25rem', background: '#f8fafc', borderRadius: '16px', border: '2px solid #e2e8f0' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '0.75rem' }}>
                  <User size={20} color="#3b82f6" />
                  <span style={{ fontSize: '0.875rem', fontWeight: '700', color: '#64748b' }}>車主</span>
                </div>
                <p style={{ fontSize: '1.125rem', fontWeight: '800', color: '#0f172a', marginBottom: '0.25rem' }}>
                  {selectedVehicle.owner_name || '未知'}
                </p>
                <p style={{ fontSize: '0.875rem', color: '#64748b' }}>
                  ID: {selectedVehicle.owner_id}
                </p>
              </div>

              <div style={{ padding: '1.25rem', background: '#f8fafc', borderRadius: '16px', border: '2px solid #e2e8f0' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '0.75rem' }}>
                  <Battery size={20} color="#10b981" />
                  <span style={{ fontSize: '0.875rem', fontWeight: '700', color: '#64748b' }}>電池容量</span>
                </div>
                <p style={{ fontSize: '1.5rem', fontWeight: '900', color: '#0f172a' }}>
                  {selectedVehicle.battery_capacity_kWh ? `${selectedVehicle.battery_capacity_kWh} kWh` : '未設定'}
                </p>
              </div>

              <div style={{ padding: '1.25rem', background: '#f8fafc', borderRadius: '16px', border: '2px solid #e2e8f0' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '0.75rem' }}>
                  <Battery size={20} color={getBatteryColor(selectedVehicle.current_charge_percent)} />
                  <span style={{ fontSize: '0.875rem', fontWeight: '700', color: '#64748b' }}>當前電量</span>
                </div>
                {selectedVehicle.current_charge_percent ? (
                  <>
                    <p style={{ fontSize: '1.5rem', fontWeight: '900', color: getBatteryColor(selectedVehicle.current_charge_percent), marginBottom: '0.5rem' }}>
                      {selectedVehicle.current_charge_percent}%
                    </p>
                    <div style={{
                      width: '100%',
                      height: '10px',
                      background: '#e2e8f0',
                      borderRadius: '5px',
                      overflow: 'hidden'
                    }}>
                      <div style={{
                        width: `${selectedVehicle.current_charge_percent}%`,
                        height: '100%',
                        background: getBatteryColor(selectedVehicle.current_charge_percent),
                        transition: 'width 0.3s'
                      }}></div>
                    </div>
                  </>
                ) : (
                  <p style={{ fontSize: '1.125rem', fontWeight: '600', color: '#94a3b8' }}>未知</p>
                )}
              </div>
            </div>

            {/* Location Info - 版本B (只有按鈕) */}
            {(selectedVehicle.location_lat && selectedVehicle.location_lng) ? (
              <div style={{ 
                padding: '1.5rem', 
                background: 'linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%)', 
                borderRadius: '16px',
                border: '2px solid #bae6fd',
                marginBottom: '2rem'
              }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div style={{ flex: 1 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '0.75rem' }}>
                      <MapPin size={24} color="#0284c7" />
                      <span style={{ fontSize: '1rem', fontWeight: '800', color: '#0c4a6e' }}>當前位置</span>
                    </div>
                    <p style={{ fontSize: '1rem', fontWeight: '600', color: '#0c4a6e' }}>
                      緯度: {selectedVehicle.location_lat}, 經度: {selectedVehicle.location_lng}
                    </p>
                  </div>
                  <button
                    onClick={() => {
                      const lat = selectedVehicle.location_lat;
                      const lng = selectedVehicle.location_lng;
                      const url = `https://www.google.com/maps/search/?api=1&query=${lat},${lng}`;
                      window.open(url, '_blank');
                    }}
                    className="btn btn-primary"
                    style={{ 
                      display: 'flex',
                      alignItems: 'center',
                      gap: '0.5rem',
                      whiteSpace: 'nowrap'
                    }}
                  >
                    <MapPin size={18} />
                    在地圖上查看
                  </button>
                </div>
              </div>
            ) : (
              <div style={{ 
                padding: '1.5rem', 
                background: '#f8fafc',
                borderRadius: '16px',
                border: '2px dashed #cbd5e1',
                marginBottom: '2rem',
                textAlign: 'center'
              }}>
                <MapPin size={48} color="#cbd5e1" style={{ margin: '0 auto 0.5rem' }} />
                <p style={{ fontSize: '1rem', fontWeight: '600', color: '#64748b' }}>
                  位置資訊未設定
                </p>
              </div>
            )}

            {/* Status Management */}
            <div style={{
              padding: '1.5rem',
              background: '#f8fafc',
              borderRadius: '16px',
              border: '2px solid #e2e8f0'
            }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
                <h3 style={{ fontSize: '1.25rem', fontWeight: '900', color: '#0f172a' }}>
                  車輛狀態管理
                </h3>
                {!editStatusMode ? (
                  <button
                    onClick={() => setEditStatusMode(true)}
                    className="btn btn-primary"
                    style={{ padding: '0.5rem 1rem', fontSize: '0.875rem' }}
                  >
                    <Edit size={16} />
                    編輯狀態
                  </button>
                ) : null}
              </div>

              {!editStatusMode ? (
                <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                  <span style={{ fontSize: '1rem', fontWeight: '600', color: '#64748b' }}>當前狀態：</span>
                  {getStatusBadge(selectedVehicle.status)}
                </div>
              ) : (
                <div>
                  <label style={{ 
                    display: 'block',
                    fontSize: '0.875rem', 
                    fontWeight: '700', 
                    color: '#334155', 
                    marginBottom: '0.5rem' 
                  }}>
                    選擇新狀態
                  </label>
                  <select
                    value={newStatus}
                    onChange={(e) => setNewStatus(e.target.value)}
                    className="select-field"
                    style={{ marginBottom: '1rem' }}
                  >
                    <option value="available">可用</option>
                    <option value="on_trip">行程中</option>
                    <option value="maintenance">維護中</option>
                    <option value="offline">離線</option>
                  </select>
                  <div style={{ display: 'flex', gap: '1rem' }}>
                    <button
                      onClick={handleUpdateStatus}
                      className="btn btn-success"
                      style={{ flex: 1 }}
                    >
                      確認更新
                    </button>
                    <button
                      onClick={() => {
                        setEditStatusMode(false);
                        setNewStatus(selectedVehicle.status);
                      }}
                      className="btn btn-secondary"
                      style={{ flex: 1 }}
                    >
                      取消
                    </button>
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </Layout>
  );
};

export default VehicleManagement;
