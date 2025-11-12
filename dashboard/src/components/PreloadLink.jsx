// dashboard/src/components/PreloadLink.jsx
import React from 'react';
import { Link } from 'react-router-dom';
import { preloadRoute } from '../utils/routePreloader';

/**
 * PreloadLink Component
 *
 * Enhanced Link component that preloads route components on hover/focus
 * for improved perceived performance
 */
const PreloadLink = ({ to, children, onMouseEnter, onFocus, ...props }) => {
  const handleMouseEnter = (e) => {
    preloadRoute(to);
    if (onMouseEnter) {
      onMouseEnter(e);
    }
  };

  const handleFocus = (e) => {
    preloadRoute(to);
    if (onFocus) {
      onFocus(e);
    }
  };

  return (
    <Link
      to={to}
      onMouseEnter={handleMouseEnter}
      onFocus={handleFocus}
      {...props}
    >
      {children}
    </Link>
  );
};

export default PreloadLink;
