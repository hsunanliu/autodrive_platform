import React, { useState } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import {
  LayoutDashboard,
  RefreshCcw,
  Car,
  Users,
  Map,
  LogOut,
  Menu,
  X,
  Shield,
} from 'lucide-react';

const Header = () => {
  const location = useLocation();
  const navigate = useNavigate();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [windowWidth, setWindowWidth] = useState(typeof window !== 'undefined' ? window.innerWidth : 1024);

  React.useEffect(() => {
    const handleResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  const menuItems = [
    { path: '/dashboard', icon: LayoutDashboard, label: '儀表板' },
    { path: '/refunds', icon: RefreshCcw, label: '退款管理' },
    { path: '/vehicles', icon: Car, label: '車輛管理' },
    { path: '/users', icon: Users, label: '使用者管理' },
    { path: '/trips', icon: Map, label: '行程管理' },
  ];

  const handleLogout = () => {
    localStorage.removeItem('adminToken');
    localStorage.removeItem('adminData');
    navigate('/login');
  };

  const adminData = JSON.parse(localStorage.getItem('adminData') || '{}');
  const isDesktop = windowWidth >= 1024;

  return (
    <header
      style={{
        background: 'linear-gradient(135deg, #1e40af 0%, #3b82f6 100%)',
        boxShadow: '0 4px 20px rgba(0, 0, 0, 0.15)',
        position: 'sticky',
        top: 0,
        zIndex: 1000,
      }}
    >
      <div
        style={{
          maxWidth: '1800px',
          margin: '0 auto',
          padding: '0 1.5rem',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          minHeight: '75px',
          gap: '2rem',
        }}
      >
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '0.75rem',
            flexShrink: 0,
          }}
        >
          <div
            style={{
              padding: '10px',
              background: 'rgba(255, 255, 255, 0.2)',
              borderRadius: '14px',
              backdropFilter: 'blur(10px)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              border: '2px solid rgba(255, 255, 255, 0.3)',
            }}
          >
            <Shield size={30} color="white" />
          </div>
          <div>
            <h1
              style={{
                fontSize: '1.5rem',
                fontWeight: '900',
                color: 'white',
                lineHeight: '1.2',
                marginBottom: '2px',
              }}
            >
              自駕計程車
            </h1>
            <p
              style={{
                fontSize: '0.75rem',
                color: 'rgba(255, 255, 255, 0.95)',
                fontWeight: '600',
              }}
            >
              管理系統
            </p>
          </div>
        </div>

        {isDesktop && (
          <nav
            style={{
              display: 'flex',
              flex: 1,
              justifyContent: 'center',
            }}
          >
            <div
              style={{
                display: 'flex',
                gap: '0.75rem',
                alignItems: 'center',
              }}
            >
              {menuItems.map((item) => {
                const Icon = item.icon;
                const isActive = location.pathname === item.path;

                return (
                  <Link
                    key={item.path}
                    to={item.path}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: '0.625rem',
                      padding: '0.875rem 1.5rem',
                      borderRadius: '14px',
                      transition: 'all 0.2s ease',
                      background: isActive ? 'rgba(255, 255, 255, 0.25)' : 'transparent',
                      backdropFilter: isActive ? 'blur(10px)' : 'none',
                      fontWeight: isActive ? '800' : '600',
                      fontSize: '1rem',
                      textDecoration: 'none',
                      color: 'white',
                      border: isActive ? '2px solid rgba(255, 255, 255, 0.4)' : '2px solid transparent',
                      boxShadow: isActive ? '0 4px 12px rgba(0, 0, 0, 0.15)' : 'none',
                    }}
                    onMouseEnter={(e) => {
                      if (!isActive) {
                        e.currentTarget.style.background = 'rgba(255, 255, 255, 0.15)';
                        e.currentTarget.style.transform = 'translateY(-2px)';
                      }
                    }}
                    onMouseLeave={(e) => {
                      if (!isActive) {
                        e.currentTarget.style.background = 'transparent';
                        e.currentTarget.style.transform = 'translateY(0)';
                      }
                    }}
                  >
                    <Icon size={22} strokeWidth={2.5} />
                    <span style={{ whiteSpace: 'nowrap' }}>{item.label}</span>
                  </Link>
                );
              })}
            </div>
          </nav>
        )}

        {isDesktop && (
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '1rem',
              flexShrink: 0,
            }}
          >
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '0.75rem',
                padding: '0.625rem 1.25rem',
                background: 'rgba(255, 255, 255, 0.15)',
                backdropFilter: 'blur(10px)',
                borderRadius: '14px',
                border: '2px solid rgba(255, 255, 255, 0.2)',
              }}
            >
              <div
                style={{
                  width: '42px',
                  height: '42px',
                  borderRadius: '11px',
                  background: 'linear-gradient(135deg, #ffffff 0%, #e0e7ff 100%)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: '1.125rem',
                  fontWeight: '900',
                  color: '#1e40af',
                  boxShadow: '0 2px 8px rgba(0, 0, 0, 0.15)',
                }}
              >
                {adminData.name?.charAt(0) || 'A'}
              </div>
              <div style={{ textAlign: 'left' }}>
                <p
                  style={{
                    fontWeight: '800',
                    fontSize: '0.9375rem',
                    lineHeight: '1.2',
                    color: 'white',
                  }}
                >
                  {adminData.name || '管理員'}
                </p>
                <p
                  style={{
                    fontSize: '0.75rem',
                    color: 'rgba(255, 255, 255, 0.8)',
                    fontWeight: '600',
                  }}
                >
                  {adminData.email || 'admin@example.com'}
                </p>
              </div>
            </div>

            <button
              onClick={handleLogout}
              className="btn btn-secondary"
              style={{ display: 'inline-flex', alignItems: 'center', gap: '0.5rem' }}
            >
              <LogOut size={18} />
              登出
            </button>
          </div>
        )}

        {!isDesktop && (
          <button
            onClick={() => setMobileMenuOpen((prev) => !prev)}
            style={{
              background: 'rgba(255, 255, 255, 0.2)',
              border: '2px solid rgba(255, 255, 255, 0.3)',
              padding: '0.75rem',
              borderRadius: '14px',
              color: 'white',
              display: 'flex',
            }}
          >
            {mobileMenuOpen ? <X size={22} /> : <Menu size={22} />}
          </button>
        )}
      </div>

      {!isDesktop && mobileMenuOpen && (
        <div
          style={{
            padding: '1rem 1.5rem 2rem',
            display: 'flex',
            flexDirection: 'column',
            gap: '1rem',
            background: 'rgba(255, 255, 255, 0.1)',
            backdropFilter: 'blur(10px)',
          }}
        >
          {menuItems.map((item) => {
            const Icon = item.icon;
            const isActive = location.pathname === item.path;
            return (
              <Link
                key={item.path}
                to={item.path}
                onClick={() => setMobileMenuOpen(false)}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '0.75rem',
                  padding: '0.85rem 1.1rem',
                  borderRadius: '12px',
                  background: isActive ? 'rgba(255, 255, 255, 0.2)' : 'transparent',
                  color: 'white',
                  textDecoration: 'none',
                  fontWeight: isActive ? '700' : '600',
                  border: isActive ? '2px solid rgba(255, 255, 255, 0.3)' : '2px solid transparent',
                }}
              >
                <Icon size={20} />
                {item.label}
              </Link>
            );
          })}

          <button
            onClick={() => {
              setMobileMenuOpen(false);
              handleLogout();
            }}
            className="btn btn-secondary"
            style={{ justifyContent: 'center' }}
          >
            <LogOut size={18} />
            登出
          </button>
        </div>
      )}
    </header>
  );
};

export default Header;
