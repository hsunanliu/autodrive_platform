// dashboard/src/utils/routePreloader.js

/**
 * Route Preloader
 *
 * Preloads route components on hover/focus to improve perceived performance
 */

const preloadedRoutes = new Set();

export const preloadRoute = (routePath) => {
  if (preloadedRoutes.has(routePath)) {
    return Promise.resolve();
  }

  const routeMap = {
    '/dashboard': () => import('../pages/Dashboard'),
    '/refunds': () => import('../pages/RefundManagement'),
    '/vehicles': () => import('../pages/VehicleManagement'),
    '/users': () => import('../pages/UserManagement'),
    '/trips': () => import('../pages/TripDetails'),
    '/orders': () => import('../pages/OrderCenter'),
  };

  const loadRoute = routeMap[routePath];
  if (!loadRoute) {
    console.warn(`No preload function found for route: ${routePath}`);
    return Promise.resolve();
  }

  preloadedRoutes.add(routePath);
  return loadRoute().catch((error) => {
    console.error(`Failed to preload route ${routePath}:`, error);
    preloadedRoutes.delete(routePath); // Remove from set if failed
  });
};

export const preloadAllRoutes = () => {
  const routes = ['/dashboard', '/refunds', '/vehicles', '/users', '/trips', '/orders'];
  return Promise.all(routes.map(preloadRoute));
};

export const clearPreloadCache = () => {
  preloadedRoutes.clear();
};

export default { preloadRoute, preloadAllRoutes, clearPreloadCache };
