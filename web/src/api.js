import { portalFetch } from './connection.js'
import { submitCreation } from './creation-recovery.js'

const API_BASE = (import.meta.env?.VITE_API_BASE || '/smartflow-api').replace(/\/+$/, '')

function handleSessionFailure(res, data, auth, token) {
  if (!auth || !token || localStorage.getItem('sf_token') !== token) return
  if (res.status === 401 || (res.status === 403 && /deactivated/i.test(data.message || ''))) {
    window.dispatchEvent(new CustomEvent('sf-session-invalid', { detail: { token, message: data.message, status: res.status } }))
  }
}

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

function requireCurrentSession(token, inFlight = false) {
  if (!token || localStorage.getItem('sf_token') !== token) {
    throw new ApiError(inFlight
      ? 'Your signed-in account changed while the request was running. Check its outcome in the original account before trying again.'
      : 'Your signed-in account changed. Review this action again in the current account.', 409, { session_changed: true })
  }
}

export async function api(path, { method = 'GET', body, auth = true, query, token = localStorage.getItem('sf_token'), sessionBound = false } = {}) {
  if (auth && sessionBound) requireCurrentSession(token)
  const headers = { Accept: 'application/json' }
  if (body) headers['Content-Type'] = 'application/json'
  const payload = body ? { ...body } : null
  if (auth && token) {
    headers.Authorization = `Bearer ${token}`
    headers['X-Authorization'] = `Bearer ${token}`
    headers['X-Smartflow-Token'] = token
  }

  const res = await portalFetch(buildUrl(path, query), {
    method,
    headers,
    body: payload ? JSON.stringify(payload) : undefined,
  })

  const text = await res.text()
  if (auth && sessionBound) requireCurrentSession(token, true)
  let data
  try {
    data = JSON.parse(text)
  } catch {
    handleSessionFailure(res, {}, auth, token)
    throw new ApiError(
      text.includes('Fatal error')
        ? 'API crashed. Check XAMPP Apache and sync the backend.'
        : 'Invalid server response',
      res.status,
    )
  }

  if (!res.ok || data.success === false) {
    handleSessionFailure(res, data, auth, token)
    throw new ApiError(data.message || 'Request failed', res.status, data)
  }
  return data
}

