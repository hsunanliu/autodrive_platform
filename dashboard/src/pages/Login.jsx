import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { authAPI } from '../services/api';
import { Lock, Mail, AlertCircle, Shield, Zap } from 'lucide-react';

const Login = () => {
  const navigate = useNavigate();
  const [formData, setFormData] = useState({ email: '', password: '' });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleChange = (e) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
    setError('');
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const response = await authAPI.login(formData);
      localStorage.setItem('adminToken', response.data.token);
      localStorage.setItem('adminData', JSON.stringify(response.data.admin));
      navigate('/dashboard');
    } catch (err) {
      setError(err.response?.data?.error || '登入失敗，請稍後再試');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{
      minHeight: '100vh',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      padding: '1.5rem',
      background: 'linear-gradient(135deg, #1e40af 0%, #3b82f6 50%, #0ea5e9 100%)',
      position: 'relative',
      overflow: 'hidden'
    }}>
      <div style={{
        position: 'absolute',
        top: '-200px',
        right: '-200px',
        width: '500px',
        height: '500px',
        background: 'rgba(255, 255, 255, 0.1)',
        borderRadius: '50%',
        filter: 'blur(80px)'
      }}></div>
      <div style={{
        position: 'absolute',
        bottom: '-200px',
        left: '-200px',
        width: '500px',
        height: '500px',
        background: 'rgba(255, 255, 255, 0.1)',
        borderRadius: '50%',
        filter: 'blur(80px)'
      }}></div>

      <div style={{ maxWidth: '480px', width: '100%', position: 'relative', zIndex: 10 }} className="scale-in">
        <div style={{ textAlign: 'center', marginBottom: '2.5rem' }}>
          <div style={{
            display: 'inline-flex',
            alignItems: 'center',
            justifyContent: 'center',
            width: '80px',
            height: '80px',
            background: 'white',
            borderRadius: '24px',
            marginBottom: '1.5rem',
            boxShadow: '0 20px 40px rgba(0, 0, 0, 0.2)'
          }}>
            <Shield size={48} color="#2563eb" />
          </div>
          <h1 style={{
            fontSize: '3rem',
            fontWeight: '900',
            color: 'white',
            marginBottom: '0.75rem',
            textShadow: '0 2px 4px rgba(0, 0, 0, 0.1)'
          }}>
            自駕計程車
          </h1>
          <p style={{ fontSize: '1.25rem', color: 'rgba(255, 255, 255, 0.9)', fontWeight: '600' }}>
            管理平台系統
          </p>
        </div>

        <div style={{
          background: 'white',
          borderRadius: '24px',
          padding: '2.5rem',
          boxShadow: '0 25px 50px rgba(0, 0, 0, 0.25)'
        }}>
          <div style={{ marginBottom: '2rem' }}>
            <h2 style={{ fontSize: '2rem', fontWeight: '800', color: '#0f172a', marginBottom: '0.5rem' }}>
              歡迎回來
            </h2>
            <p style={{ color: '#64748b', fontSize: '1rem', fontWeight: '500' }}>
              請登入您的管理員帳號
            </p>
          </div>

          <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
            {error && (
              <div style={{
                background: 'linear-gradient(135deg, #fee2e2 0%, #fecaca 100%)',
                border: '2px solid #ef4444',
                color: '#991b1b',
                padding: '1rem',
                borderRadius: '12px',
                display: 'flex',
                alignItems: 'center',
                gap: '0.75rem',
                fontWeight: '600'
              }} className="scale-in">
                <AlertCircle size={20} />
                <span>{error}</span>
              </div>
            )}

            <div>
              <label style={{
                display: 'block',
                fontSize: '0.875rem',
                fontWeight: '700',
                color: '#334155',
                marginBottom: '0.5rem'
              }}>
                電子郵件
              </label>
              <div style={{ position: 'relative' }}>
                <Mail style={{
                  position: 'absolute',
                  left: '1rem',
                  top: '50%',
                  transform: 'translateY(-50%)',
                  color: '#94a3b8'
                }} size={20} />
                <input
                  type="email"
                  name="email"
                  value={formData.email}
                  onChange={handleChange}
                  className="input-field"
                  placeholder="admin@example.com"
                  style={{ paddingLeft: '3rem' }}
                  required
                />
              </div>
            </div>

            <div>
              <label style={{
                display: 'block',
                fontSize: '0.875rem',
                fontWeight: '700',
                color: '#334155',
                marginBottom: '0.5rem'
              }}>
                密碼
              </label>
              <div style={{ position: 'relative' }}>
                <Lock style={{
                  position: 'absolute',
                  left: '1rem',
                  top: '50%',
                  transform: 'translateY(-50%)',
                  color: '#94a3b8'
                }} size={20} />
                <input
                  type="password"
                  name="password"
                  value={formData.password}
                  onChange={handleChange}
                  className="input-field"
                  placeholder="••••••••"
                  style={{ paddingLeft: '3rem' }}
                  required
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="btn btn-primary"
              style={{ fontSize: '1rem', padding: '1rem' }}
            >
              {loading ? (
                <>
                  <div className="spinner" style={{ width: '20px', height: '20px', borderWidth: '3px' }} />
                  <span>登入中...</span>
                </>
              ) : (
                <>
                  <Shield size={20} />
                  <span>安全登入</span>
                </>
              )}
            </button>
          </form>

          <div style={{
            marginTop: '2rem',
            padding: '1.25rem',
            background: 'linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%)',
            borderRadius: '16px',
            border: '1px solid #bae6fd'
          }}>
            <div style={{ display: 'flex', alignItems: 'start', gap: '0.75rem' }}>
              <Zap size={20} color="#0284c7" style={{ flexShrink: 0, marginTop: '2px' }} />
              <div>
                <p style={{ fontWeight: '700', color: '#0c4a6e', marginBottom: '0.25rem', fontSize: '0.875rem' }}>
                  測試帳號
                </p>
                <p style={{ fontSize: '0.8125rem', color: '#075985', marginBottom: '0.5rem' }}>
                  請使用 API 創建管理員帳號
                </p>
                <code style={{
                  fontSize: '0.75rem',
                  background: 'white',
                  padding: '0.375rem 0.75rem',
                  borderRadius: '6px',
                  color: '#0284c7',
                  fontFamily: 'monospace',
                  fontWeight: '600',
                  display: 'inline-block'
                }}>
                  POST /api/auth/create-admin
                </code>
              </div>
            </div>
          </div>
        </div>

        <p style={{
          textAlign: 'center',
          marginTop: '2rem',
          color: 'white',
          fontSize: '0.875rem',
          fontWeight: '500',
          textShadow: '0 1px 2px rgba(0, 0, 0, 0.1)'
        }}>
          © 2025 自駕計程車管理平台
        </p>
      </div>
    </div>
  );
};

export default Login;