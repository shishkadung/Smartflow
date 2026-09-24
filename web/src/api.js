const API_BASE = (import.meta.env.VITE_API_BASE || '/smartflow-api').replace(/\/+$/, '')

export class ApiError extends Error {
  constructor(message, status = 0, extra = {}) {
    super(message)
    this.status = status
    this.scanError = extra.scan_error || extra.scanError || null
    this.qrError = extra.qr_error || extra.qrError || null
    this.data = extra
  }
}

function buildUrl(path, query) {
  let url = `${API_BASE}/${String(path).replace(/^\/+/, '')}`
  const params = new URLSearchParams()
  if (query) {
    Object.entries(query).forEach(([key, value]) => {
      if (value !== undefined && value !== null && value !== '') {
        params.set(key, String(value))
      }
    })
  }
  const qs = params.toString()
  if (qs) url += `?${qs}`
  return url
}

export async function api(path, { method = 'GET', body, auth = true, query } = {}) {
  const token = localStorage.getItem('sf_token')
  const headers = { Accept: 'application/json' }
  if (body) headers['Content-Type'] = 'application/json'
  const payload = body ? { ...body } : null
  if (auth && token) {
    headers.Authorization = `Bearer ${token}`
    headers['X-Authorization'] = `Bearer ${token}`
    headers['X-Smartflow-Token'] = token
  }

  const q = { ...(query || {}) }
  if (auth && token) q.access_token = token
  if (auth && token && payload) payload.access_token = token

  const res = await fetch(buildUrl(path, q), {
    method,
    headers,
    body: payload ? JSON.stringify(payload) : undefined,
  })

  const text = await res.text()
  let data
  try {
    data = JSON.parse(text)
  } catch {
    throw new ApiError(
      text.includes('Fatal error')
        ? 'API crashed. Check XAMPP Apache and sync the backend.'
        : 'Invalid server response',
      res.status,
    )
  }

  if (!res.ok || data.success === false) {
    throw new ApiError(data.message || 'Request failed', res.status, data)
  }
  return data
}

/** Multipart upload (profile photo). Do not set Content-Type — browser sets boundary. */
export async function apiUpload(path, formData, { auth = true } = {}) {
  const token = localStorage.getItem('sf_token')
  const headers = { Accept: 'application/json' }
  if (auth && token) {
    headers.Authorization = `Bearer ${token}`
    headers['X-Authorization'] = `Bearer ${token}`
    headers['X-Smartflow-Token'] = token
  }
  const q = {}
  if (auth && token) q.access_token = token

  const res = await fetch(buildUrl(path, q), {
    method: 'POST',
    headers,
    body: formData,
  })

  const text = await res.text()
  let data
  try {
    data = JSON.parse(text)
  } catch {
    throw new ApiError('Invalid server response', res.status)
  }
  if (!res.ok || data.success === false) {
    throw new ApiError(data.message || 'Upload failed', res.status, data)
  }
  return data
}

export function avatarUrl(userOrPath) {
  if (!userOrPath) return null
  const rel = typeof userOrPath === 'string' ? userOrPath : userOrPath.avatar_url
  if (!rel) return null
  if (/^https?:\/\//i.test(rel)) return rel
  return `${API_BASE}/${String(rel).replace(/^\/+/, '')}`
}

export const smartflow = {
  login: (username, password) =>
    api('auth-login.php', { method: 'POST', auth: false, body: { username, password } }),
  signup: (body) =>
    api('auth-signup.php', { method: 'POST', auth: false, body }),
  forgotPassword: (username) =>
    api('auth-forgot-password.php', { method: 'POST', auth: false, body: { username } }),
  resetPassword: (body) =>
    api('auth-reset-password.php', { method: 'POST', auth: false, body }),
  changePassword: (currentPassword, newPassword) =>
    api('users-change-password.php', {
      method: 'POST',
      body: { current_password: currentPassword, new_password: newPassword },
    }),
  updateProfile: (name, username, email) =>
    api('users-profile-update.php', {
      method: 'POST',
      body: { name, username, email },
    }),
  uploadAvatar: (file) => {
    const fd = new FormData()
    fd.append('avatar', file)
    return apiUpload('users-avatar-upload.php', fd)
  },
  removeAvatar: () => {
    const fd = new FormData()
    fd.append('remove', '1')
    return apiUpload('users-avatar-upload.php', fd)
  },
  offices: () => api('offices-list.php', { auth: false }),
  dashboardStats: (officeId) =>
    api('dashboard-stats.php', { query: { office_id: officeId } }),
  headDashboard: (officeId) =>
    api('head-dashboard.php', { query: { office_id: officeId } }),
  headAnalytics: (officeId, month) =>
    api('head-analytics.php', { query: { office_id: officeId, month } }),
  accountantDashboard: () => api('accountant-dashboard.php'),
  alerts: (officeId) => api('alerts-list.php', { query: { office_id: officeId } }),
  accountantAlerts: () => api('accountant-alerts.php'),
  documentShow: (id) => api('documents-show.php', { query: { id } }),
  documentMovements: (id) => api('documents-movements.php', { query: { id } }),
  verifyQr: (qr) => api('qr-verify.php', { method: 'POST', body: { qr } }),
  createDocument: (body) => api('documents-create.php', { method: 'POST', body }),
  recordMovement: (body) => api('movements-create.php', { method: 'POST', body }),
  reportsSummary: (officeId, month) =>
    api('reports-summary.php', { query: { office_id: officeId, month } }),

  documentRequestsList: (view, status) =>
    api('document-requests-list.php', { query: { view, ...(status ? { status } : {}) } }),
  documentRequestCreate: (body) =>
    api('document-requests-create.php', { method: 'POST', body }),
  documentRequestUpdate: (body) =>
    api('document-requests-update.php', { method: 'POST', body }),

  usersList: () => api('users-list.php'),
  setUserActive: (userId, active) =>
    api('users-set-active.php', { method: 'POST', body: { user_id: userId, active } }),
  signupPending: () => api('signup-pending-list.php'),
  signupApprove: (requestId, action) =>
    api('signup-approve.php', { method: 'POST', body: { request_id: requestId, action } }),
  adminOffices: () => api('admin-offices.php'),
  updateThreshold: (body) =>
    api('admin-thresholds-update.php', { method: 'POST', body }),
  systemStatus: () => api('system-status.php'),
  auditExceptions: (hours = 24) =>
    api('audit-exceptions.php', { query: { hours } }),
  auditScans: ({ hours = 48, outcome = 'all', limit = 200 } = {}) =>
    api('audit-scans.php', { query: { hours, outcome, limit } }),

  qrLabelUrl: (documentId, token) => {
    const q = new URLSearchParams({ id: documentId })
    if (token) q.set('token', token)
    return `${API_BASE}/qr-label.php?${q}`
  },
}
