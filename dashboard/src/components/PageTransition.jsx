// dashboard/src/components/PageTransition.jsx
import React, { useEffect, useState } from 'react';
import { useLocation } from 'react-router-dom';
import { Loader2 } from 'lucide-react';
import './PageTransition.css';

/**
 * Page Transition Component
 *
 * Provides smooth fade-in/fade-out transitions between pages
 * with optional loading state
 */
const PageTransition = ({ children, loading = false }) => {
  const location = useLocation();
  const [displayLocation, setDisplayLocation] = useState(location);
  const [transitionStage, setTransitionStage] = useState('fadeIn');

  useEffect(() => {
    if (location !== displayLocation) {
      setTransitionStage('fadeOut');
    }
  }, [location, displayLocation]);

  const onAnimationEnd = () => {
    if (transitionStage === 'fadeOut') {
      setTransitionStage('fadeIn');
      setDisplayLocation(location);
    }
  };

  if (loading) {
    return (
      <div className="page-loading">
        <div className="loading-spinner">
          <Loader2 className="spinner-icon" />
          <p>載入中...</p>
        </div>
      </div>
    );
  }

  return (
    <div
      className={`page-transition ${transitionStage}`}
      onAnimationEnd={onAnimationEnd}
    >
      {children}
    </div>
  );
};

export default PageTransition;
