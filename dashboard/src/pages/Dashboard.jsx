import React, { useState, useEffect } from 'react';
import Layout from '../components/Layout';
import { dashboardAPI } from '../services/api';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts';
import { Users, Car, MapPin, TrendingUp, DollarSign, Calendar, ArrowUp, ArrowDown, CreditCard, Coins, RefreshCw } from 'lucide-react';

const Dashboard = () => {
  const [totals, setTotals] = useState(null);
  const [revenueData, setRevenueData] = useState([]);
  const [growthData, setGrowthData] = useState(null);
  const [paymentData, setPaymentData] = useState(null);
  const [revenueType, setRevenueType] = useState('monthly');
  const [growthType, setGrowthType] = useState('monthly');
  
  // 獲取今天的日期（格式：YYYY-MM-DD）
  const getTodayDate = () => {
    const today = new Date();
    const year = today.getFullYear();
    const month = String(today.getMonth() + 1).padStart(2, '0');
    const day = String(today.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  };
  
  const [baseDate, setBaseDate] = useState(getTodayDate()); // 實際用於 API 的日期
  const [tempBaseDate, setTempBaseDate] = useState(getTodayDate()); // 暫時儲存用戶選擇的日期
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchData();
  }, [revenueType, growthType, baseDate]);

  const fetchData = async () => {
    try {
      setLoading(true);
      const [totalsRes, revenueRes, growthRes, paymentRes] = await Promise.all([
        dashboardAPI.getTotals(),
        dashboardAPI.getRevenue(revenueType),
        dashboardAPI.getRevenueGrowth(growthType, baseDate),
        dashboardAPI.getPaymentDistribution(),
      ]);

      setTotals(totalsRes.data);
      setRevenueData(revenueRes.data);
      setGrowthData(growthRes.data);
      setPaymentData(paymentRes.data);
    } catch (error) {
      console.error('獲取儀表板數據失敗:', error);
    } finally {
      setLoading(false);
    }
  };

  // 應用日期變更
  const handleApplyDate = () => {
    setBaseDate(tempBaseDate);
  };

  // 重置為今天
  const handleResetToToday = () => {
    const today = getTodayDate();
    setTempBaseDate(today);
    setBaseDate(today);
  };

  const kpiCards = totals ? [
    {
      title: '總用戶數',
      value: totals.totalUsers?.toLocaleString() || '0',
      icon: Users,
      gradient: 'from-blue-500 to-blue-600',
      bgColor: '#eff6ff',
    },
    {
      title: '總車主數',
      value: totals.totalDrivers?.toLocaleString() || '0',
      icon: Users,
      gradient: 'from-green-500 to-green-600',
      bgColor: '#f0fdf4',
    },
    {
      title: '總車輛數',
      value: totals.totalVehicles?.toLocaleString() || '0',
      icon: Car,
      gradient: 'from-purple-500 to-purple-600',
      bgColor: '#faf5ff',
    },
    {
      title: '總行程數',
      value: totals.totalTrips?.toLocaleString() || '0',
      icon: MapPin,
      gradient: 'from-orange-500 to-orange-600',
      bgColor: '#fff7ed',
    },
    {
      title: '總營收',
      value: totals.totalRevenue ? `${Number(totals.totalRevenue).toFixed(2)} SUI` : '0 SUI',
      icon: DollarSign,
      gradient: 'from-emerald-500 to-emerald-600',
      bgColor: '#ecfdf5',
    },
  ] : [];

  // 甜甜圈圖顏色
  const COLORS = {
    card: '#3b82f6',
    points: '#f59e0b',
  };

  const paymentTypeLabels = {
    card: '信用卡',
    points: '點數',
  };

  // 格式化顯示日期
  const formatDisplayDate = (dateString) => {
    const date = new Date(dateString + 'T00:00:00');
    return date.toLocaleDateString('zh-TW', { year: 'numeric', month: 'long', day: 'numeric' });
  };

  if (loading) {
    return (
      <Layout>
        <div className="loading">
          <div className="spinner-lg" />
          <p style={{ color: '#64748b', fontSize: '1.125rem', fontWeight: '600' }}>載入儀表板資料中...</p>
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
              <TrendingUp size={36} />
            </div>
            <div>
              <h1 style={{ fontSize: '2.5rem', fontWeight: '900', marginBottom: '0.25rem' }}>儀表板</h1>
              <p style={{ fontSize: '1.125rem', opacity: 0.95 }}>系統總覽與數據分析</p>
            </div>
          </div>
        </div>

        {/* KPI Cards */}
        <div style={{ 
          display: 'grid', 
          gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', 
          gap: '1.5rem',
          marginBottom: '2rem'
        }}>
          {kpiCards.map((kpi, index) => {
            const Icon = kpi.icon;
            return (
              <div key={index} className="card">
                <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                  <div style={{
                    padding: '12px',
                    borderRadius: '12px',
                    background: kpi.bgColor,
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
                      {kpi.title}
                    </p>
                    <p style={{ fontSize: '2rem', fontWeight: '900', color: '#0f172a', lineHeight: '1' }}>
                      {kpi.value}
                    </p>
                  </div>
                </div>
              </div>
            );
          })}
        </div>

        {/* Growth Trends */}
        {growthData && (
          <div className="card" style={{ marginBottom: '2rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem', flexWrap: 'wrap', gap: '1rem' }}>
              <h2 style={{ fontSize: '1.5rem', fontWeight: '900', color: '#0f172a', display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                <TrendingUp size={28} color="#3b82f6" />
                成長趨勢
              </h2>
              <div style={{ display: 'flex', gap: '1rem', alignItems: 'center', flexWrap: 'wrap' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  <Calendar size={20} color="#64748b" />
                  <span style={{ fontSize: '0.875rem', fontWeight: '600', color: '#64748b' }}>
                    基準日期：
                  </span>
                  <input
                    type="date"
                    value={tempBaseDate}
                    onChange={(e) => setTempBaseDate(e.target.value)}
                    className="input-field"
                    style={{ width: 'auto', padding: '0.5rem 0.75rem' }}
                  />
                  <button
                    onClick={handleApplyDate}
                    className="btn btn-primary"
                    style={{ padding: '0.5rem 1rem', fontSize: '0.875rem' }}
                    disabled={tempBaseDate === baseDate}
                  >
                    <RefreshCw size={16} />
                    應用
                  </button>
                  <button
                    onClick={handleResetToToday}
                    className="btn btn-secondary"
                    style={{ padding: '0.5rem 1rem', fontSize: '0.875rem' }}
                  >
                    今天
                  </button>
                </div>
                <select
                  value={growthType}
                  onChange={(e) => setGrowthType(e.target.value)}
                  className="select-field"
                  style={{ width: 'auto', minWidth: '120px' }}
                >
                  <option value="daily">日</option>
                  <option value="weekly">週</option>
                  <option value="monthly">月</option>
                  <option value="yearly">年</option>
                </select>
              </div>
            </div>

            {/* 顯示當前選定的日期 */}
            <div style={{
              padding: '1rem',
              background: 'linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%)',
              borderRadius: '12px',
              border: '2px solid #bae6fd',
              marginBottom: '1.5rem'
            }}>
              <p style={{ fontSize: '0.875rem', fontWeight: '700', color: '#0c4a6e', textAlign: 'center' }}>
                📅 分析基準日期：<span style={{ fontSize: '1rem', color: '#0284c7' }}>{formatDisplayDate(baseDate)}</span>
              </p>
            </div>

            <div style={{ 
              display: 'grid', 
              gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', 
              gap: '1.5rem' 
            }}>
              {/* 行程數成長 */}
              <div style={{
                padding: '1.5rem',
                background: 'linear-gradient(135deg, #eff6ff 0%, #dbeafe 100%)',
                borderRadius: '16px',
                border: '2px solid #bfdbfe'
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '1rem' }}>
                  <MapPin size={24} color="#3b82f6" />
                  <h3 style={{ fontSize: '1.125rem', fontWeight: '800', color: '#1e40af' }}>行程數</h3>
                </div>
                
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '1rem' }}>
                  <div>
                    <p style={{ fontSize: '0.875rem', color: '#64748b', marginBottom: '0.25rem' }}>{growthData.current.label}</p>
                    <p style={{ fontSize: '2rem', fontWeight: '900', color: '#0f172a' }}>
                      {growthData.current.trips.toLocaleString()}
                    </p>
                  </div>
                  <div style={{ textAlign: 'right' }}>
                    <p style={{ fontSize: '0.875rem', color: '#64748b', marginBottom: '0.25rem' }}>{growthData.previous.label}</p>
                    <p style={{ fontSize: '1.25rem', fontWeight: '700', color: '#64748b' }}>
                      {growthData.previous.trips.toLocaleString()}
                    </p>
                  </div>
                </div>

                <div style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '0.5rem',
                  padding: '0.75rem',
                  background: growthData.growth.trips >= 0 ? '#dcfce7' : '#fee2e2',
                  borderRadius: '12px'
                }}>
                  {growthData.growth.trips >= 0 ? (
                    <ArrowUp size={20} color="#10b981" />
                  ) : (
                    <ArrowDown size={20} color="#ef4444" />
                  )}
                  <span style={{
                    fontSize: '1.25rem',
                    fontWeight: '900',
                    color: growthData.growth.trips >= 0 ? '#10b981' : '#ef4444'
                  }}>
                    {Math.abs(growthData.growth.trips)}%
                  </span>
                  <span style={{ fontSize: '0.875rem', color: '#64748b', marginLeft: 'auto' }}>
                    較{growthData.previous.label}
                  </span>
                </div>
              </div>

              {/* 營收成長 */}
              <div style={{
                padding: '1.5rem',
                background: 'linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%)',
                borderRadius: '16px',
                border: '2px solid #bbf7d0'
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '1rem' }}>
                  <DollarSign size={24} color="#10b981" />
                  <h3 style={{ fontSize: '1.125rem', fontWeight: '800', color: '#059669' }}>營收</h3>
                </div>
                
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '1rem' }}>
                  <div>
                    <p style={{ fontSize: '0.875rem', color: '#64748b', marginBottom: '0.25rem' }}>{growthData.current.label}</p>
                    <p style={{ fontSize: '2rem', fontWeight: '900', color: '#0f172a' }}>
                      {Number(growthData.current.revenue).toFixed(4)} SUI
                    </p>
                  </div>
                  <div style={{ textAlign: 'right' }}>
                    <p style={{ fontSize: '0.875rem', color: '#64748b', marginBottom: '0.25rem' }}>{growthData.previous.label}</p>
                    <p style={{ fontSize: '1.25rem', fontWeight: '700', color: '#64748b' }}>
                      {Number(growthData.previous.revenue).toFixed(4)} SUI
                    </p>
                  </div>
                </div>

                <div style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '0.5rem',
                  padding: '0.75rem',
                  background: growthData.growth.revenue >= 0 ? '#dcfce7' : '#fee2e2',
                  borderRadius: '12px'
                }}>
                  {growthData.growth.revenue >= 0 ? (
                    <ArrowUp size={20} color="#10b981" />
                  ) : (
                    <ArrowDown size={20} color="#ef4444" />
                  )}
                  <span style={{
                    fontSize: '1.25rem',
                    fontWeight: '900',
                    color: growthData.growth.revenue >= 0 ? '#10b981' : '#ef4444'
                  }}>
                    {Math.abs(growthData.growth.revenue)}%
                  </span>
                  <span style={{ fontSize: '0.875rem', color: '#64748b', marginLeft: 'auto' }}>
                    較{growthData.previous.label}
                  </span>
                </div>
              </div>
            </div>
          </div>
        )}

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '2rem', marginBottom: '2rem' }}>
          {/* Revenue Chart */}
          <div className="card">
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem' }}>
              <h2 style={{ fontSize: '1.5rem', fontWeight: '900', color: '#0f172a', display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                <DollarSign size={28} color="#10b981" />
                營收趨勢
              </h2>
              <select
                value={revenueType}
                onChange={(e) => setRevenueType(e.target.value)}
                className="select-field"
                style={{ width: 'auto', minWidth: '150px' }}
              >
                <option value="daily">日</option>
                <option value="monthly">月</option>
                <option value="yearly">年</option>
              </select>
            </div>

            {revenueData.length > 0 ? (
              <ResponsiveContainer width="100%" height={300}>
                <LineChart data={revenueData}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" />
                  <XAxis 
                    dataKey="date" 
                    stroke="#64748b"
                    style={{ fontSize: '0.75rem', fontWeight: '600' }}
                  />
                  <YAxis 
                    stroke="#64748b"
                    style={{ fontSize: '0.75rem', fontWeight: '600' }}
                  />
                  <Tooltip 
                    contentStyle={{
                      background: 'white',
                      border: '2px solid #e2e8f0',
                      borderRadius: '12px',
                      padding: '12px',
                      fontWeight: '600'
                    }}
                  />
                  <Legend 
                    wrapperStyle={{ 
                      paddingTop: '20px',
                      fontWeight: '700'
                    }}
                  />
                  <Line 
                    type="monotone" 
                    dataKey="total_revenue" 
                    stroke="#10b981" 
                    strokeWidth={3}
                    name="總營收"
                    dot={{ fill: '#10b981', r: 4 }}
                  />
                </LineChart>
              </ResponsiveContainer>
            ) : (
              <div style={{ textAlign: 'center', padding: '3rem', color: '#94a3b8' }}>
                <p>暫無營收數據</p>
              </div>
            )}
          </div>

          {/* Payment Distribution */}
          {paymentData && (
            <div className="card">
              <h2 style={{ fontSize: '1.5rem', fontWeight: '900', color: '#0f172a', marginBottom: '1.5rem', display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                <CreditCard size={28} color="#3b82f6" />
                付款方式分布
              </h2>

              <div style={{ display: 'flex', alignItems: 'center', gap: '2rem' }}>
                <ResponsiveContainer width="50%" height={250}>
                  <PieChart>
                    <Pie
                      data={paymentData.data}
                      cx="50%"
                      cy="50%"
                      innerRadius={60}
                      outerRadius={100}
                      paddingAngle={5}
                      dataKey="amount"
                    >
                      {paymentData.data.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={COLORS[entry.type]} />
                      ))}
                    </Pie>
                    <Tooltip 
                      contentStyle={{
                        background: 'white',
                        border: '2px solid #e2e8f0',
                        borderRadius: '12px',
                        padding: '12px',
                        fontWeight: '600'
                      }}
                      formatter={(value) => `${Number(value).toFixed(4)} SUI`}
                    />
                  </PieChart>
                </ResponsiveContainer>

                <div style={{ flex: 1 }}>
                  <div style={{ marginBottom: '1rem', padding: '1rem', background: '#f8fafc', borderRadius: '12px' }}>
                    <p style={{ fontSize: '0.875rem', color: '#64748b', fontWeight: '600', marginBottom: '0.25rem' }}>總金額</p>
                    <p style={{ fontSize: '1.75rem', fontWeight: '900', color: '#0f172a' }}>
                      {Number(paymentData.totalAmount).toFixed(4)} SUI
                    </p>
                  </div>

                  {paymentData.data.map((item, index) => (
                    <div 
                      key={index}
                      style={{
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'center',
                        padding: '0.75rem',
                        background: '#f8fafc',
                        borderRadius: '12px',
                        marginBottom: '0.5rem',
                        borderLeft: `4px solid ${COLORS[item.type]}`
                      }}
                    >
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                        {item.type === 'card' && <CreditCard size={20} color={COLORS[item.type]} />}
                        {item.type === 'points' && <Coins size={20} color={COLORS[item.type]} />}
                        <div>
                          <p style={{ fontSize: '0.9375rem', fontWeight: '800', color: '#0f172a' }}>
                            {paymentTypeLabels[item.type]}
                          </p>
                          <p style={{ fontSize: '0.75rem', color: '#64748b', fontWeight: '600' }}>
                            {item.count} 筆交易
                          </p>
                        </div>
                      </div>
                      <div style={{ textAlign: 'right' }}>
                        <p style={{ fontSize: '1.125rem', fontWeight: '900', color: '#0f172a' }}>
                          {Number(item.amount).toFixed(4)} SUI
                        </p>
                        <p style={{ fontSize: '0.875rem', color: '#64748b', fontWeight: '700' }}>
                          {item.percentage}%
                        </p>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </Layout>
  );
};

export default Dashboard;