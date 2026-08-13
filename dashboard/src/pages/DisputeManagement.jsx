import React, { useState, useEffect } from 'react';
import Layout from '../components/Layout';
import { disputeAPI } from '../services/api';
import { Gavel, Scale, User, Car, AlertCircle, CheckCircle, Clock, Shield } from 'lucide-react';

// ruling: 1 判給司機（release）/ 2 退乘客（refund）
const RULING_DRIVER = 1;
const RULING_PASSENGER = 2;

const DisputeManagement = () => {
  const [trips, setTrips] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selected, setSelected] = useState(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [ruling, setRuling] = useState(RULING_PASSENGER);
  const [note, setNote] = useState('');
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => { fetchDisputes(); }, []);

  const fetchDisputes = async () => {
    try {
      setLoading(true);
      const res = await disputeAPI.getDisputed();
      // 後端可能回陣列或 {data:[...]}；防禦式取值
      const data = Array.isArray(res.data) ? res.data : (res.data?.trips || res.data?.data || []);
      setTrips(data);
    } catch (e) {
      console.error('載入爭議行程失敗:', e);
      alert('載入爭議行程失敗: ' + (e.response?.data?.detail || e.message));
    } finally {
      setLoading(false);
    }
  };

  const openModal = (trip) => {
    setSelected(trip);
    setRuling(RULING_PASSENGER);
    setNote('');
    setModalOpen(true);
  };

  const handleResolve = async () => {
    if (!selected) return;
    const tripId = selected.trip_id ?? selected.id;
    if (!selected.dispute_object_id) {
      alert('此行程缺少鏈上 Dispute 物件 ID，無法裁決（需乘客/司機先在錢包簽 raise_dispute 並回報）。');
      return;
    }
    try {
      setSubmitting(true);
      const res = await disputeAPI.resolve(tripId, ruling, note || null);
      alert(`裁決完成（${ruling === RULING_DRIVER ? '判給司機' : '退乘客'}）\n交易: ${res.data?.transaction_hash || '已送出'}`);
      setModalOpen(false);
      setSelected(null);
      fetchDisputes();
    } catch (e) {
      console.error('裁決失敗:', e);
      alert('裁決失敗: ' + (e.response?.data?.detail || e.message));
    } finally {
      setSubmitting(false);
    }
  };

  const short = (v) => (v ? `${String(v).slice(0, 10)}…` : '—');

  if (loading && trips.length === 0) {
    return (
      <Layout>
        <div className="loading">
          <div className="spinner-lg" />
          <p style={{ color: '#64748b', fontSize: '1.125rem', fontWeight: 600 }}>載入爭議行程中...</p>
        </div>
      </Layout>
    );
  }

  return (
    <Layout>
      <div style={{ maxWidth: '1600px', margin: '0 auto' }}>
        {/* Header */}
        <div style={{
          background: 'linear-gradient(135deg, #7c2d12 0%, #b45309 100%)',
          borderRadius: '24px', padding: '2.5rem', marginBottom: '2rem', color: 'white',
          boxShadow: '0 10px 40px rgba(124, 45, 18, 0.3)',
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
            <div style={{ padding: '12px', background: 'rgba(255,255,255,0.2)', borderRadius: '16px', backdropFilter: 'blur(10px)' }}>
              <Gavel size={36} />
            </div>
            <div>
              <h1 style={{ fontSize: '2.5rem', fontWeight: 900, marginBottom: '0.25rem' }}>爭議仲裁</h1>
              <p style={{ fontSize: '1.125rem', opacity: 0.95 }}>裁決凍結中的行程 — 判給司機（放款）或退乘客（退款），由平台 ArbiterCap 上鏈執行</p>
            </div>
          </div>
        </div>

        {/* Count */}
        <div style={{
          marginBottom: '1.5rem', padding: '1rem 1.5rem',
          background: 'linear-gradient(135deg, #fff7ed 0%, #ffedd5 100%)',
          borderRadius: '16px', border: '2px solid #fed7aa',
        }}>
          <p style={{ fontSize: '0.9375rem', fontWeight: 700, color: '#7c2d12' }}>
            目前 <span style={{ fontSize: '1.25rem', color: '#c2410c' }}>{trips.length}</span> 筆爭議待裁決
          </p>
        </div>

        {/* Table */}
        <div className="table-container">
          <table>
            <thead>
              <tr>
                <th>行程 ID</th>
                <th>乘客</th>
                <th>司機</th>
                <th>託管 (escrow)</th>
                <th>爭議物件</th>
                <th>狀態</th>
                <th>操作</th>
              </tr>
            </thead>
            <tbody>
              {trips.length === 0 ? (
                <tr>
                  <td colSpan="7" style={{ textAlign: 'center', padding: '3rem', color: '#94a3b8' }}>
                    <CheckCircle size={48} style={{ margin: '0 auto 1rem', opacity: 0.5 }} />
                    <p style={{ fontSize: '1.125rem', fontWeight: 600 }}>目前沒有爭議行程</p>
                  </td>
                </tr>
              ) : (
                trips.map((t) => {
                  const tripId = t.trip_id ?? t.id;
                  return (
                    <tr key={tripId}>
                      <td style={{ fontWeight: 700, color: '#c2410c' }}>#{tripId}</td>
                      <td><span style={{ display: 'inline-flex', alignItems: 'center', gap: '0.5rem', fontWeight: 600 }}><User size={16} color="#64748b" />{t.rider_name || t.username || `User ${t.user_id}`}</span></td>
                      <td><span style={{ display: 'inline-flex', alignItems: 'center', gap: '0.5rem', fontWeight: 600 }}><Car size={16} color="#64748b" />{t.driver_name || (t.driver_id ? `Driver ${t.driver_id}` : '—')}</span></td>
                      <td style={{ fontFamily: 'monospace', fontSize: '0.8rem' }}>{short(t.escrow_object_id)}</td>
                      <td style={{ fontFamily: 'monospace', fontSize: '0.8rem' }}>
                        {t.dispute_object_id
                          ? short(t.dispute_object_id)
                          : <span style={{ color: '#dc2626', fontWeight: 700 }}>未回報</span>}
                      </td>
                      <td>
                        <span className="badge badge-warning" style={{ display: 'inline-flex', alignItems: 'center', gap: '0.4rem' }}>
                          <Clock size={16} /> 爭議中（凍結）
                        </span>
                      </td>
                      <td>
                        <button onClick={() => openModal(t)} className="btn btn-primary" style={{ padding: '0.5rem 1rem', fontSize: '0.875rem' }}>
                          <Scale size={16} /> 裁決
                        </button>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Modal */}
      {modalOpen && selected && (
        <div className="modal-overlay" onClick={() => !submitting && setModalOpen(false)}>
          <div className="modal-content" style={{ maxWidth: '560px' }} onClick={(e) => e.stopPropagation()}>
            <h2 style={{ fontSize: '2rem', fontWeight: 900, color: '#0f172a', marginBottom: '1.5rem' }}>
              裁決爭議 · 行程 #{selected.trip_id ?? selected.id}
            </h2>

            <div style={{ marginBottom: '1.5rem', padding: '1.25rem', background: '#f8fafc', borderRadius: '16px', border: '2px solid #e2e8f0' }}>
              <p style={{ fontSize: '0.8rem', color: '#64748b', fontWeight: 600 }}>託管物件</p>
              <p style={{ fontFamily: 'monospace', fontSize: '0.85rem', marginBottom: '0.75rem', wordBreak: 'break-all' }}>{selected.escrow_object_id || '—'}</p>
              <p style={{ fontSize: '0.8rem', color: '#64748b', fontWeight: 600 }}>爭議物件</p>
              <p style={{ fontFamily: 'monospace', fontSize: '0.85rem', wordBreak: 'break-all', color: selected.dispute_object_id ? '#0f172a' : '#dc2626' }}>
                {selected.dispute_object_id || '未回報（無法裁決）'}
              </p>
            </div>

            {/* 判決選擇 */}
            <div style={{ marginBottom: '1.5rem', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
              <button
                onClick={() => setRuling(RULING_DRIVER)}
                style={{
                  padding: '1.25rem', borderRadius: '14px', cursor: 'pointer', textAlign: 'left',
                  border: ruling === RULING_DRIVER ? '2px solid #2563eb' : '2px solid #e2e8f0',
                  background: ruling === RULING_DRIVER ? '#eff6ff' : 'white',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', fontWeight: 800, color: '#1e40af' }}>
                  <Car size={20} /> 判給司機
                </div>
                <p style={{ fontSize: '0.8rem', color: '#64748b', marginTop: '0.4rem' }}>釋放託管給司機+平台（已提供服務）</p>
              </button>
              <button
                onClick={() => setRuling(RULING_PASSENGER)}
                style={{
                  padding: '1.25rem', borderRadius: '14px', cursor: 'pointer', textAlign: 'left',
                  border: ruling === RULING_PASSENGER ? '2px solid #16a34a' : '2px solid #e2e8f0',
                  background: ruling === RULING_PASSENGER ? '#f0fdf4' : 'white',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', fontWeight: 800, color: '#15803d' }}>
                  <User size={20} /> 退乘客
                </div>
                <p style={{ fontSize: '0.8rem', color: '#64748b', marginTop: '0.4rem' }}>全額退還乘客</p>
              </button>
            </div>

            {/* 備註 */}
            <div style={{ marginBottom: '2rem' }}>
              <label style={{ display: 'block', fontSize: '0.875rem', fontWeight: 700, color: '#334155', marginBottom: '0.5rem' }}>裁決說明（選填）</label>
              <textarea
                value={note}
                onChange={(e) => setNote(e.target.value)}
                className="input-field"
                placeholder="說明裁決理由"
                rows="3"
                disabled={submitting}
                style={{ resize: 'vertical' }}
              />
            </div>

            <div style={{ display: 'flex', gap: '1rem', alignItems: 'center' }}>
              <button onClick={() => setModalOpen(false)} className="btn btn-secondary" disabled={submitting} style={{ flex: 1 }}>取消</button>
              <button onClick={handleResolve} className="btn btn-primary" disabled={submitting || !selected.dispute_object_id} style={{ flex: 2, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: '0.5rem' }}>
                <Shield size={18} /> {submitting ? '上鏈裁決中...' : '確認裁決並上鏈'}
              </button>
            </div>
          </div>
        </div>
      )}
    </Layout>
  );
};

export default DisputeManagement;
