import { useEffect, useRef, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { ApiError } from '../api.js'
import { useAuth } from '../auth.jsx'
import { CoaSummaryHero, ExceptionCard, LifeEmpty, LifeSkeleton, Overview, Segmented, statTone } from '../components/ui.jsx'
import { reportPeriodBounds } from '../tracking.js'
import { reportPeriodQuery, reportViewFromSearch, reportViewParams } from '../report-navigation.js'
import ReportRegister from '../components/ReportRegister.jsx'
import DepartmentPerformance from '../components/DepartmentPerformance.jsx'
import { formatHours } from '../report-metrics.js'
import { scrollBehavior } from '../motion.js'

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

function focusRegisterHeading() {
  const heading = document.getElementById('custody-register-heading')
  heading?.focus({ preventScroll: true })
  heading?.scrollIntoView({ block: 'start', behavior: scrollBehavior() })
}

export default function AdminReportsPage() {
  const { user, smartflow, apiText } = useAuth()
  const [params, setParams] = useSearchParams()
  const view = reportViewFromSearch(params)
  const { period, month, year, quarter } = view
  const reportKey = JSON.stringify(reportPeriodQuery(view))
  const registerFocus = useRef(false)
  function changeView(changes) { setParams(reportViewParams({ ...view, ...changes, page: changes.page ?? 1 })) }
  // Moving between parts keeps the register page and filters the user already chose.
  function changeSection(section) { setParams(reportViewParams({ ...view, section })) }
  function showClassification(classification) {
    changeView({ section: 'register', scope: 'activity', classification, office_id: '', q: '' })
    if (section === 'register') focusRegisterHeading()
    else registerFocus.current = true
  }
  const setPeriod = period => changeView({ period })
  const setMonth = month => changeView({ month })
  const setYear = year => changeView({ year })
  const setQuarter = quarter => changeView({ quarter })
  const [snapshot, setSnapshot] = useState(null)
  const data = snapshot?.key === reportKey ? snapshot.data : null
  const [exceptionSnapshot, setExceptionSnapshot] = useState(null)
  const exceptions = exceptionSnapshot?.key === reportKey ? exceptionSnapshot.data : null
  const [exceptionError, setExceptionError] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [exportError, setExportError] = useState('')
  const [exporting, setExporting] = useState(false)
  const [revision, setRevision] = useState(0)
  const request = useRef(0)
  const isAccounting = String(user.office_code || '').toUpperCase() === 'ACC'
  const sectionOptions = [
    { value: 'overview', label: 'Overview' },
    { value: 'departments', label: 'Departments' },
    { value: 'register', label: 'Register' },
    ...(isAccounting ? [{ value: 'exceptions', label: 'Exceptions', badge: exceptions?.length }] : []),
  ]
  const section = sectionOptions.some(option => option.value === view.section) ? view.section : 'overview'
  useEffect(() => {
    // A summary tile opened the register from another part; focus its heading once the part is visible.
    if (!registerFocus.current || section !== 'register') return
    registerFocus.current = false
    focusRegisterHeading()
  }, [section])

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

  useEffect(() => {
    const load = async () => {
      const current = ++request.current
      setError('')
      setExportError('')
      setSnapshot(null)
      setExceptionSnapshot(null)
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
        setSnapshot({ key: reportKey, data: res })
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
          setExceptionSnapshot({ key: reportKey, data: ex.exceptions || [] })
        } catch (e) {
          if (current !== request.current) return
          setExceptionError(e.message || 'Could not verify audit exceptions. Refresh to retry.')
        }
      }
      if (current === request.current) setLoading(false)
    }
    // oxlint-disable-next-line react/set-state-in-effect -- Period changes start an asynchronous report request and invalidate the previous result.
    load()
    const sequence = request
    return () => { sequence.current++ }
  }, [isYear, year, isQuarter, quarter, quarterYear, quarterNumber, month, isAccounting, user.office_id, smartflow, reportKey, revision])

  const exportAllowed = data?.export_allowed === true

  async function exportReport(format) {
    if (!exportAllowed || loading || exporting) return
    setExportError('')
    const exportVersion = request.current
    const preview = format === 'print' ? window.open('', '_blank') : null
    if (format === 'print' && !preview) { setExportError('Allow pop-ups to open the print preview.'); return }
    setExporting(true)
    try {
      const text = await apiText('reports-summary.php', { office_id: data.office_id, period: data.period, month: data.month, year: data.year, quarter: data.quarter, as_of: data.as_of || data.period_end, movement_watermark: data.movement_watermark, correction_watermark: data.correction_watermark, format })
      if (exportVersion !== request.current) { preview?.close(); return }
      const content = format === 'csv' && !text.startsWith('\uFEFF') ? `\uFEFF${text}` : text
      const url = URL.createObjectURL(new Blob([content], { type: format === 'csv' ? 'text/csv;charset=utf-8' : 'text/html;charset=utf-8' }))
      if (preview) preview.location.replace(url)
      else {
        const link = document.createElement('a')
        link.href = url; link.download = `SmartFlow-custody-${data.period}-${String(data.period_start).slice(0, 10)}.csv`
        link.click()
      }
      setTimeout(() => URL.revokeObjectURL(url), 60000)
    } catch (e) { preview?.close(); if (exportVersion === request.current) setExportError(e.message) }
    finally { setExporting(false) }
  }

  const compliance = data?.compliance || {}
  // Office counts overlap; summing them cannot establish a unique-folder total.
  const docsInPeriod = data?.totals?.documents_in_period ?? data?.summary?.documents_in_period ?? null

  return (
    <div className="sf-life custody-reports-page">
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
          {[
            ['on_time', 'On time / in process', 'stat--ok'],
            ['unforwarded', 'Awaiting receipt', 'stat--warn'],
            ['delayed', 'Late receipt', 'stat--bad'],
          ].map(([key, label, tone]) => <button key={key} type="button" className={`${statTone(pct(compliance[key]), tone)} report-classification`} aria-pressed={view.scope === 'activity' && view.classification === key} onClick={() => showClassification(key)}>
            <b>{compliance[key]?.count ?? '—'} <small>{compliance[key]?.count === 1 ? 'folder' : 'folders'} · {pct(compliance[key])}</small></b><span>{label}</span>
          </button>)}
        </div> : loading ? <LifeSkeleton rows={2} label="Loading custody summary" /> : <p className="muted">Load the report to verify activity and rates for this period.</p>}
        {data?.submission_note ? (
          <p className="hint" style={{ margin: '12px 0 0' }}>{data.submission_note}</p>
        ) : null}
        <details className="report-basis"><summary>How these numbers are counted</summary><p>Each folder with activity in the period is counted once. A receipt more than 72 calendar hours after sending takes priority as Late receipt; otherwise an OUT awaiting receipt is counted as Awaiting receipt. Remaining received folders are On time / in process, including folders still at an office. This does not establish that processing met its deadline or that a folder is complete. Alerts use the configured office limits.</p><p>Audit exceptions separately flag missing receipts after 24 hours and route evidence for review. A flagged route is not proof of an unauthorized handoff. Outstanding transfers also includes earlier sends without a receipt at the cutoff.</p></details>
        {exportAllowed ? (
          <div className="report-actions"><button type="button" className="btn" disabled={loading || exporting} onClick={() => exportReport('csv')}>{exporting ? 'Preparing…' : 'Download CSV'}</button><button type="button" className="btn-ghost" disabled={loading || exporting} onClick={() => exportReport('print')}>Print / Save PDF</button></div>
        ) : data ? (
          <p className="muted" style={{ margin: '14px 0 0' }}>
            Only Accounting administrators can export municipal COA summaries.
          </p>
        ) : null}
      </CoaSummaryHero>
      {exportError ? <div className="error" role="alert">Export could not be prepared. {exportError} The loaded report remains available.</div> : null}
      {data ? <p className="muted">Generated {data.generated_at} ({data.timezone}) · {data.scope} · Prepared by {data.prepared_by}</p> : null}
      {data?.outstanding_transfers != null ? <p className="muted">{data.outstanding_transfers} outstanding transfers at cutoff · {data.carried_forward_transfers ?? '—'} sent before this period</p> : null}
      <div className="toolbar report-sections"><Segmented value={section} onChange={changeSection} options={sectionOptions} /></div>
      <div className="report-section" role="tabpanel" aria-label="Overview" hidden={section !== 'overview'}>
        <ReportFlowMetrics data={data} />
        <ReportOfficeTotals data={data} loading={loading} periodNoun={periodNoun} />
      </div>
      <div className="report-section" role="tabpanel" aria-label="Departments" hidden={section !== 'departments'}>
        <DepartmentPerformance />
      </div>
      <div className="report-section" role="tabpanel" aria-label="Register" hidden={section !== 'register'}>
        <ReportRegister view={view} onChange={changeView} offices={data?.office_totals || []} revision={revision} enabled={!error && !!data} asOf={data?.as_of || data?.period_end} movementWatermark={data?.movement_watermark} correctionWatermark={data?.correction_watermark} />
      </div>
      {isAccounting ? (
        <div className="report-section" role="tabpanel" aria-label="Exceptions" hidden={section !== 'exceptions'}>
          <div className="card sf-life__panel">
            <h3 className="section-title">Audit exceptions · {periodLabel}</h3>
            <p className="muted" style={{ marginTop: 0 }}>
              Missing receipt records after 24 hours, receiver mismatches, route gaps and incomplete DV contents. Review the full history; permitted route exceptions may need context.
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
        </div>
      ) : null}
    </div>
  )
}

