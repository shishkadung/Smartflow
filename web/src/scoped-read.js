// A retained response belongs to the query that produced it, including browser history changes.
export function scopedReadView(state, key) {
  return state?.key === key ? state : { key, data: null, error: '', loading: true, updated: null }
}

export function beginScopedRead(state, key) {
  return { ...scopedReadView(state, key), loading: true, error: '' }
}

export function failScopedRead(state, key, error) {
  return { ...scopedReadView(state, key), loading: false, error }
}