/** Multipart upload (profile photo). Do not set Content-Type — browser sets boundary. */
export async function apiUpload(path, formData, { auth = true, token = localStorage.getItem('sf_token'), sessionBound = false } = {}) {
  if (auth && sessionBound) requireCurrentSession(token)
  const headers = { Accept: 'application/json' }
  if (auth && token) {
    headers.Authorization = `Bearer ${token}`
    headers['X-Authorization'] = `Bearer ${token}`
    headers['X-Smartflow-Token'] = token
  }
  const res = await portalFetch(buildUrl(path), {
    method: 'POST',
    headers,
    body: formData,
  })

  const text = await res.text()
  if (auth && sessionBound) requireCurrentSession(token, true)
  let data
  try {
    data = JSON.parse(text)
  } catch {
    handleSessionFailure(res, {}, auth, token)
    throw new ApiError('Invalid server response', res.status)
  }
  if (!res.ok || data.success === false) {
    handleSessionFailure(res, data, auth, token)
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

export async function apiText(path, query, { token = localStorage.getItem('sf_token'), sessionBound = false } = {}) {
  if (sessionBound) requireCurrentSession(token)
  const headers = { Accept: 'text/html, text/csv, text/plain' }
  if (token) Object.assign(headers, { Authorization: `Bearer ${token}`, 'X-Authorization': `Bearer ${token}`, 'X-Smartflow-Token': token })
  const response = await portalFetch(buildUrl(path, query), { headers })
  const text = await response.text()
  if (sessionBound) requireCurrentSession(token, true)
  if (!response.ok) {
    let data = {}
    try { data = JSON.parse(text) } catch { /* Non-JSON error response. */ }
    handleSessionFailure(response, data, true, token)
    throw new ApiError(data.message || 'Could not export the report', response.status)
  }
  return text
}

export async function openPrintableLabel(documentId, textRequest = apiText) {
  const preview = window.open('', '_blank')
  if (!preview) throw new ApiError('Allow pop-ups to open the printable label.')
  try {
    const html = await textRequest('qr-label.php', { id: documentId })
    const assetBase = new URL(`${API_BASE}/`, window.location.href).href
    const base = assetBase.replace(/&/g, '&amp;').replace(/"/g, '&quot;')
    const content = html.replace('<head>', `<head><base href="${base}">`)
    const url = URL.createObjectURL(new Blob([content], { type: 'text/html;charset=utf-8' }))
    preview.opener = null
    preview.location.replace(url)
    setTimeout(() => URL.revokeObjectURL(url), 60000)
  } catch (error) { preview.close(); throw error }
}

function smartflowClient(api, apiUpload, assertSession = () => {}) { return {
  login: (username, password) =>
    api('auth-login.php', { method: 'POST', auth: false, body: { username, password } }),
  logout: (token) => api('auth-logout.php', { method: 'POST', token }),
  signup: (body) =>
    api('auth-signup.php', { method: 'POST', auth: false, body }),
  signupStatus: ({ username, code, statusKey, password } = {}) =>
    api('signup-status.php', {
      method: 'POST',
      auth: false,
      body: { username, request_code: code, status_key: statusKey, password },
    }),
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
  officeDocuments: (id, filters = {}) => api('office-documents.php', { query: { ...filters, ...(id ? { id } : {}) } }),
  documentMovements: (id) => api('documents-movements.php', { query: { id } }),
  officeMovements: (officeId, filters = {}) => api('office-movements-list.php', { query: { office_id: officeId, ...filters } }),
  verifyQr: (qr) => api('qr-verify.php', { method: 'POST', body: { qr } }),
  createDocument: (body) => { assertSession(); return submitCreation('document', body, api) },
  findByReference: (reference) =>
    api('documents-find-by-reference.php', { query: { reference } }),
  recordMovement: (body) => api('movements-create.php', { method: 'POST', body }),
  fileDocument: (documentId, expectedMovementId) => api('documents-file.php', { method: 'POST', body: { document_id: documentId, expected_movement_id: expectedMovementId } }),
  reportsSummary: (officeId, month) =>
    api('reports-summary.php', { query: { office_id: officeId, month } }),
  reportsSummaryQuarterly: (officeId, year, quarter) =>
    api('reports-summary.php', { query: { office_id: officeId, period: 'quarter', year, quarter } }),
  reportsSummaryAnnual: (officeId, year) =>
    api('reports-summary.php', { query: { office_id: officeId, period: 'year', year } }),
  reportsRegister: (filters = {}) => api('reports-register.php', { query: filters }),
  departmentPerformance: (months = 6) => api('department-performance.php', { query: { months } }),

  documentRequestsList: (view, status, filters = {}) =>
    api('document-requests-list.php', { query: { view, ...(status ? { status } : {}), ...filters } }),
  documentRequestsSummary: () => api('document-requests-summary.php'),
  documentRequestCreate: (body) => { assertSession(); return submitCreation('request', body, api) },
  documentRequestUpdate: (body) =>
    api('document-requests-update.php', { method: 'POST', body }),

  usersList: () => api('users-list.php'),
  adminResetPassword: (userId) =>
    api('users-admin-reset-password.php', { method: 'POST', body: { user_id: userId } }),
  adminSetUserEmail: (userId, email) =>
    api('users-admin-set-email.php', { method: 'POST', body: { user_id: userId, email } }),
  setUserActive: (userId, active) =>
    api('users-set-active.php', { method: 'POST', body: { user_id: userId, active } }),
  signupPending: () => api('signup-pending-list.php'),
  signupApprove: (requestId, action) =>
    api('signup-approve.php', { method: 'POST', body: { request_id: requestId, action } }),
  adminOffices: () => api('admin-offices.php'),
  updateThreshold: (body) =>
    api('admin-thresholds-update.php', { method: 'POST', body }),
  systemStatus: () => api('system-status.php'),
  systemEmailTest: () => api('system-email-test.php', { method: 'POST', body: {} }),
  auditExceptions: (hours = 24, period = {}) =>
    api('audit-exceptions.php', { query: { hours, ...period } }),
  auditScans: ({ hours = 48, outcome = 'all', limit = 200 } = {}) =>
    api('audit-scans.php', { query: { hours, outcome, limit } }),
  auditActivity: ({ hours = 168, type = 'all', limit = 100 } = {}) =>
    api('audit-activity.php', { query: { hours, type, limit } }),

  documentUrl: (documentId) => new URL(`/documents?id=${encodeURIComponent(documentId)}`, window.location.href).href,
} }

// Each rendered account keeps its own transport. A dialog opened by account A
// can never silently acquire account B's token after another tab signs in.
export function createSessionClient(token) {
  const request = (path, options) => api(path, { ...options, token, sessionBound: true })
  request.assertSession = () => requireCurrentSession(token)
  const upload = (path, form, options) => apiUpload(path, form, { ...options, token, sessionBound: true })
  const text = (path, query) => apiText(path, query, { token, sessionBound: true })
  return {
    api: request,
    apiText: text,
    openPrintableLabel: id => openPrintableLabel(id, text),
    smartflow: smartflowClient(request, upload, () => requireCurrentSession(token)),
  }
}

// Public sign-in/signup/recovery entry points do not assume a rendered account.
export const smartflow = smartflowClient(api, apiUpload)
