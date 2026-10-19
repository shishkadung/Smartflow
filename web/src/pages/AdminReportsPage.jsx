import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { ApiError } from '../api.js'
import { useAuth } from '../auth.jsx'
import { CoaSummaryHero, ExceptionCard, LifeEmpty, LifeSkeleton, Overview, Segmented, statTone } from '../components/ui.jsx'
import { reportPeriodBounds } from '../tracking.js'

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
  const { user, smartflow, apiText } = useAuth()
  const [period, setPeriod] = useState('month')
  const [month, setMonth] = useState(() => reportPeriodBounds().maxMonth)
  const [year, setYear] = useState(() => String(new Date().getFullYear()))
  const [quarter, setQuarter] = useState(() => {
    const now = new Date()
    return `${now.getFullYear()}-Q${Math.ceil((now.getMonth() + 1) / 3)}`
  })
  const [data, setData] = useState(null)
  const [exceptions, setExceptions] = useState(null)
  const [exceptionError, setExceptionError] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [exporting, setExporting] = useState(false)
  const [revision, setRevision] = useState(0)
  const request = useRef(0)
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

  const load = useCallback(async () => {
    const current = ++request.current
    setError('')
    setData(null)
    setExceptions(null)
    setExceptionError('')
    const bounds = reportPeriodBounds()
    const valid = isYear ? /^\d{4}$/.test(year) && Number(year) >= bounds.minYear && Number(year) <= bounds.maxYear
      : isQuarter ? bounds.quarters.includes(quarter)
        : /^\d{4}-(0[1-9]|1[0-2])$/.test(month) && month >= bounds.minMonth && month <= bounds.maxMonth
    if (!valid) { setLoading(false); setError(`Choose a reporting period from ${bounds.minYear} through the current period.`); return }
    setLoading(true)
    try {
      let res
      if (isYear) res = await smartflow.reportsSummaryAnnual(user.office_id, year)
      else if (isQuarter) res = await smartflow.reportsSummaryQuarterly(user.office_id, quarterYear, quarterNumber)
      else res = await smartflow.reportsSummary(user.office_id, month)
      if (current !== request.current) return
      setData(res)
    } catch (e) {
      if (current !== request.current) return
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
        if (current !== request.current) return
        setExceptions(ex.exceptions || [])
      } catch (e) {
        if (current !== request.current) return
        setExceptionError(e.message || 'Could not verify audit exceptions. Refresh to retry.')
      }
    }
    if (current === request.current) setLoading(false)
  }, [isYear, year, isQuarter, quarter, quarterYear, quarterNumber, month, isAccounting, user.office_id, smartflow])

  useEffect(() => {
    // oxlint-disable-next-line react/set-state-in-effect -- Period changes start an asynchronous report request and invalidate the previous result.
    load()
    const sequence = request
    return () => { sequence.current++ }
  }, [load, revision])

  const exportAllowed = data?.export_allowed === true

  async function exportReport(format) {
    if (!exportAllowed || loading || exporting) return
    setError('')
    const preview = format === 'print' ? window.open('', '_blank') : null
    if (format === 'print' && !preview) { setError('Allow pop-ups to open the print preview.'); return }
    setExporting(true)
    try {
      const text = await apiText('reports-summary.php', { office_id: data.office_id, period: data.period, month: data.month, year: data.year, quarter: data.quarter, format })
      const content = format === 'csv' && !text.startsWith('\uFEFF') ? `\uFEFF${text}` : text
      const url = URL.createObjectURL(new Blob([content], { type: format === 'csv' ? 'text/csv;charset=utf-8' : 'text/html;charset=utf-8' }))
      if (preview) preview.location.replace(url)
      else {
        const link = document.createElement('a')
        link.href = url; link.download = `SmartFlow-custody-${data.period}-${String(data.period_start).slice(0, 10)}.csv`
        link.click()
      }
      setTimeout(() => URL.revokeObjectURL(url), 60000)
    } catch (e) { preview?.close(); setError(e.message) }
    finally { setExporting(false) }
  }

  const compliance = data?.compliance || {}
  const docsInPeriod = useMemo(() => {
    if (!data) return null
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
        title="Custody reports"
        actions={!error ? <button type="button" className="btn-secondary" disabled={loading} onClick={() => setRevision(r => r + 1)}>Refresh report</button> : null}
      />
      {error ? <div className="error" role="alert"><strong>{data ? 'Report action failed' : 'Custody report unavailable'}</strong><p>{error}</p><button type="button" className="btn-secondary" disabled={loading} onClick={() => setRevision(value => value + 1)}>Retry report</button></div> : null}
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
        {data ? <div className="stats sf-life__stats" style={{ margin: 0 }}>
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
        </div> : loading ? <LifeSkeleton rows={2} label="Loading custody summary" /> : <p className="muted">Load the report to verify activity and rates for this period.</p>}
        {data?.submission_note ? (
          <p className="hint" style={{ margin: '12px 0 0' }}>{data.submission_note}</p>
        ) : null}
        {exportAllowed ? (
          <div className="report-actions"><button type="button" className="btn" disabled={loading || exporting} onClick={() => exportReport('csv')}>{exporting ? 'Preparing…' : 'Download CSV'}</button><button type="button" className="btn-ghost" disabled={loading || exporting} onClick={() => exportReport('print')}>Print / Save PDF</button></div>
        ) : data ? (
          <p className="muted" style={{ margin: '14px 0 0' }}>
            Only Accounting administrators can export municipal COA summaries.
          </p>
        ) : null}
      </CoaSummaryHero>
      {data ? <p className="muted">Generated {data.generated_at} ({data.timezone}) · {data.scope} · Prepared by {data.prepared_by}</p> : null}
      {isAccounting ? (
        <div className="card sf-life__panel">
          <h3 className="section-title">Audit exceptions · {periodLabel}</h3>
          <p className="muted" style={{ marginTop: 0 }}>
            Unforwarded OUT, wrong-office IN, or trails that skipped Budget/Accounting — review before COA reporting.
          </p>
          {loading ? (
            <LifeSkeleton rows={2} label="Loading exceptions" />
          ) : exceptionError ? <div className="error" role="alert">Audit exceptions could not be verified. {exceptionError}<button type="button" className="btn-secondary" onClick={() => setRevision(value => value + 1)}>Retry exceptions</button></div>
            : exceptions === null ? <p className="muted">Audit exceptions have not been verified for this period.</p>
            : exceptions.length === 0 ? (
            <LifeEmpty icon="coaSupport" tone="ok">{`No exceptions this ${periodNoun}.`}</LifeEmpty>
          ) : (
            exceptions.map((ex, i) => (
              <ExceptionCard key={`${ex.document_id}-${ex.exception_type}-${i}`} exception={ex} />
            ))
          )}
        </div>
      ) : null}
      <ReportOfficeTotals data={data} loading={loading} periodNoun={periodNoun} />
    </div>
  )
}

export function ReportOfficeTotals({ data, loading, periodNoun }) {
  return <div className="card sf-life__panel">
    <h3 className="section-title">By office</h3>
    {loading && !data ? <LifeSkeleton rows={3} label="Loading office totals" /> : !data ? <p className="muted">Office totals are unavailable until the report loads.</p> : (data.office_totals || []).length === 0 ? <LifeEmpty icon="coa">{`No office totals for this ${periodNoun}.`}</LifeEmpty> : data.office_totals.map(row => <div key={row.office_id || row.office_code} className="list-item list-item--static"><strong>{row.office_name || row.office_code}</strong><span className="muted">Processed {row.docs_processed ?? row.processed ?? '—'}</span></div>)}
  </div>
}
