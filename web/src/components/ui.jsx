import { useEffect } from 'react'
import sealImg from '../assets/brand/urbiztondo_seal.png'
import { SfIcon } from '../icons.jsx'

export function Wordmark({ size = 'sm' }) {
  return (
    <div className={`wordmark wordmark--${size}`} aria-label="SmartFlow">
      <span>Smart</span>
      <span>Flow</span>
    </div>
  )
}

export function Overview({ strap, title, body, chips, hint, actions, children }) {
  return (
    <>
      <section className="overview">
        {strap ? (
          <div className="overview__strap-row">
            <span className="strap">{strap}</span>
          </div>
        ) : null}
        {title ? <h2>{title}</h2> : null}
        {body ? <p className="muted">{body}</p> : null}
        {chips?.length ? (
          <div className="chips">
            {chips.map((c) => (
              <span key={typeof c === 'string' ? c : c.label} className={c.gold ? 'chip chip--gold' : 'chip'}>
                {typeof c === 'string' ? c : c.label}
              </span>
            ))}
          </div>
        ) : null}
        {hint ? <div className="hint">{hint}</div> : null}
        {actions ? <div className="overview__actions">{actions}</div> : null}
        {children}
      </section>
      <header className="page-head">
        <div className="page-head__copy">
          {strap ? (
            <div className="overview__strap-row">
              <span className="strap">{strap}</span>
            </div>
          ) : null}
          {title ? <h2>{title}</h2> : null}
          {body ? <p className="muted">{body}</p> : null}
          {chips?.length ? (
            <div className="chips">
              {chips.map((c) => (
                <span key={typeof c === 'string' ? c : c.label} className={c.gold ? 'chip chip--gold' : 'chip'}>
                  {typeof c === 'string' ? c : c.label}
                </span>
              ))}
            </div>
          ) : null}
          {hint ? <p className="page-head__hint">{hint}</p> : null}
        </div>
        {actions ? <div className="page-head__actions">{actions}</div> : null}
      </header>
    </>
  )
}

export function Empty({ mark = '—', children }) {
  return (
    <div className="empty">
      <div className="empty__mark" aria-hidden>{mark}</div>
      <p className="muted">{children}</p>
    </div>
  )
}

/** Empty state with icon — use inside `.sf-life` / `.desk-home` pages. */
export function LifeEmpty({ icon = 'custodyLog', tone, children, action }) {
  const toneClass = tone ? ` sf-life__empty-icon--${tone}` : ''
  return (
    <div className="sf-life__empty desk-home__empty">
      <div className={`sf-life__empty-icon desk-home__empty-icon${toneClass}`} aria-hidden>
        <SfIcon name={icon} size={22} />
      </div>
      <div className="empty">
        <p className="muted">{children}</p>
      </div>
      {action || null}
    </div>
  )
}

/** Soft load placeholder — prefer over blank “Loading…” on desk screens. */
export function LifeSkeleton({ rows = 3, label = 'Loading' }) {
  return (
    <div className="sf-life__skeleton" role="status" aria-live="polite" aria-label={label}>
      {Array.from({ length: rows }, (_, i) => (
        <div key={i} className={`sf-life__skeleton-bar${i === 0 ? ' sf-life__skeleton-bar--lg' : ''}`} />
      ))}
    </div>
  )
}

export function roleLabel(role) {
  if (role === 'head') return 'Department head'
  if (role === 'admin') return 'Municipal accountant'
  return 'Clerk'
}

export function StatusPill({ tone = 'neutral', children }) {
  return <span className={`status-pill status-pill--${tone}`}>{children}</span>
}

export function Segmented({ value, onChange, options }) {
  return (
    <div className="segmented" role="tablist">
      {options.map((opt) => (
        <button
          key={opt.value}
          type="button"
          role="tab"
          aria-selected={value === opt.value}
          className={value === opt.value ? 'is-active' : undefined}
          onClick={() => onChange(opt.value)}
        >
          {opt.label}
          {opt.badge != null && opt.badge !== 0 ? <span className="segmented__badge">{opt.badge}</span> : null}
        </button>
      ))}
    </div>
  )
}

export function Modal({ open, title, onClose, children, footer }) {
  useEffect(() => {
    if (!open) return undefined
    const onKey = (e) => { if (e.key === 'Escape') onClose?.() }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open, onClose])

  if (!open) return null
  return (
    <div className="modal-root" role="presentation">
      <button type="button" className="modal-backdrop" aria-label="Close" onClick={onClose} />
      <div className="modal-panel" role="dialog" aria-modal="true" aria-label={title}>
        <div className="modal-panel__head">
          <h3>{title}</h3>
          <button type="button" className="btn-ghost" onClick={onClose}>Close</button>
        </div>
        <div className="modal-panel__body">{children}</div>
        {footer ? <div className="modal-panel__foot">{footer}</div> : null}
      </div>
    </div>
  )
}

