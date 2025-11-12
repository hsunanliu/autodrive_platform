// dashboard/src/components/SkeletonLoader.jsx
import React from 'react';
import './PageTransition.css'; // Uses skeleton styles from PageTransition.css

/**
 * Skeleton Loader Component
 *
 * Displays placeholder loading states for different content types
 */

export const SkeletonText = ({ width = '100%' }) => (
  <div className="skeleton skeleton-text" style={{ width }} />
);

export const SkeletonTitle = ({ width = '60%' }) => (
  <div className="skeleton skeleton-title" style={{ width }} />
);

export const SkeletonCard = () => (
  <div className="skeleton skeleton-card" />
);

export const SkeletonTable = ({ rows = 5, columns = 4 }) => (
  <div style={{ padding: '20px' }}>
    {[...Array(rows)].map((_, rowIndex) => (
      <div key={rowIndex} style={{ display: 'flex', gap: '16px', marginBottom: '12px' }}>
        {[...Array(columns)].map((_, colIndex) => (
          <div
            key={colIndex}
            className="skeleton"
            style={{
              flex: 1,
              height: '40px',
              borderRadius: '6px'
            }}
          />
        ))}
      </div>
    ))}
  </div>
);

export const SkeletonDashboard = () => (
  <div style={{ padding: '24px' }}>
    {/* Title */}
    <SkeletonTitle width="40%" />

    {/* Stats Cards */}
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))', gap: '20px', marginTop: '24px' }}>
      <SkeletonCard />
      <SkeletonCard />
      <SkeletonCard />
      <SkeletonCard />
    </div>

    {/* Content Section */}
    <div style={{ marginTop: '32px' }}>
      <SkeletonTitle width="30%" />
      <div style={{ marginTop: '16px' }}>
        <SkeletonTable rows={8} columns={5} />
      </div>
    </div>
  </div>
);

export const SkeletonList = ({ items = 5 }) => (
  <div style={{ padding: '20px' }}>
    {[...Array(items)].map((_, index) => (
      <div key={index} style={{ marginBottom: '16px', padding: '16px', border: '1px solid #e2e8f0', borderRadius: '8px' }}>
        <SkeletonTitle width="50%" />
        <SkeletonText width="80%" />
        <SkeletonText width="60%" />
      </div>
    ))}
  </div>
);

const SkeletonLoader = {
  Text: SkeletonText,
  Title: SkeletonTitle,
  Card: SkeletonCard,
  Table: SkeletonTable,
  Dashboard: SkeletonDashboard,
  List: SkeletonList,
};

export default SkeletonLoader;
