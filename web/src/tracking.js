export function isSignedQrPayload(raw) {
  const trimmed = String(raw || '').trim()
  if (!trimmed.startsWith('SF1.')) return false
  const parts = trimmed.split('.')
  return parts.length === 3 && parts[1] && parts[2]
}

export function parseTrackingId(raw) {
  const trimmed = String(raw || '').trim()
  if (!trimmed || isSignedQrPayload(trimmed)) return null
  const direct = /^DOC-\d{4}-\d{6}$/i
  if (direct.test(trimmed)) return trimmed.toUpperCase()
  const match = trimmed.match(/DOC-\d{4}-\d{6}/i)
  return match ? match[0].toUpperCase() : null
}

export function clerkScanActions({ lastStatus, lastOfficeId, myOfficeId, currentOfficeName }) {
  if (!lastStatus || lastOfficeId == null) {
    return {
      canIn: true,
      canOut: false,
      statusLine: 'No scans yet — mark IN when the document arrives',
      blockReason: null,
    }
  }

  const office = currentOfficeName || `office #${lastOfficeId}`
  const statusLine = `${lastStatus} at ${office}`
  const status = String(lastStatus).toUpperCase()

  if (status === 'IN' && lastOfficeId === myOfficeId) {
    return { canIn: false, canOut: true, statusLine, blockReason: null }
  }
  if (status === 'OUT' && lastOfficeId === myOfficeId) {
    return {
      canIn: false,
      canOut: false,
      statusLine,
      blockReason: 'Already forwarded from your office. Receiving office must scan IN.',
    }
  }
  if (status === 'IN' && lastOfficeId !== myOfficeId) {
    return {
      canIn: false,
      canOut: false,
      statusLine,
      blockReason: `Still at ${office}. They must mark OUT before you can receive it.`,
    }
  }
  return { canIn: true, canOut: false, statusLine, blockReason: null }
}

export const OFFICE_DOCUMENT_TYPES = {
  ENG: ['Disbursement Voucher'],
  HR: [],
  BUD: ['Approved Budget'],
  ACC: ['Disbursement Voucher', 'Approved Budget'],
  TRE: ['Disbursement Voucher'],
  MAY: ['Disbursement Voucher'],
}

export const OTHER_DOCUMENT_TYPE = 'Others'

export function documentTypesForOffice(code) {
  const types = OFFICE_DOCUMENT_TYPES[String(code || '').toUpperCase()] ?? [
    'Disbursement Voucher',
    'Approved Budget',
  ]
  return types.includes(OTHER_DOCUMENT_TYPE) ? types : [...types, OTHER_DOCUMENT_TYPE]
}

/** Access request categories (matches Flutter office_document_types.dart). */
export function documentRequestCategoriesForOffice(code) {
  const upper = String(code || '').toUpperCase()
  const items = []
  if (upper !== 'BUD') items.push({ value: 'budget', label: 'Budget (→ BUD)' })
  if (upper !== 'ACC') items.push({ value: 'disbursement', label: 'Disbursement / DV (→ ACC)' })
  items.push({ value: 'other', label: 'Others' })
  return items
}

export function homePath(role) {
  if (role === 'head') return '/head'
  if (role === 'admin') return '/admin'
  return '/home'
}

export function statusLabel(status) {
  const s = String(status || '').toLowerCase()
  if (s === 'rejected') return 'Declined'
  if (s === 'approved') return 'Accepted'
  if (s === 'fulfilled') return 'Closed'
  return s ? s[0].toUpperCase() + s.slice(1) : '—'
}
