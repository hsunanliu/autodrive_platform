import React, { useState, useEffect } from 'react';
import Layout from '../components/Layout';
import { refundAPI } from '../services/api';
import { Search, Filter, CheckCircle, XCircle, Clock, DollarSign, User, Calendar, AlertCircle, Pause } from 'lucide-react';

const RefundManagement = () => {
  const [refunds, setRefunds] = useState([]);
  const [loading, setLoading] = useState(true);
  const [statusFilter, setStatusFilter] = useState('');
  const [searchType, setSearchType] = useState('user_id');
  const [searchValue, setSearchValue] = useState('');
  const [selectedRefund, setSelectedRefund] = useState(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [liability, setLiability] = useState('');
  const [liabilityNote, setLiabilityNote] = useState('');
  const [recoveryStatus, setRecoveryStatus] = useState('pending');
  const [updating, setUpdating] = useState(false);
  const [approvedAmountTWD, setApprovedAmountTWD] = useState('');
  const [approvedPoints, setApprovedPoints] = useState('');
  const [decisionNote, setDecisionNote] = useState('');

  // 初始載入
  useEffect(() => {
    fetchRefunds();
  }, []);

  // 監聽狀態篩選變化
  useEffect(() => {
    fetchRefunds();
  }, [statusFilter]);

  // 修改後的 fetchRefunds，接受可選參數
  const fetchRefunds = async (overrideParams = {}) => {
    try {
      setLoading(true);
      const params = {};
      
      // 使用傳入的參數或當前狀態
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
      const response = await refundAPI.getAll(params);
      console.log('收到退款數據:', response.data);
      setRefunds(response.data);
    } catch (error) {
      console.error('獲取退款請求失敗:', error);
      alert('載入退款資料失敗');
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = () => {
    // 立即使用當前的搜尋參數執行搜尋
    fetchRefunds({
      status: statusFilter,
      search_type: searchType,
      search_value: searchValue
    });
  };

  const handleUpdateLiability = async () => {
    if (!liability) {
      alert('請選擇責任歸屬');
      return;
    }

    try {
      setUpdating(true);
      const data = { 
        status: 'reviewed',  // 標記為已審核
        liability: liability,
        liability_note: liabilityNote || null,
        recovery_status: recoveryStatus
      };
      
      await refundAPI.update(selectedRefund.refund_request_id, data);
      alert('責任歸屬已更新');
      setModalOpen(false);
      setSelectedRefund(null);
      setLiability('');
      setLiabilityNote('');
      setRecoveryStatus('pending');
      fetchRefunds();
    } catch (error) {
      console.error('更新失敗:', error);
      alert('更新失敗: ' + (error.response?.data?.detail || error.message));
    } finally {
      setUpdating(false);
    }
  };

  const handleUpdateStatus = async (status) => {
    try {
      setUpdating(true);
      const data = { 
        status,
        decision_note: decisionNote || null
      };
      
      if (status === 'approved') {
        const approvedTWD = parseFloat(approvedAmountTWD) || 0;
        const approvedPts = parseInt(approvedPoints) || 0;
        
        if (approvedTWD > 0) {
          data.approved_refund_twd = approvedTWD;
        }
        if (approvedPts > 0) {
          data.approved_refund_points = approvedPts;
        }
        
        if (approvedTWD === 0 && approvedPts === 0) {
          alert('請至少輸入核准金額或點數');
          setUpdating(false);
          return;
        }
      }
      
      console.log('發送更新請求:', data);
      await refundAPI.update(selectedRefund.refund_request_id, data);
      
      setModalOpen(false);
      setSelectedRefund(null);
      setApprovedAmountTWD('');
      setApprovedPoints('');
      setDecisionNote('');
      
      alert('退款狀態已更新！');
      fetchRefunds();
    } catch (error) {
      console.error('更新退款狀態失敗:', error);
      alert('更新失敗: ' + (error.response?.data?.detail || error.message));
    } finally {
      setUpdating(false);
    }
  };

  const openModal = (refund) => {
    setSelectedRefund(refund);
    setApprovedAmountTWD(refund.requested_refund_twd?.toString() || '0');
    setApprovedPoints(refund.requested_refund_points?.toString() || '0');
    setDecisionNote('');
    setModalOpen(true);
  };

  const getStatusBadge = (status) => {
    const statusMap = {
      pending: { label: '待處理', class: 'badge-warning', icon: Clock },
      approved: { label: '已核准', class: 'badge-success', icon: CheckCircle },
      rejected: { label: '已拒絕', class: 'badge-danger', icon: XCircle },
      on_hold: { label: '暫緩', class: 'badge-info', icon: Pause },
      cancelled: { label: '已取消', class: 'badge-secondary', icon: XCircle },
    };
    const statusInfo = statusMap[status] || { label: status, class: 'badge-secondary', icon: AlertCircle };
    const Icon = statusInfo.icon;
    return (
      <span className={`badge ${statusInfo.class}`} style={{ display: 'inline-flex', alignItems: 'center', gap: '0.5rem' }}>
        <Icon size={16} />
        {statusInfo.label}
      </span>
    );
  };

  const searchTypes = [
    { value: 'user_id', label: '用戶 ID' },
    { value: 'trip_id', label: '行程 ID' },
    { value: 'user_name', label: '用戶名稱' }
  ];

  if (loading && refunds.length === 0) {
    return (
      <Layout>
        <div className="loading">
          <div className="spinner-lg" />
          <p style={{ color: '#64748b', fontSize: '1.125rem', fontWeight: '600' }}>載入退款資料中...</p>
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
              <DollarSign size={36} />
            </div>
            <div>
              <h1 style={{ fontSize: '2.5rem', fontWeight: '900', marginBottom: '0.25rem' }}>退款管理</h1>
              <p style={{ fontSize: '1.125rem', opacity: 0.95 }}>管理和處理所有退款請求</p>
            </div>
          </div>
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
                <span>狀態篩選</span>
              </label>
              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                className="select-field"
              >
                <option value="">全部狀態</option>
                <option value="pending">待處理</option>
                <option value="approved">已核准</option>
                <option value="rejected">已拒絕</option>
                <option value="on_hold">暫緩</option>
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
            找到 <span style={{ fontSize: '1.25rem', color: '#0284c7' }}>{refunds.length}</span> 筆退款記錄
          </p>
        </div>

        {/* Refunds Table */}
        <div className="table-container">
          <table>
            <thead>
              <tr>
                <th>退款 ID</th>
                <th>行程 ID</th>
                <th>申請人</th>
                <th>司機</th>
                <th>原因</th>
                <th>申請金額/點數</th>
                <th>核准金額/點數</th>
                <th>狀態</th>
                <th>申請時間</th>
                <th>操作</th>
              </tr>
            </thead>
            <tbody>
              {refunds.length === 0 ? (
                <tr>
                  <td colSpan="10" style={{ textAlign: 'center', padding: '3rem', color: '#94a3b8' }}>
                    <AlertCircle size={48} style={{ margin: '0 auto 1rem', opacity: 0.5 }} />
                    <p style={{ fontSize: '1.125rem', fontWeight: '600' }}>暫無退款記錄</p>
                  </td>
                </tr>
              ) : (
                refunds.map((refund) => (
                  <tr key={refund.refund_request_id}>
                    <td style={{ fontWeight: '700', color: '#1e40af' }}>#{refund.refund_request_id}</td>
                    <td style={{ fontWeight: '600' }}>#{refund.trip_id}</td>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                        <User size={16} color="#64748b" />
                        <span style={{ fontWeight: '600' }}>{refund.rider_name || `User ${refund.rider_id}`}</span>
                      </div>
                    </td>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                        <User size={16} color="#64748b" />
                        <span style={{ fontWeight: '600' }}>{refund.driver_name || `Owner ${refund.owner_id}`}</span>
                      </div>
                    </td>
                    <td style={{ maxWidth: '200px' }}>
                      <span style={{ 
                        display: '-webkit-box',
                        WebkitLineClamp: 2,
                        WebkitBoxOrient: 'vertical',
                        overflow: 'hidden',
                        fontSize: '0.875rem',
                        color: '#64748b'
                      }}>
                        {refund.reason || '無'}
                      </span>
                    </td>
                    <td>
                      <div style={{ fontSize: '0.875rem' }}>
                        {refund.requested_refund_twd > 0 && (
                          <div style={{ fontWeight: '700', color: '#0f172a' }}>
                            NT$ {refund.requested_refund_twd.toLocaleString()}
                          </div>
                        )}
                        {refund.requested_refund_points > 0 && (
                          <div style={{ fontWeight: '700', color: '#f59e0b' }}>
                            {refund.requested_refund_points.toLocaleString()} 點
                          </div>
                        )}
                        {(!refund.requested_refund_twd && !refund.requested_refund_points) && (
                          <span style={{ color: '#94a3b8' }}>-</span>
                        )}
                      </div>
                    </td>
                    <td>
                      <div style={{ fontSize: '0.875rem' }}>
                        {refund.approved_refund_twd > 0 && (
                          <div style={{ fontWeight: '700', color: '#10b981' }}>
                            NT$ {refund.approved_refund_twd.toLocaleString()}
                          </div>
                        )}
                        {refund.approved_refund_points > 0 && (
                          <div style={{ fontWeight: '700', color: '#f59e0b' }}>
                            {refund.approved_refund_points.toLocaleString()} 點
                          </div>
                        )}
                        {(!refund.approved_refund_twd && !refund.approved_refund_points) && (
                          <span style={{ color: '#94a3b8' }}>-</span>
                        )}
                      </div>
                    </td>
                    <td>{getStatusBadge(refund.status)}</td>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', fontSize: '0.875rem' }}>
                        <Calendar size={16} color="#64748b" />
                        <span>{new Date(refund.created_at).toLocaleDateString('zh-TW')}</span>
                      </div>
                    </td>
                    <td>
                      {(refund.status === 'pending' || refund.status === 'on_hold') && (
                        <button
                          onClick={() => openModal(refund)}
                          className="btn btn-primary"
                          style={{ padding: '0.5rem 1rem', fontSize: '0.875rem' }}
                        >
                          處理
                        </button>
                      )}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Modal */}
      {modalOpen && selectedRefund && (
        <div className="modal-overlay" onClick={() => !updating && setModalOpen(false)}>
          <div className="modal-content" style={{ maxWidth: '600px' }} onClick={(e) => e.stopPropagation()}>
            <h2 style={{ fontSize: '2rem', fontWeight: '900', color: '#0f172a', marginBottom: '1.5rem' }}>
              處理退款請求 #{selectedRefund.refund_request_id}
            </h2>
            
            {/* 退款資訊 */}
            <div style={{ marginBottom: '2rem', padding: '1.5rem', background: '#f8fafc', borderRadius: '16px', border: '2px solid #e2e8f0' }}>
              <div style={{ display: 'grid', gap: '1rem' }}>
                <div>
                  <p style={{ fontSize: '0.875rem', color: '#64748b', fontWeight: '600', marginBottom: '0.25rem' }}>行程 ID</p>
                  <p style={{ fontSize: '1.125rem', fontWeight: '800', color: '#0f172a' }}>#{selectedRefund.trip_id}</p>
                </div>
                <div>
                  <p style={{ fontSize: '0.875rem', color: '#64748b', fontWeight: '600', marginBottom: '0.25rem' }}>申請人</p>
                  <p style={{ fontSize: '1rem', fontWeight: '700', color: '#0f172a' }}>
                    {selectedRefund.rider_name || `User ${selectedRefund.rider_id}`}
                  </p>
                </div>
                <div>
                  <p style={{ fontSize: '0.875rem', color: '#64748b', fontWeight: '600', marginBottom: '0.25rem' }}>申請金額</p>
                  <div>
                    {selectedRefund.requested_refund_twd > 0 && (
                      <p style={{ fontSize: '1.5rem', fontWeight: '900', color: '#1e40af', marginBottom: '0.25rem' }}>
                        NT$ {selectedRefund.requested_refund_twd.toLocaleString()}
                      </p>
                    )}
                    {selectedRefund.requested_refund_points > 0 && (
                      <p style={{ fontSize: '1.25rem', fontWeight: '800', color: '#f59e0b' }}>
                        {selectedRefund.requested_refund_points.toLocaleString()} 點
                      </p>
                    )}
                  </div>
                </div>
                <div>
                  <p style={{ fontSize: '0.875rem', color: '#64748b', fontWeight: '600', marginBottom: '0.25rem' }}>申請原因</p>
                  <p style={{ fontSize: '0.9375rem', color: '#334155', lineHeight: '1.6' }}>{selectedRefund.reason || '無'}</p>
                </div>
              </div>
            </div>

            {/* 核准金額輸入 */}
            <div style={{ marginBottom: '1.5rem' }}>
              <label style={{ 
                display: 'block',
                fontSize: '0.875rem', 
                fontWeight: '700', 
                color: '#334155', 
                marginBottom: '0.5rem' 
              }}>
                核准金額（NT$）
                <span style={{ color: '#64748b', fontWeight: '400', marginLeft: '0.5rem' }}>
                  最多 NT$ {selectedRefund.requested_refund_twd?.toLocaleString() || 0}
                </span>
              </label>
              <input
                type="number"
                value={approvedAmountTWD}
                onChange={(e) => setApprovedAmountTWD(e.target.value)}
                className="input-field"
                placeholder="輸入核准金額"
                min="0"
                max={selectedRefund.requested_refund_twd || 0}
                step="0.01"
                disabled={updating}
              />
            </div>

            {/* 核准點數輸入 */}
            <div style={{ marginBottom: '1.5rem' }}>
              <label style={{ 
                display: 'block',
                fontSize: '0.875rem', 
                fontWeight: '700', 
                color: '#334155', 
                marginBottom: '0.5rem' 
              }}>
                核准點數
                <span style={{ color: '#64748b', fontWeight: '400', marginLeft: '0.5rem' }}>
                  最多 {selectedRefund.requested_refund_points?.toLocaleString() || 0} 點
                </span>
              </label>
              <input
                type="number"
                value={approvedPoints}
                onChange={(e) => setApprovedPoints(e.target.value)}
                className="input-field"
                placeholder="輸入核准點數"
                min="0"
                max={selectedRefund.requested_refund_points || 0}
                step="1"
                disabled={updating}
              />
            </div>

            {/* 決定原因 */}
            <div style={{ marginBottom: '2rem' }}>
              <label style={{ 
                display: 'block',
                fontSize: '0.875rem', 
                fontWeight: '700', 
                color: '#334155', 
                marginBottom: '0.5rem' 
              }}>
                處理原因說明
              </label>
              <textarea
                value={decisionNote}
                onChange={(e) => setDecisionNote(e.target.value)}
                className="input-field"
                placeholder="請說明核准、拒絕或暫緩的原因"
                rows="4"
                disabled={updating}
                style={{ resize: 'vertical' }}
              />
            </div>

            {/* 操作按鈕 */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '1rem' }}>
              <button
                onClick={() => handleUpdateStatus('approved')}
                className="btn btn-success"
                disabled={updating}
              >
                <CheckCircle size={18} />
                核准
              </button>
              <button
                onClick={() => handleUpdateStatus('on_hold')}
                className="btn btn-warning"
                disabled={updating}
              >
                <Pause size={18} />
                暫緩
              </button>
              <button
                onClick={() => handleUpdateStatus('rejected')}
                className="btn btn-danger"
                disabled={updating}
              >
                <XCircle size={18} />
                拒絕
              </button>
            </div>

            {updating && (
              <div style={{ marginTop: '1rem', textAlign: 'center' }}>
                <div className="spinner" style={{ margin: '0 auto' }} />
                <p style={{ color: '#64748b', fontSize: '0.875rem', marginTop: '0.5rem' }}>處理中...</p>
              </div>
            )}
          </div>
        </div>
      )}
    </Layout>
  );
};

export default RefundManagement;