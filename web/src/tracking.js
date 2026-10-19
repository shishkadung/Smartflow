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

export function clerkScanActions({ lastStatus, lastOfficeId, myOfficeId, currentOfficeName, destinationOfficeId, destinationOfficeName, role = 'staff' }) {
  if (role !== 'staff') {
    return {
      canIn: false,
      canOut: false,
      statusLine: lastStatus && lastOfficeId != null ? `${lastStatus} at ${currentOfficeName || `office #${lastOfficeId}`}` : 'No custody recorded yet',
      blockReason: 'Read-only custody view. Office staff register folders and record physical handoffs.',
    }
  }
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
  if (status === 'OUT' && Number(destinationOfficeId) > 0 && Number(destinationOfficeId) !== Number(myOfficeId)) {
    return {
      canIn: false,
      canOut: false,
      statusLine,
      blockReason: `Sent to ${destinationOfficeName || 'another office'}. Only that receiving office can confirm receipt. If the destination was recorded incorrectly, ask the sending office to correct it.`,
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

/** "2026-09-28 15:14:02" → "Sep 28, 2026 · 3:14 PM" (falls back to the raw value). */
export function formatWhen(raw) {
  if (!raw) return ''
  const d = new Date(String(raw).replace(' ', 'T'))
  if (Number.isNaN(d.getTime())) return String(raw)
  const date = d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
  const time = d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
  return `${date} · ${time}`
}

const RETURN_PREFIX = /^Returned to (.+?): (.*)$/s

/** Hide only an entire boilerplate remark; appended receipt evidence and clerk notes stay intact. */
export function movementNote(m) {
  const remarks = String(m?.remarks || '').trim()
  const ret = remarks.match(RETURN_PREFIX)
  if (ret) return { isReturn: true, returnedTo: ret[1], note: ret[2] }
  const boilerplate = [
    'Registered and received at origin office',
    m?.office_name ? `Received at ${m.office_name}` : null,
    m?.office_name && m?.destination_office_name && m?.destination_office_code
      ? `Forwarded from ${m.office_name} → ${m.destination_office_name} (${m.destination_office_code})` : null,
  ]
  if (!remarks || boilerplate.includes(remarks)) {
    return { isReturn: false, note: '' }
  }
  return { isReturn: false, note: remarks }
}

export function homePath(role) {
  if (role === 'head') return '/head'
  if (role === 'admin') return '/admin'
  return '/home'
}

export function movementDestination({ destinationOfficeId, isReturn = false, returnReason = '' }) {
  const destination = Number(destinationOfficeId)
  if (!Number.isSafeInteger(destination) || destination <= 0) throw new Error('Choose a receiving office.')
  if (!isReturn) return { destination_office_id: destination }
  const reason = returnReason.trim()
  if (reason.length < 5 || reason.length > 200) throw new Error('Enter a return reason between 5 and 200 characters.')
  return { destination_office_id: destination, is_return: true, remarks: reason }
}

export function reportPeriodBounds(now = new Date()) {
  const maxYear = now.getFullYear()
  const minYear = maxYear - 14
  const month = now.getMonth() + 1
  const quarters = []
  for (let year = maxYear; year >= minYear; year--) {
    for (let quarter = year === maxYear ? Math.ceil(month / 3) : 4; quarter >= 1; quarter--) quarters.push(`${year}-Q${quarter}`)
  }
  return { minYear, maxYear, minMonth: `${minYear}-01`, maxMonth: `${maxYear}-${String(month).padStart(2, '0')}`, quarters }
}

export function statusLabel(status, category) {
  const s = String(status || '').toLowerCase()
  if (s === 'rejected') return 'Declined'
  if (s === 'approved') return 'Accepted'
  if (s === 'fulfilled') {
    return String(category || '').toLowerCase() === 'disbursement' ? 'Payment released' : 'Closed'
  }
  return s ? s[0].toUpperCase() + s.slice(1) : '—'
}
