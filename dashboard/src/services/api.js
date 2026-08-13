import axios from 'axios';

const API_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000/api/v1/admin';

const api = axios.create({
  baseURL: API_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('adminToken');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('adminToken');
      localStorage.removeItem('adminData');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

// 非 /admin 前綴的端點（爭議仲裁、鏈上退款核准）也用同一把 admin token
const ROOT_URL = API_URL.replace(/\/admin$/, '');
const rootApi = axios.create({
  baseURL: ROOT_URL,
  headers: { 'Content-Type': 'application/json' },
});
rootApi.interceptors.request.use((config) => {
  const token = localStorage.getItem('adminToken');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});
rootApi.interceptors.response.use(
  (r) => r,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('adminToken');
      localStorage.removeItem('adminData');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

export const authAPI = {
  login: (credentials) => api.post('/auth/login', credentials),
  createAdmin: (data) => api.post('/auth/create-admin', data),
};

// 爭議仲裁（鏈上）：resolve 由平台 ArbiterCap 執行；列表沿用 admin trips
export const disputeAPI = {
  getDisputed: () => api.get('/trips', {
    params: { status: 'disputed' },
    paramsSerializer: (p) => Object.entries(p)
      .filter(([, v]) => v !== undefined && v !== null && v !== '')
      .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`).join('&'),
  }),
  // ruling: 1 判給司機（release）/ 2 退乘客（refund）
  resolve: (tripId, ruling, adminNote = null) =>
    rootApi.post(`/trips/${tripId}/resolve-dispute`, { ruling, admin_note: adminNote }),
};

// 鏈上退款核准/拒絕（refund_module_v2::admin_refund_from_pool）
export const refundChainAPI = {
  approve: (refundId, adminNote = null) =>
    rootApi.post(`/refunds/${refundId}/approve`, { admin_note: adminNote }),
  reject: (refundId, adminNote = null) =>
    rootApi.post(`/refunds/${refundId}/reject`, { admin_note: adminNote }),
};

export const dashboardAPI = {
  getTotals: () => api.get('/dashboard/totals'),
  getRevenue: (type, params = {}) => api.get(`/dashboard/revenue/${type}`, { params }),
  getTotalRevenue: (params = {}) => api.get('/dashboard/total-revenue', { params }),
  getRevenueGrowth: (type, baseDate = null) => {
    const params = baseDate ? { baseDate } : {};
    return api.get(`/dashboard/growth/${type}`, { params });
  },
  getRevenueDistribution: () => api.get('/dashboard/revenue-distribution'),
  getPaymentDistribution: () => api.get('/dashboard/payment-distribution'),
};

export const refundAPI = {
  getAll: (params) => {
    console.log('refundAPI.getAll 調用，參數:', params);
    return api.get('/refunds', { 
      params,
      paramsSerializer: params => {
        // 手動序列化參數，避免嵌套問題
        const query = Object.entries(params)
          .filter(([_, value]) => value !== undefined && value !== null && value !== '')
          .map(([key, value]) => `${encodeURIComponent(key)}=${encodeURIComponent(value)}`)
          .join('&');
        console.log('序列化後的查詢字符串:', query);
        return query;
      }
    });
  },
  update: (id, data) => api.put(`/refunds/${id}`, data),
};

export const vehicleAPI = {
  getAll: (params) => api.get('/vehicles', { params }),
  getById: (id) => api.get(`/vehicles/${id}`),
  updateStatus: (id, status) => api.put(`/vehicles/${id}/status`, { status }),
};

export const userAPI = {
  getAll: (type) => api.get('/users', { params: { type } }),
  getById: (type, id) => api.get(`/users/${type}/${id}`),
  getVehicles: (id) => api.get(`/users/driver/${id}/vehicles`),
  getTrips: (id) => api.get(`/users/rider/${id}/trips`),
};

export const tripAPI = {
  getAll: (params) => {
    console.log('tripAPI.getAll 調用，參數:', params);
    return api.get('/trips', { 
      params,
      paramsSerializer: params => {
        // 手動序列化參數，避免嵌套
        const query = Object.entries(params)
          .filter(([_, value]) => value !== undefined && value !== null && value !== '')
          .map(([key, value]) => `${encodeURIComponent(key)}=${encodeURIComponent(value)}`)
          .join('&');
        console.log('序列化後的查詢字符串:', query);
        return query;
      }
    });
  },
  getById: (id) => api.get(`/trips/${id}`),
  updateStatus: (id, status) => api.put(`/trips/${id}/status`, { status }),
};
    
export default api;
