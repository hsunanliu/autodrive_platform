import React from 'react';
import Header from './Header';

const Layout = ({ children }) => {
  return (
    <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column', background: '#f8fafc' }}>
      <Header />
      <main style={{ flex: 1 }}>
        <div style={{ padding: '2rem 1.5rem', maxWidth: '1600px', margin: '0 auto' }}>
          {children}
        </div>
      </main>
    </div>
  );
};

export default Layout;