/** Completion rate and average time at an office; hidden for an older API that does not send them. */
export function ReportFlowMetrics({ data }) {
  const completion = data?.completion
  const time = data?.processing_time
  if (!completion && !time) return null
  return <div className="card sf-life__panel report-flow-metrics">
    <h3 className="section-title">Completion and time at offices</h3>
    {completion ? <div className="list-item list-item--static"><strong>Trail completion</strong><span className="muted">{completion.percent == null ? 'No folders with activity in this period' : `${completion.completed} of ${completion.of} folders · ${completion.percent}%`}</span></div> : null}
    {time ? <div className="list-item list-item--static"><strong>Average time at an office</strong><span className="muted">{time.average_hours == null ? 'No folders were forwarded in this period' : `${formatHours(time.average_hours)} before forwarding · ${time.forwarded_stays} forwarded, ${time.open_stays} still at the office`}</span></div> : null}
    <details className="report-basis"><summary>How these are counted</summary>{completion?.basis ? <p>{completion.basis}</p> : null}{time?.basis ? <p>{time.basis}</p> : null}</details>
  </div>
}

export function ReportOfficeTotals({ data, loading, periodNoun }) {
  return <div className="card sf-life__panel">
    <h3 className="section-title">By office</h3>
    {loading && !data ? <LifeSkeleton rows={3} label="Loading office totals" /> : !data ? <p className="muted">Office totals are unavailable until the report loads.</p> : (data.office_totals || []).length === 0 ? <LifeEmpty icon="coa">{`No office totals for this ${periodNoun}.`}</LifeEmpty> : <><p className="muted">Distinct folders with activity at each office. A folder can appear under several offices; these counts do not mean completed work.</p>{data.office_totals.map(row => <div key={row.office_id || row.office_code} className="list-item list-item--static"><strong>{row.office_name || row.office_code}</strong><span className="muted">{row.docs_processed ?? row.processed ?? '—'} folders with activity{row.forwarded_stays == null ? '' : row.avg_hours_at_office == null ? ' · none forwarded' : ` · avg ${formatHours(row.avg_hours_at_office)} before forwarding`}</span></div>)}</>}
  </div>
}
