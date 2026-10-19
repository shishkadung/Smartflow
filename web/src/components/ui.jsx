import { useEffect, useRef } from 'react'
import { Link } from 'react-router-dom'
import sealImg from '../assets/brand/urbiztondo_seal.png'
import { SfIcon } from '../icons.jsx'
import { formatWhen, reportPeriodBounds } from '../tracking.js'

const EXCEPTION_KINDS = {
  unforwarded: { label: 'Unforwarded OUT', tone: 'warn' },
  wrong_receiver: { label: 'Wrong receiver', tone: 'bad' },
  skipped_office: { label: 'Skipped office', tone: 'bad' },
}

/** Custody exception row — opens the document's trail in History. */
export function ExceptionCard({ exception: ex }) {
  const kind = EXCEPTION_KINDS[ex.exception_type] || { label: ex.exception_type || 'Exception', tone: 'neutral' }
  return (
    <Link
      className="pending-card"
      to={`/history?id=${encodeURIComponent(ex.document_id)}`}
      title="Open the custody trail"
    >
      <div className="pending-card__head">
        <strong>{ex.document_id}</strong>
        <StatusPill tone={kind.tone}>{kind.label}</StatusPill>
      </div>
      <span className="muted">
        {ex.detail}
        {ex.last_scanned_at ? ` · ${formatWhen(ex.last_scanned_at)}` : ''}
      </span>
    </Link>
  )
}

export function Wordmark({ size = 'sm' }) {
  return (
    <div className={`wordmark wordmark--${size}`} aria-label="SmartFlow">
      <span>Smart</span>
      <span>Flow</span>
    </div>
  )
}

function OverviewCopy({ strap, title, body, chips, hint }) {
  return (
    <>
      {strap ? (
        <div className="overview__strap-row">
          <span className="strap">{strap}</span>
        </div>
      ) : null}
      {title ? <h2>{title}</h2> : null}
      {body ? (
        <>
          <span className="overview__rule" aria-hidden />
          <p className="muted">{body}</p>
        </>
      ) : null}
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
    </>
  )
}

export function Overview({ strap, title, body, chips, hint, actions, children }) {
  const props = { strap, title, body, chips, hint }
  return (
    <header className="page-heading">
      <div className="page-heading__copy"><OverviewCopy {...props} /></div>
      {actions ? <div className="page-heading__actions">{actions}</div> : null}
      {children}
    </header>
  )
}

