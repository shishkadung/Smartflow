import { avatarUrl } from '../api.js'

function initials(name = '') {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((p) => p[0]?.toUpperCase() || '')
    .join('') || '?'
}

/**
 * Profile photo or initials fallback.
 * size: 'sm' | 'md' | 'lg' | 'xl'
 */
export function UserAvatar({ user, name, size = 'md', className = '', editable = false, onPick, busy = false }) {
  const displayName = name || user?.name || ''
  const src = avatarUrl(user)
  const letters = initials(displayName)
  const cls = `user-avatar user-avatar--${size} ${editable ? 'user-avatar--editable' : ''} ${className}`.trim()

  const inner = src ? (
    <img src={src} alt="" className="user-avatar__img" />
  ) : (
    <span className="user-avatar__initials" aria-hidden>{letters}</span>
  )

  if (!editable) {
    return (
      <div className={cls} aria-hidden={!src}>
        {inner}
      </div>
    )
  }

  return (
    <button
      type="button"
      className={cls}
      onClick={onPick}
      disabled={busy}
      title="Change profile photo"
      aria-label="Change profile photo"
    >
      {inner}
      <span className="user-avatar__badge" aria-hidden>
        {busy ? '…' : '✎'}
      </span>
    </button>
  )
}
