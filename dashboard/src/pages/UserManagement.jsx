import React, { useState, useEffect } from 'react';
import Layout from '../components/Layout';
import { userAPI } from '../services/api';
import { Users, Car, Search, Mail, Phone, Calendar, AlertCircle, X, Eye, MapPin, DollarSign } from 'lucide-react';

const UserManagement = () => {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [typeFilter, setTypeFilter] = useState('');
  const [searchValue, setSearchValue] = useState('');
  const [selectedUser, setSelectedUser] = useState(null);
  const [userVehicles, setUserVehicles] = useState([]);
  const [userTrips, setUserTrips] = useState([]);
  const [modalOpen, setModalOpen] = useState(false);
  const [dataLoading, setDataLoading] = useState(false);

  useEffect(() => {
    fetchUsers();
  }, [typeFilter]);

  const fetchUsers = async () => {
    try {
      setLoading(true);
      const response = await userAPI.getAll(typeFilter);
      setUsers(response.data);
    } catch (error) {
      console.error('獲取用戶列表失敗:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = () => {
    fetchUsers();
  };

  const handleViewUser = async (user) => {
    setSelectedUser(user);
    setModalOpen(true);
    
    if (user.user_type === 'driver') {
      // 獲取車主的車輛
      setDataLoading(true);
      try {
        const response = await userAPI.getVehicles(user.id);
        setUserVehicles(response.data);
        setUserTrips([]);
      } catch (error) {
        console.error('獲取車輛失敗:', error);
        setUserVehicles([]);
      } finally {
        setDataLoading(false);
      }
    } else if (user.user_type === 'rider') {
      // 獲取乘客的行程
      setDataLoading(true);
      try {
        const response = await userAPI.getTrips(user.id);
        setUserTrips(response.data);
        setUserVehicles([]);
      } catch (error) {
        console.error('獲取行程失敗:', error);
        setUserTrips([]);
      } finally {
        setDataLoading(false);
      }
    }
  };

  const getUserTypeBadge = (userType) => {
    if (userType === 'rider') {
      return <span className="badge badge-info">乘客</span>;
    } else if (userType === 'driver') {
      return <span className="badge badge-success">車主</span>;
    }
  };

  const getVehicleStatusBadge = (status) => {
    const statusMap = {
      available: { label: '可用', class: 'badge-success' },
      on_trip: { label: '行程中', class: 'badge-info' },
      maintenance: { label: '維護中', class: 'badge-warning' },
      offline: { label: '離線', class: 'badge-secondary' },
    };
    const statusInfo = statusMap[status] || { label: status, class: 'badge-secondary' };
    return <span className={`badge ${statusInfo.class}`}>{statusInfo.label}</span>;
  };

  const getTripStatusBadge = (status) => {
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

  const filteredUsers = searchValue
    ? users.filter(user =>
        user.name?.toLowerCase().includes(searchValue.toLowerCase()) ||
        user.email?.toLowerCase().includes(searchValue.toLowerCase()) ||
        user.id?.toString().includes(searchValue) ||
        user.phone?.includes(searchValue)
      )
    : users;

  if (loading) {
    return (
      <Layout>
        <div className="loading">
          <div className="spinner-lg" />
          <p style={{ color: '#64748b', fontSize: '1.125rem', fontWeight: '600' }}>載入用戶資料中...</p>
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
              <Users size={36} />
            </div>
            <div>
              <h1 style={{ fontSize: '2.5rem', fontWeight: '900', marginBottom: '0.25rem' }}>用戶管理</h1>
              <p style={{ fontSize: '1.125rem', opacity: 0.95 }}>管理平台所有用戶資料</p>
            </div>
          </div>
        </div>

        {/* Filters & Search */}
        <div className="card" style={{ marginBottom: '2rem' }}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '1.5rem' }}>
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
                <Users size={18} />
                <span>用戶類型</span>
              </label>
              <select
                value={typeFilter}
                onChange={(e) => setTypeFilter(e.target.value)}
                className="select-field"
              >
                <option value="">全部用戶</option>
                <option value="rider">乘客</option>
                <option value="driver">車主</option>
              </select>
            </div>

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
                <span>搜尋用戶</span>
              </label>
              <div style={{ display: 'flex', gap: '0.75rem' }}>
                <input
                  type="text"
                  value={searchValue}
                  onChange={(e) => setSearchValue(e.target.value)}
                  onKeyPress={(e) => e.key === 'Enter' && handleSearch()}
                  className="input-field"
                  placeholder="輸入姓名、Email、電話或 ID"
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
            找到 <span style={{ fontSize: '1.25rem', color: '#0284c7' }}>{filteredUsers.length}</span> 位用戶
          </p>
        </div>

        {/* Users Table */}
        <div className="table-container">
          <table>
            <thead>
              <tr>
                <th>用戶 ID</th>
                <th>姓名</th>
                <th>類型</th>
                <th>Email</th>
                <th>電話</th>
                <th>統計</th>
                <th>註冊日期</th>
                <th>操作</th>
              </tr>
            </thead>
            <tbody>
              {filteredUsers.length === 0 ? (
                <tr>
                  <td colSpan="8" style={{ textAlign: 'center', padding: '3rem', color: '#94a3b8' }}>
                    <AlertCircle size={48} style={{ margin: '0 auto 1rem', opacity: 0.5 }} />
                    <p style={{ fontSize: '1.125rem', fontWeight: '600' }}>暫無用戶資料</p>
                  </td>
                </tr>
              ) : (
                filteredUsers.map((user) => (
                  <tr key={`${user.user_type}-${user.id}`}>
                    <td style={{ fontWeight: '700', color: '#1e40af' }}>#{user.id}</td>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                        <div style={{
                          width: '40px',
                          height: '40px',
                          borderRadius: '10px',
                          background: user.user_type === 'driver' 
                            ? 'linear-gradient(135deg, #10b981 0%, #059669 100%)'
                            : 'linear-gradient(135deg, #3b82f6 0%, #1e40af 100%)',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          fontSize: '1.125rem',
                          fontWeight: '900',
                          color: 'white',
                          flexShrink: 0
                        }}>
                          {user.name?.charAt(0) || 'U'}
                        </div>
                        <span style={{ fontWeight: '600', color: '#0f172a' }}>{user.name || '未命名'}</span>
                      </div>
                    </td>
                    <td>{getUserTypeBadge(user.user_type)}</td>
                    <td style={{ maxWidth: '250px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                        <Mail size={16} color="#64748b" />
                        <span style={{ 
                          overflow: 'hidden',
                          textOverflow: 'ellipsis',
                          whiteSpace: 'nowrap'
                        }}>
                          {user.email || '無'}
                        </span>
                      </div>
                    </td>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                        <Phone size={16} color="#64748b" />
                        <span>{user.phone || '無'}</span>
                      </div>
                    </td>
                    <td>
                      {user.user_type === 'rider' ? (
                        <div style={{
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: '0.5rem',
                          padding: '0.375rem 0.75rem',
                          background: 'linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%)',
                          borderRadius: '8px'
                        }}>
                          <MapPin size={16} color="#1e40af" />
                          <span style={{ fontWeight: '700', color: '#1e40af' }}>
                            {user.trip_count || 0} 趟行程
                          </span>
                        </div>
                      ) : (
                        <div style={{
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: '0.5rem',
                          padding: '0.375rem 0.75rem',
                          background: 'linear-gradient(135deg, #d1fae5 0%, #a7f3d0 100%)',
                          borderRadius: '8px'
                        }}>
                          <Car size={16} color="#065f46" />
                          <span style={{ fontWeight: '700', color: '#065f46' }}>
                            {user.vehicle_count || 0} 輛車
                          </span>
                        </div>
                      )}
                    </td>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', fontSize: '0.875rem' }}>
                        <Calendar size={16} color="#64748b" />
                        <span>{new Date(user.created_at).toLocaleDateString('zh-TW')}</span>
                      </div>
                    </td>
                    <td>
                      <button
                        onClick={() => handleViewUser(user)}
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

      {/* User Detail Modal */}
      {modalOpen && selectedUser && (
        <div className="modal-overlay" onClick={() => setModalOpen(false)}>
          <div className="modal-content" style={{ maxWidth: '1000px' }} onClick={(e) => e.stopPropagation()}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start', marginBottom: '2rem' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                <div style={{
                  width: '80px',
                  height: '80px',
                  borderRadius: '20px',
                  background: selectedUser.user_type === 'driver'
                    ? 'linear-gradient(135deg, #10b981 0%, #059669 100%)'
                    : 'linear-gradient(135deg, #3b82f6 0%, #1e40af 100%)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: '2.25rem',
                  fontWeight: '900',
                  color: 'white',
                  boxShadow: '0 8px 24px rgba(59, 130, 246, 0.4)'
                }}>
                  {selectedUser.name?.charAt(0) || 'U'}
                </div>
                <div>
                  <h2 style={{ fontSize: '2rem', fontWeight: '900', color: '#0f172a', marginBottom: '0.5rem' }}>
                    {selectedUser.name || '未命名用戶'}
                  </h2>
                  {getUserTypeBadge(selectedUser.user_type)}
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

            {/* User Info */}
            <div style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))',
              gap: '1.5rem',
              marginBottom: '2rem'
            }}>
              <div style={{ padding: '1.25rem', background: '#f8fafc', borderRadius: '16px', border: '2px solid #e2e8f0' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '0.75rem' }}>
                  <Mail size={20} color="#3b82f6" />
                  <span style={{ fontSize: '0.875rem', fontWeight: '700', color: '#64748b' }}>Email</span>
                </div>
                <p style={{ fontSize: '1rem', fontWeight: '600', color: '#0f172a', wordBreak: 'break-all' }}>
                  {selectedUser.email || '無'}
                </p>
              </div>

              <div style={{ padding: '1.25rem', background: '#f8fafc', borderRadius: '16px', border: '2px solid #e2e8f0' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '0.75rem' }}>
                  <Phone size={20} color="#10b981" />
                  <span style={{ fontSize: '0.875rem', fontWeight: '700', color: '#64748b' }}>電話</span>
                </div>
                <p style={{ fontSize: '1rem', fontWeight: '600', color: '#0f172a' }}>{selectedUser.phone || '無'}</p>
              </div>

              <div style={{ padding: '1.25rem', background: '#f8fafc', borderRadius: '16px', border: '2px solid #e2e8f0' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '0.75rem' }}>
                  <Calendar size={20} color="#f59e0b" />
                  <span style={{ fontSize: '0.875rem', fontWeight: '700', color: '#64748b' }}>註冊日期</span>
                </div>
                <p style={{ fontSize: '1rem', fontWeight: '600', color: '#0f172a' }}>
                  {new Date(selectedUser.created_at).toLocaleDateString('zh-TW')}
                </p>
              </div>
            </div>

            {/* Vehicles Section (Only for Drivers) */}
            {selectedUser.user_type === 'driver' && (
              <div>
                <div style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '0.75rem',
                  marginBottom: '1.5rem',
                  paddingBottom: '1rem',
                  borderBottom: '3px solid #e2e8f0'
                }}>
                  <Car size={28} color="#3b82f6" />
                  <h3 style={{ fontSize: '1.5rem', fontWeight: '900', color: '#0f172a' }}>
                    車輛資訊
                  </h3>
                  <span className="badge badge-info" style={{ marginLeft: 'auto' }}>
                    {userVehicles.length} 輛車
                  </span>
                </div>

                {dataLoading ? (
                  <div style={{ textAlign: 'center', padding: '3rem' }}>
                    <div className="spinner" style={{ margin: '0 auto 1rem' }} />
                    <p style={{ color: '#64748b', fontWeight: '600' }}>載入車輛資料中...</p>
                  </div>
                ) : userVehicles.length === 0 ? (
                  <div style={{ 
                    textAlign: 'center', 
                    padding: '3rem',
                    background: '#f8fafc',
                    borderRadius: '16px',
                    border: '2px dashed #cbd5e1'
                  }}>
                    <Car size={48} color="#cbd5e1" style={{ margin: '0 auto 1rem' }} />
                    <p style={{ fontSize: '1rem', fontWeight: '600', color: '#64748b' }}>
                      此車主尚未註冊任何車輛
                    </p>
                  </div>
                ) : (
                  <div style={{ display: 'grid', gap: '1rem' }}>
                    {userVehicles.map((vehicle) => (
                      <div
                        key={vehicle.vehicle_id}
                        style={{
                          padding: '1.5rem',
                          background: 'linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%)',
                          borderRadius: '16px',
                          border: '2px solid #e2e8f0',
                          transition: 'all 0.2s'
                        }}
                        onMouseEnter={(e) => {
                          e.currentTarget.style.borderColor = '#3b82f6';
                          e.currentTarget.style.transform = 'translateY(-2px)';
                        }}
                        onMouseLeave={(e) => {
                          e.currentTarget.style.borderColor = '#e2e8f0';
                          e.currentTarget.style.transform = 'translateY(0)';
                        }}
                      >
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start', marginBottom: '1rem' }}>
                          <div style={{ flex: 1 }}>
                            <h4 style={{ fontSize: '1.25rem', fontWeight: '800', color: '#0f172a', marginBottom: '0.5rem' }}>
                              {vehicle.model || '未知型號'}
                            </h4>
                            <p style={{ fontSize: '0.875rem', color: '#64748b', fontWeight: '600' }}>
                              車牌號碼：<span style={{ color: '#1e40af', fontWeight: '800' }}>{vehicle.plate_number}</span>
                            </p>
                          </div>
                          {getVehicleStatusBadge(vehicle.status)}
                        </div>

                        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: '1rem' }}>
                          <div>
                            <p style={{ fontSize: '0.75rem', color: '#94a3b8', fontWeight: '600', marginBottom: '0.25rem' }}>電池容量</p>
                            <p style={{ fontSize: '1rem', fontWeight: '700', color: '#0f172a' }}>
                              {vehicle.battery_capacity_kWh ? `${vehicle.battery_capacity_kWh} kWh` : '未設定'}
                            </p>
                          </div>
                          <div>
                            <p style={{ fontSize: '0.75rem', color: '#94a3b8', fontWeight: '600', marginBottom: '0.25rem' }}>當前電量</p>
                            <p style={{ fontSize: '1rem', fontWeight: '700', color: '#0f172a' }}>
                              {vehicle.current_charge_percent ? `${vehicle.current_charge_percent}%` : '未知'}
                            </p>
                          </div>
                          <div>
                            <p style={{ fontSize: '0.75rem', color: '#94a3b8', fontWeight: '600', marginBottom: '0.25rem' }}>車輛 ID</p>
                            <p style={{ fontSize: '1rem', fontWeight: '700', color: '#0f172a' }}>#{vehicle.vehicle_id}</p>
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}

            {/* Trips Section (Only for Riders) */}
            {selectedUser.user_type === 'rider' && (
              <div>
                <div style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '0.75rem',
                  marginBottom: '1.5rem',
                  paddingBottom: '1rem',
                  borderBottom: '3px solid #e2e8f0'
                }}>
                  <MapPin size={28} color="#3b82f6" />
                  <h3 style={{ fontSize: '1.5rem', fontWeight: '900', color: '#0f172a' }}>
                    行程記錄
                  </h3>
                  <span className="badge badge-info" style={{ marginLeft: 'auto' }}>
                    {userTrips.length} 趟行程
                  </span>
                </div>

                {dataLoading ? (
                  <div style={{ textAlign: 'center', padding: '3rem' }}>
                    <div className="spinner" style={{ margin: '0 auto 1rem' }} />
                    <p style={{ color: '#64748b', fontWeight: '600' }}>載入行程資料中...</p>
                  </div>
                ) : userTrips.length === 0 ? (
                  <div style={{ 
                    textAlign: 'center', 
                    padding: '3rem',
                    background: '#f8fafc',
                    borderRadius: '16px',
                    border: '2px dashed #cbd5e1'
                  }}>
                    <MapPin size={48} color="#cbd5e1" style={{ margin: '0 auto 1rem' }} />
                    <p style={{ fontSize: '1rem', fontWeight: '600', color: '#64748b' }}>
                      此乘客尚無行程記錄
                    </p>
                  </div>
                ) : (
                  <div style={{ display: 'grid', gap: '1rem', maxHeight: '500px', overflowY: 'auto' }}>
                    {userTrips.map((trip) => (
                      <div
                        key={trip.trip_id}
                        style={{
                          padding: '1.5rem',
                          background: 'linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%)',
                          borderRadius: '16px',
                          border: '2px solid #e2e8f0',
                          transition: 'all 0.2s'
                        }}
                        onMouseEnter={(e) => {
                          e.currentTarget.style.borderColor = '#3b82f6';
                          e.currentTarget.style.transform = 'translateY(-2px)';
                        }}
                        onMouseLeave={(e) => {
                          e.currentTarget.style.borderColor = '#e2e8f0';
                          e.currentTarget.style.transform = 'translateY(0)';
                        }}
                      >
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start', marginBottom: '1rem' }}>
                          <div style={{ flex: 1 }}>
                            <h4 style={{ fontSize: '1.125rem', fontWeight: '800', color: '#0f172a', marginBottom: '0.5rem' }}>
                              行程 #{trip.trip_id}
                            </h4>
                            <p style={{ fontSize: '0.875rem', color: '#64748b', fontWeight: '600' }}>
                              車輛：{trip.vehicle_model || '未知'} ({trip.plate_number || '無車牌'})
                            </p>
                            {trip.driver_name && (
                              <p style={{ fontSize: '0.875rem', color: '#64748b', fontWeight: '600' }}>
                                司機：{trip.driver_name}
                              </p>
                            )}
                          </div>
                          {getTripStatusBadge(trip.status)}
                        </div>

                        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: '1rem' }}>
                          <div>
                            <p style={{ fontSize: '0.75rem', color: '#94a3b8', fontWeight: '600', marginBottom: '0.25rem' }}>距離</p>
                            <p style={{ fontSize: '1rem', fontWeight: '700', color: '#0f172a' }}>
                              {trip.distance_km ? `${trip.distance_km} km` : '未知'}
                            </p>
                          </div>
                          <div>
                            <p style={{ fontSize: '0.75rem', color: '#94a3b8', fontWeight: '600', marginBottom: '0.25rem' }}>費用</p>
                            <p style={{ fontSize: '1rem', fontWeight: '700', color: '#0f172a' }}>
                              {trip.paid_amount ? `${Number(trip.paid_amount).toFixed(4)} SUI` : trip.fare ? `${Number(trip.fare).toFixed(4)} SUI` : '未知'}
                            </p>
                          </div>
                          <div>
                            <p style={{ fontSize: '0.75rem', color: '#94a3b8', fontWeight: '600', marginBottom: '0.25rem' }}>付款方式</p>
                            <p style={{ fontSize: '1rem', fontWeight: '700', color: '#0f172a' }}>
                              {trip.paid_with === 'points' ? '點數' : trip.paid_with === 'card' ? '信用卡' : trip.paid_with === 'cash' ? '現金' : '未付款'}
                            </p>
                          </div>
                          <div>
                            <p style={{ fontSize: '0.75rem', color: '#94a3b8', fontWeight: '600', marginBottom: '0.25rem' }}>出發時間</p>
                            <p style={{ fontSize: '0.875rem', fontWeight: '600', color: '#0f172a' }}>
                              {new Date(trip.requested_at).toLocaleString('zh-TW')}
                            </p>
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      )}
    </Layout>
  );
};

export default UserManagement;