export function DocTable({ columns, rows, onRowClick }) {
  if (!rows?.length) return null
  return (
    <div className="table-wrap">
      <table className="data-table">
        <thead>
          <tr>
            {columns.map((c) => <th key={c.key}>{c.label}</th>)}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, i) => (
            <tr
              key={row.id || row.document_id || i}
              className={onRowClick ? 'is-clickable' : undefined}
              onClick={onRowClick ? () => onRowClick(row) : undefined}
            >
              {columns.map((c) => (
                <td key={c.key}>{c.render ? c.render(row) : row[c.key]}</td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

export function MunicipalSeal({ size = 'sm', tone = 'light', ring = false }) {
  const px = typeof size === 'number'
    ? size
    : size === 'lg'
      ? 64
      : size === 'md'
        ? 52
        : 44
  const cls = [
    'muni-seal',
    ring ? 'muni-seal--ring' : '',
    tone === 'dark' ? 'muni-seal--dark' : '',
  ].filter(Boolean).join(' ')
  return (
    <img
      className={cls}
      src={sealImg}
      alt="Official seal of the Municipality of Urbiztondo"
      width={px}
      height={px}
      style={{ width: px, height: px }}
      decoding="async"
    />
  )
}

export function MunicipalMasthead({ compact = false }) {
  return (
    <header className="muni-masthead">
      <MunicipalSeal size={compact ? 44 : 52} />
      <div className="muni-masthead__text">
        <p className="muni-masthead__kicker">Republic of the Philippines</p>
        <h1 className="muni-masthead__title">Municipality of Urbiztondo</h1>
        <p className="muni-masthead__sub">Province of Pangasinan · Document flow &amp; COA support system</p>
      </div>
    </header>
  )
}

export function GovFooter() {
  return (
    <footer className="gov-foot">
      <strong>SmartFlow</strong> records custody events for municipal audit support.
      It does not approve disbursements or payments.
    </footer>
  )
}

export function AuthShell({
  strap,
  title,
  body,
  chips,
  leading,
  children,
  layout = 'stack',
  welcome = 'Welcome',
  showPoints = true,
}) {
  if (layout === 'split') {
    return (
      <div className="auth-page auth-page--split">
        <div className="auth-split">
          <aside className="auth-split__brand" aria-label="Municipal portal">
            <div className="auth-split__brand-inner">
              <MunicipalSeal size={64} tone="dark" ring />
              <div className="auth-split__brand-copy">
                <p className="auth-split__muni">Municipality of Urbiztondo</p>
                <p className="auth-split__place">Province of Pangasinan</p>
                <div className="auth-split__wordmark">
                  <Wordmark size="lg" />
                </div>
                {welcome ? <h1 className="auth-split__welcome">{welcome}</h1> : null}
                {body ? <p className="auth-split__blurb">{body}</p> : null}
                {showPoints ? (
                  <ul className="auth-split__points">
                    <li>QR handoffs between offices</li>
                    <li>Custody log for accountability</li>
                    <li>Support for COA preparation</li>
                  </ul>
                ) : null}
              </div>
            </div>
          </aside>
          <div className="auth-split__panel">
            <div className="auth-split__panel-inner">
              {leading ? <div className="auth-split__leading">{leading}</div> : null}
              <div className="auth-split__mobile-brand" aria-hidden="true">
                <Wordmark size="sm" />
              </div>
              {strap ? (
                <div className="auth-strap">
                  <span className="auth-strap__text">{strap}</span>
                  <span className="auth-strap__rule" aria-hidden />
                </div>
              ) : null}
              {title ? <h2 className="auth-split__form-title">{title}</h2> : null}
              {chips?.length ? (
                <div className="chips auth-split__chips">
                  {chips.map((c) => (
                    <span key={typeof c === 'string' ? c : c.label} className={c.gold ? 'chip chip--gold' : 'chip'}>
                      {typeof c === 'string' ? c : c.label}
                    </span>
                  ))}
                </div>
              ) : null}
              {children}
              <GovFooter />
            </div>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="auth-page">
      <header className="auth-ceremonial">
        <div className="auth-ceremonial__inner">
          {leading ? <div className="auth-ceremonial__leading">{leading}</div> : null}
          <div className="auth-ceremonial__row">
            <MunicipalSeal size={72} tone="dark" ring />
            <div className="auth-ceremonial__copy">
              <h1 className="auth-ceremonial__title">Municipality of Urbiztondo</h1>
              <p className="auth-ceremonial__sub">Province of Pangasinan</p>
              <p className="auth-ceremonial__kicker">Republic of the Philippines</p>
            </div>
          </div>
        </div>
      </header>

      <div className="auth-panel">
        <div className="auth-panel__body">
          <div className="auth-copy">
            {strap ? (
              <div className="auth-strap">
                <span className="auth-strap__text">{strap}</span>
                <span className="auth-strap__rule" aria-hidden />
              </div>
            ) : null}
            <div className="auth-hero">
              <div className="auth-hero__brand-row">
                <Wordmark size="lg" />
              </div>
              {title ? <h2 className="auth-hero__title">{title}</h2> : null}
              {body ? <p className="muted auth-hero__body">{body}</p> : null}
              {chips?.length ? (
                <div className="chips">
                  {chips.map((c) => (
                    <span key={typeof c === 'string' ? c : c.label} className={c.gold ? 'chip chip--gold' : 'chip'}>
                      {typeof c === 'string' ? c : c.label}
                    </span>
                  ))}
                </div>
              ) : null}
            </div>
          </div>
          <div className="auth-form-wrap">
            {children}
          </div>
        </div>
      </div>
      <GovFooter />
    </div>
  )
}
