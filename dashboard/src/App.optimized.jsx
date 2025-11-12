// dashboard/src/App.optimized.jsx
import React, { Suspense, lazy } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import ProtectedRoute from './components/ProtectedRoute';
import PageTransition from './components/PageTransition';
import { SkeletonDashboard } from './components/SkeletonLoader';
import './App.css';

// Eager load Login (needed immediately)
import Login from './pages/Login';

// Lazy load other pages
const Dashboard = lazy(() => import('./pages/Dashboard'));
const RefundManagement = lazy(() => import('./pages/RefundManagement'));
const VehicleManagement = lazy(() => import('./pages/VehicleManagement'));
const UserManagement = lazy(() => import('./pages/UserManagement'));
const TripDetails = lazy(() => import('./pages/TripDetails'));
const OrderCenter = lazy(() => import('./pages/OrderCenter'));

// Fallback component for Suspense
const PageLoader = () => (
  <PageTransition loading={true}>
    <SkeletonDashboard />
  </PageTransition>
);

function App() {
  return (
    <Router>
      <Suspense fallback={<PageLoader />}>
        <Routes>
          <Route path="/login" element={<Login />} />

          <Route
            path="/dashboard"
            element={
              <ProtectedRoute>
                <PageTransition>
                  <Dashboard />
                </PageTransition>
              </ProtectedRoute>
            }
          />

          <Route
            path="/refunds"
            element={
              <ProtectedRoute>
                <PageTransition>
                  <RefundManagement />
                </PageTransition>
              </ProtectedRoute>
            }
          />

          <Route
            path="/vehicles"
            element={
              <ProtectedRoute>
                <PageTransition>
                  <VehicleManagement />
                </PageTransition>
              </ProtectedRoute>
            }
          />

          <Route
            path="/users"
            element={
              <ProtectedRoute>
                <PageTransition>
                  <UserManagement />
                </PageTransition>
              </ProtectedRoute>
            }
          />

          <Route
            path="/trips"
            element={
              <ProtectedRoute>
                <PageTransition>
                  <TripDetails />
                </PageTransition>
              </ProtectedRoute>
            }
          />

          <Route
            path="/orders"
            element={
              <ProtectedRoute>
                <PageTransition>
                  <OrderCenter />
                </PageTransition>
              </ProtectedRoute>
            }
          />

          <Route path="/" element={<Navigate to="/dashboard" replace />} />
          <Route path="*" element={<Navigate to="/dashboard" replace />} />
        </Routes>
      </Suspense>
    </Router>
  );
}

export default App;