/** Soft paper COA summary band (mobile twin of SfCoaExportHero header). */
export function CoaSummaryHero({
  monthLabel,
  docsInPeriod = 0,
  onChangeMonth,
  monthValue,
  period = 'month',
  children,
}) {
  const isYear = period === 'year'
  const isQuarter = period === 'quarter'
  const { minYear, maxYear, minMonth, maxMonth, quarters: quarterOptions } = reportPeriodBounds()
  return (
    <section className="coa-hero">
      <div className="coa-hero__band">
        <div className="coa-hero__copy">
          <p className="coa-hero__strap">COA support summary</p>
          <h3 className="coa-hero__title">{monthLabel}</h3>
          <span className="coa-hero__rule" aria-hidden />
          <p className="coa-hero__meta">
            {docsInPeriod == null ? 'Activity count not verified' : `${docsInPeriod} documents with activity · municipal system`}
          </p>
        </div>
        {onChangeMonth ? (
          <label className="coa-hero__month">
            <span>{isYear ? 'Year' : isQuarter ? 'Quarter' : 'Month'}</span>
            {isYear ? (
              <input
                type="number"
                min={minYear}
                max={maxYear}
                step={1}
                value={monthValue}
                onChange={(e) => onChangeMonth(e.target.value)}
              />
            ) : isQuarter ? (
              <select value={monthValue} onChange={(e) => onChangeMonth(e.target.value)}>
                {quarterOptions.map((value) => {
                  const [y, q] = value.split('-')
                  return <option key={value} value={value}>{`${q} ${y}`}</option>
                })}
              </select>
            ) : (
              <input
                type="month"
                min={minMonth}
                max={maxMonth}
                value={monthValue}
                onChange={(e) => onChangeMonth(e.target.value)}
              />
            )}
          </label>
        ) : null}
      </div>
      {children ? <div className="coa-hero__body">{children}</div> : null}
    </section>
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
    <div className="sf-empty">
      <div className={`sf-life__empty-icon desk-home__empty-icon${toneClass}`} aria-hidden>
        <SfIcon name={icon} size={22} />
      </div>
      <div className="sf-empty__body">
        <p className="muted">{children}</p>
        {action ? <div className="sf-empty__actions">{action}</div> : null}
      </div>
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

/** Navy until the count is above zero. Red is only for overdue. */
export function statTone(value, tone) {
  const n = Number(String(value ?? '').replace('%', ''))
  if (!Number.isFinite(n) || n <= 0) return 'stat stat--quiet'
  if (tone === 'stat--out' || tone === 'stat--hours' || tone === 'stat--pending') return 'stat stat--quiet'
  return `stat ${tone}`
}

export function roleLabel(role) {
  if (role === 'head') return 'Department head'
  if (role === 'admin') return 'Municipal accountant'
  return 'Clerk'
}

export function StatusPill({ tone = 'neutral', children }) {
  return <span className={`status-pill status-pill--${tone}`}>{children}</span>
}

/** One folder, one next step. The whole card opens that step. */
export function WorkCard({ kicker, title, meta, pill, tone = 'info', verb, onOpen }) {
  return (
    <article className={`work-card work-card--${tone}`}>
      <button type="button" className="work-card__open" onClick={onOpen}>
        <span className="work-card__kicker">{kicker}</span>
        <strong>{title}</strong>
        {meta ? <span className="work-card__meta">{meta}</span> : null}
        <span className="work-card__foot">
          <StatusPill tone={tone}>{pill}</StatusPill>
          <span className="work-card__verb">{verb}</span>
        </span>
      </button>
    </article>
  )
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
  const panel = useRef(null)
  // Form edits can replace onClose; keep Escape current without resetting focus.
  const closeHandler = useRef(onClose)
  useEffect(() => { closeHandler.current = onClose }, [onClose])
  useEffect(() => {
    if (!open) return undefined
    const previous = document.activeElement
    const focusable = () => [...(panel.current?.querySelectorAll('button:not(:disabled), a[href], input:not(:disabled), select:not(:disabled), textarea:not(:disabled), [tabindex="0"]') || [])].filter(node => node.getClientRects().length)
    const frame = requestAnimationFrame(() => (focusable()[0] || panel.current)?.focus())
    const onKey = (e) => {
      if (panel.current !== [...document.querySelectorAll('[role="dialog"]')].at(-1)) return
      if (e.key === 'Escape') { e.preventDefault(); closeHandler.current?.() }
      if (e.key !== 'Tab') return
      const elements = focusable()
      if (!elements.length) { e.preventDefault(); panel.current?.focus(); return }
      const first = elements[0], last = elements.at(-1)
      if (e.shiftKey && (document.activeElement === first || !panel.current?.contains(document.activeElement))) { e.preventDefault(); last.focus() }
      else if (!e.shiftKey && (document.activeElement === last || !panel.current?.contains(document.activeElement))) { e.preventDefault(); first.focus() }
    }
    window.addEventListener('keydown', onKey)
    return () => { cancelAnimationFrame(frame); window.removeEventListener('keydown', onKey); if (previous?.isConnected) previous.focus() }
  }, [open])

  if (!open) return null
  return (
    <div className="modal-root" role="presentation">
      <button type="button" className="modal-backdrop" aria-label="Close" onClick={onClose} />
      <div className="modal-panel" role="dialog" aria-modal="true" aria-label={title} ref={panel} tabIndex={-1}>
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

export function DocTable({ columns, rows, onRowClick, scroll = false }) {
  if (!rows?.length) return null
  return (
    <div className={scroll ? 'table-wrap table-wrap--scroll' : 'table-wrap'}>
      <table className="data-table">
        <thead>
          <tr>
            {columns.map((c) => <th key={c.key} style={c.width ? { width: c.width } : undefined}>{c.label}</th>)}
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
      <strong>SmartFlow</strong> keeps the folder log. It does not approve payments.
    </footer>
  )
}

const AUTH_POINTS = [
  'Scan a folder when it arrives or leaves',
  'See which office has it now',
  'Print the monthly custody summary',
]

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
  points = AUTH_POINTS,
  grow = false,
  note,
}) {
  if (layout === 'split') {
    return (
      <div className="auth-page auth-page--split">
        <div className={grow ? 'auth-split auth-split--grow' : 'auth-split'}>
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
                    {points.map((point) => <li key={point}>{point}</li>)}
                  </ul>
                ) : null}
              </div>
            </div>
          </aside>
          <div className="auth-split__panel">
            <div className="auth-split__panel-inner">
              <div className="auth-split__stack">
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
                {note ? <p className="auth-note-plain">{note}</p> : null}
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
