import { useEffect, useMemo, useState } from 'react'
import { smartflow, ApiError } from '../api.js'
import { useAuth } from '../auth.jsx'
import { CoaSummaryHero, ExceptionCard, LifeEmpty, LifeSkeleton, Overview, Segmented, statTone } from '../components/ui.jsx'

function pct(bucket) {
  if (bucket == null) return '—'
  if (typeof bucket === 'object' && bucket.percent != null) return `${Math.round(bucket.percent)}%`
  return String(bucket)
}

function monthDisplay(ym) {
  try {
    const [y, m] = String(ym).split('-').map(Number)
    if (!y || !m) return ym
    return new Date(y, m - 1, 1).toLocaleString('en-US', { month: 'long', year: 'numeric' })
  } catch {
    return ym
  }
}

export default function AdminReportsPage() {
  const { user } = useAuth()
  const [period, setPeriod] = useState('month')
  const [month, setMonth] = useState(() => new Date().toISOString().slice(0, 7))
  const [year, setYear] = useState(() => String(new Date().getFullYear()))
  const [quarter, setQuarter] = useState(() => {
    const now = new Date()
    return `${now.getFullYear()}-Q${Math.ceil((now.getMonth() + 1) / 3)}`
  })
  const [data, setData] = useState(null)
  const [exceptions, setExceptions] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [copied, setCopied] = useState(false)
  const isAccounting = String(user.office_code || '').toUpperCase() === 'ACC'

  const isYear = period === 'year'
  const isQuarter = period === 'quarter'
  const [quarterYear, quarterNumber] = quarter.split('-Q')
  const periodLabel = isYear
    ? `Annual ${year}`
    : isQuarter
      ? `Q${quarterNumber} ${quarterYear}`
      : monthDisplay(month)
  const pickerValue = isYear ? year : isQuarter ? quarter : month
  const onPickerChange = isYear ? setYear : isQuarter ? setQuarter : setMonth
  const periodNoun = isYear ? 'year' : isQuarter ? 'quarter' : 'month'

  async function load() {
    setError('')
    if (isYear && !/^\d{4}$/.test(year)) return
    setLoading(true)
    try {
      let res
      if (isYear) res = await smartflow.reportsSummaryAnnual(user.office_id, year)
      else if (isQuarter) res = await smartflow.reportsSummaryQuarterly(user.office_id, quarterYear, quarterNumber)
      else res = await smartflow.reportsSummary(user.office_id, month)
      setData(res)
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'Could not load custody summary')
    }
    if (isAccounting) {
      const periodQuery = isYear
        ? { period: 'year', year }
        : isQuarter
          ? { period: 'quarter', year: quarterYear, quarter: quarterNumber }
          : { period: 'month', month }
      try {
        const ex = await smartflow.auditExceptions(24, periodQuery)
        setExceptions(ex.exceptions || [])
      } catch {
        setExceptions([])
      }
    }
    setLoading(false)
  }

  useEffect(() => { load() }, [period, month, quarter, year, user.office_id])

  const exportAllowed = data?.export_allowed === true

  function copySummary() {
    if (!exportAllowed) return
    const c = data?.compliance || {}
    const text = [
      `Custody support summary · ${periodLabel}`,
      `Office: ${user.office_name} (${user.office_code})`,
      `On-time handoffs: ${pct(c.on_time ?? c.completed_on_time)}`,
      `Unforwarded OUT: ${pct(c.unforwarded)}`,
      `Delayed: ${pct(c.delayed)}`,
      '',
      'Source: SmartFlow scan logs (custody). Not a COA financial package.',
    ].join('\n')
    navigator.clipboard?.writeText(text)
    setCopied(true)
    setTimeout(() => setCopied(false), 1500)
  }

  const compliance = data?.compliance || {}
  const docsInPeriod = useMemo(() => {
    const totals = data?.totals || data?.summary || {}
    if (totals.documents_in_period != null) return totals.documents_in_period
    const offices = data?.office_totals || []
    return offices.reduce(
      (n, row) => n + (Number(row.docs_processed ?? row.processed) || 0),
      0,
    )
  }, [data])

  return (
    <div className="sf-life">
      <Overview
        title="COA reports"
        body="Monthly, quarterly, and annual handoff metrics from scan logs — not a financial review."
      />
      {error ? <div className="error">{error}</div> : null}
      <div className="toolbar">
        <Segmented
          value={period}
          onChange={setPeriod}
          options={[
            { value: 'month', label: 'Monthly' },
            { value: 'quarter', label: 'Quarterly' },
            { value: 'year', label: 'Annual' },
          ]}
        />
      </div>
      <CoaSummaryHero
        monthLabel={periodLabel}
        docsInPeriod={docsInPeriod}
        period={period}
        monthValue={pickerValue}
        onChangeMonth={onPickerChange}
      >
        <div className="stats sf-life__stats" style={{ margin: 0 }}>
          <div className={statTone(pct(compliance.on_time ?? compliance.completed_on_time), 'stat--ok')}>
            <b>{pct(compliance.on_time ?? compliance.completed_on_time)}</b>
            <span>On time</span>
          </div>
          <div className={statTone(pct(compliance.unforwarded), 'stat--warn')}>
            <b>{pct(compliance.unforwarded)}</b>
            <span>Unforwarded</span>
          </div>
          <div className={statTone(pct(compliance.delayed), 'stat--bad')}>
            <b>{pct(compliance.delayed)}</b>
            <span>Delayed</span>
          </div>
        </div>
        {data?.submission_note ? (
          <p className="hint" style={{ margin: '12px 0 0' }}>{data.submission_note}</p>
        ) : null}
        {exportAllowed ? (
          <button
            type="button"
            className="btn sf-life__cta"
            onClick={copySummary}
            style={{ marginTop: 14, width: '100%' }}
          >
            {copied ? 'Copied' : 'Copy summary for COA'}
          </button>
        ) : data ? (
          <p className="muted" style={{ margin: '14px 0 0' }}>
            Only Accounting administrators can copy municipal COA summaries.
          </p>
        ) : null}
      </CoaSummaryHero>
      {isAccounting ? (
        <div className="card sf-life__panel">
          <h3 className="section-title">Audit exceptions · {periodLabel}</h3>
          <p className="muted" style={{ marginTop: 0 }}>
            Unforwarded OUT, wrong-office IN, or trails that skipped Budget/Accounting — review before COA reporting.
          </p>
          {loading ? (
            <LifeSkeleton rows={2} label="Loading exceptions" />
          ) : exceptions.length === 0 ? (
            <LifeEmpty icon="coaSupport" tone="ok">{`No exceptions this ${periodNoun}.`}</LifeEmpty>
          ) : (
            exceptions.map((ex, i) => (
              <ExceptionCard key={`${ex.document_id}-${ex.exception_type}-${i}`} exception={ex} />
            ))
          )}
        </div>
      ) : null}
      <div className="card sf-life__panel">
        <h3 className="section-title">By office</h3>
        {loading && !data ? (
          <LifeSkeleton rows={3} label="Loading office totals" />
        ) : (data?.office_totals || []).length === 0 ? (
          <LifeEmpty icon="coa">
            {`No office totals for this ${periodNoun}.`}
          </LifeEmpty>
        ) : (
          (data?.office_totals || []).map((row) => (
            <div key={row.office_id || row.office_code} className="list-item list-item--static">
              <strong>{row.office_name || row.office_code}</strong>
              <span className="muted">Processed {row.docs_processed ?? row.processed ?? '—'}</span>
            </div>
          ))
        )}
      </div>
    </div>
  )
}
