// Local visual review of the real screens. All API calls stay in memory.
import React, { useState } from 'react'
import { createRoot } from 'react-dom/client'
import { Link, MemoryRouter, Route, Routes, useNavigate } from 'react-router-dom'
import { AuthProvider, useAuth } from '../src/auth.jsx'
import Layout from '../src/components/Layout.jsx'
import DocumentsPage from '../src/pages/DocumentsPage.jsx'
import RegisterPage from '../src/pages/RegisterPage.jsx'
import RequestsPage from '../src/pages/RequestsPage.jsx'
import HistoryPage from '../src/pages/HistoryPage.jsx'
import ScanPage from '../src/pages/ScanPage.jsx'
import AlertsPage from '../src/pages/AlertsPage.jsx'
import ProfilePage from '../src/pages/ProfilePage.jsx'
import AdminReportsPage from '../src/pages/AdminReportsPage.jsx'
import AdminOfficesPage from '../src/pages/AdminOfficesPage.jsx'
import AdminThresholdsPage from '../src/pages/AdminThresholdsPage.jsx'
import AdminUsersPage from '../src/pages/AdminUsersPage.jsx'
import AdminQrMonitorPage from '../src/pages/AdminQrMonitorPage.jsx'
import AdminSystemPage from '../src/pages/AdminSystemPage.jsx'
import StaffHomePage from '../src/pages/StaffHomePage.jsx'
import HeadHomePage from '../src/pages/HeadHomePage.jsx'
import HeadAnalyticsPage from '../src/pages/HeadAnalyticsPage.jsx'
import AdminHomePage from '../src/pages/AdminHomePage.jsx'
import { documentTypesForOffice } from '../src/tracking.js'
import { reportConnection } from '../src/connection.js'
import reportPrint from './report-preview.html?raw'
import reportCsv from './report-preview.csv?raw'
import '../src/index.css'
import '../src/sf-life.css'
import '../src/page-layout.css'
import '../src/finishing-polish.css'
import '../src/phone-pages.css'
import '../src/phone-forms.css'
import '../src/phone-lists.css'
import '../src/phone-shell.css'

const reviewParams = new URLSearchParams(window.location.search)
const requestedRole = reviewParams.get('role')
const reviewRole = ['staff', 'head'].includes(requestedRole) ? requestedRole : 'admin'
const reviewHome = reviewRole === 'admin' ? '/admin' : reviewRole === 'head' ? '/head' : '/home'
const reviewPages = {
  '/home': StaffHomePage, '/head': HeadHomePage, '/admin': AdminHomePage,
  '/documents': DocumentsPage, '/requests': RequestsPage, '/register': RegisterPage,
  '/scan': ScanPage, '/history': HistoryPage, '/alerts': AlertsPage, '/profile': ProfilePage,
  '/head/analytics': HeadAnalyticsPage, '/admin/reports': AdminReportsPage,
  '/admin/offices': AdminOfficesPage, '/admin/thresholds': AdminThresholdsPage,
  '/admin/users': AdminUsersPage, '/admin/qr-monitor': AdminQrMonitorPage,
  '/admin/system': AdminSystemPage, '/reports': AdminReportsPage,
}
const requestedPage = reviewParams.get('page') || 'documents'
const pageUrl = new URL(requestedPage === 'home' ? reviewHome : `/${requestedPage.replace(/^\/+/, '')}`, location.origin)
const reviewPath = Object.hasOwn(reviewPages, pageUrl.pathname) ? pageUrl.pathname : '/documents'
for (const key of ['id', 'view', 'request_id', 'tab', 'filter', 'q', 'page']) if (reviewParams.has(key)) pageUrl.searchParams.set(key, reviewParams.get(key))
const initialEntry = reviewPath + pageUrl.search
const homeReview = ['/home', '/head', '/admin'].includes(reviewPath)
const emptyReview = reviewParams.get('state') === 'empty'
const failedReview = reviewParams.get('state') === 'error'
const volumeReview = reviewParams.get('state') === 'volume'
const longReview = reviewParams.get('state') === 'long'
const busyHome = !emptyReview && (!homeReview || ['busy', 'long'].includes(reviewParams.get('state')))
const reviewUser = { id:9002, role:reviewRole, name:longReview ? 'Sample Maria Alexandra de los Santos — Municipal Accounting and Financial Records Coordinator' : `Sample Accounting ${reviewRole}`, username:`sample.acc.${reviewRole}`, email:`sample.${reviewRole}@smartflow.test`, office_id:103, office_code:'ACC', office_name:'Accounting Office', is_active:true, avatar_url:null }
// This page gets its own storage object. Real saved accounts and tokens are never read or changed.
const fixtureStorage = new Map([['sf_token', 'sample-session-only'], ['sf_user', JSON.stringify(reviewUser)]])
const sessionReview = reviewParams.get('state') === 'session'
const sampleAccounts = [reviewUser, { ...reviewUser, id:9003, name:'Sample Accounting second account', username:'sample.acc.second' }]
if (sessionReview) for (const account of sampleAccounts) fixtureStorage.set(`sf_role_tip_seen_v2_${account.username.trim().toLowerCase()}`, '1')
const sessionChannel = sessionReview ? new BroadcastChannel('smartflow-ui-review-synthetic-sessions') : null
function changeSampleSession(index, broadcast = true) {
  const user = sampleAccounts[index]
  if (user) {
    fixtureStorage.set('sf_token', index === 0 ? 'sample-session-only' : 'sample-second-session-only')
    fixtureStorage.set('sf_user', JSON.stringify(user))
  } else {
    fixtureStorage.delete('sf_token')
    fixtureStorage.delete('sf_user')
  }
  // The browser's native storage remains untouched. These events exercise the
  // real provider using only this review page's in-memory account data.
  window.dispatchEvent(new StorageEvent('storage', { key:'sf_token' }))
  if (broadcast) sessionChannel?.postMessage({ account:index })
}
if (sessionChannel) sessionChannel.onmessage = event => {
  if ([-1, 0, 1].includes(event.data?.account)) changeSampleSession(event.data.account, false)
}
Object.defineProperty(window, 'localStorage', { configurable:true, value:{
  get length() { return fixtureStorage.size },
  key: (index) => [...fixtureStorage.keys()][index] ?? null,
  getItem: (key) => fixtureStorage.get(String(key)) ?? null,
  setItem: (key, value) => fixtureStorage.set(String(key), String(value)),
  removeItem: (key) => fixtureStorage.delete(String(key)),
  clear: () => fixtureStorage.clear(),
} })
// History's recent IDs and help preferences are isolated too.
const fixtureSession = new Map()
Object.defineProperty(window, 'sessionStorage', { configurable:true, value:{
  get length() { return fixtureSession.size },
  key: (index) => [...fixtureSession.keys()][index] ?? null,
  getItem: (key) => fixtureSession.get(String(key)) ?? null,
  setItem: (key, value) => fixtureSession.set(String(key), String(value)),
  removeItem: (key) => fixtureSession.delete(String(key)),
  clear: () => fixtureSession.clear(),
} })
const reviewOffice = { id:reviewUser.office_id, code:reviewUser.office_code, name:reviewUser.office_name }
const offices = [['ENG', 'Engineering Office'], ['BUD', 'Budget Office'], ['ACC', 'Accounting Office'], ['TRE', 'Treasury Office'], ['MAY', 'Mayor’s Office']]
  .map(([code, name], index) => code === reviewOffice.code ? reviewOffice : { id: 101 + index, code, name })
const budgetOffice = offices.find((office) => office.code === 'BUD')
const accountingOffice = offices.find((office) => office.code === 'ACC')
const engineeringOffice = offices.find((office) => office.code === 'ENG')
const sample = {
  id: 'DOC-2026-000001', title: longReview ? `Road rehabilitation — supporting schedules ${'VeryLongProjectReference'.repeat(6)}` : 'Road rehabilitation — Phase 1 disbursement voucher',
  type: 'Disbursement Voucher', reference_no: 'ENG-DV-2026-001',
  origin_office_name: reviewOffice.name, current_office_name: reviewOffice.name,
  origin_office_id: engineeringOffice.id, current_office_id: reviewOffice.id, current_status: 'IN', tray: 'in_office', last_movement_id: 5,
  visited_office_codes: ['ENG', 'BUD', 'ACC'], trail_complete:false,
  last_scanned_at: '2026-10-03 09:30:00', qr_payload: 'DOC-2026-000001',
  initial_in_recorded: true, due_at_display: 'Oct 10, 2026', qr_expires_at: '2027-04-01T09:30:00',
  due_at: '2026-10-10 17:00:00', hours_waiting: 4, is_overdue: false,
  registered_by: {name:'Sample Engineering clerk', office_name:engineeringOffice.name, registered_at:'2026-10-01 08:00:00'},
  linked_requests: [{id:101, purpose:'Signed cost estimate and approved program of work for municipal access road rehabilitation.', user_name:'Sample Engineering requester', office_name:engineeringOffice.name, created_at:'2026-10-01 07:45:00'}],
  journey: [
    {id:1,status:'IN',office_name:engineeringOffice.name,office_code:'ENG',user_name:'Sample Engineering clerk',scanned_at:'2026-10-01 08:00:00',elapsed_hours:2,duration_kind:'at_office',is_current:false},
    {id:2,status:'OUT',office_name:engineeringOffice.name,office_code:'ENG',destination_office_name:budgetOffice.name,destination_office_code:'BUD',user_name:'Sample Engineering clerk',scanned_at:'2026-10-01 10:00:00',elapsed_hours:1,duration_kind:'in_transit',is_current:false},
    {id:3,status:'IN',office_name:budgetOffice.name,office_code:'BUD',user_name:'Sample Budget clerk',scanned_at:'2026-10-01 11:00:00',elapsed_hours:20,duration_kind:'at_office',is_current:false},
    {id:4,status:'OUT',office_name:budgetOffice.name,office_code:'BUD',destination_office_name:reviewOffice.name,destination_office_code:'ACC',user_name:'Sample Budget clerk',scanned_at:'2026-10-02 07:00:00',elapsed_hours:1,duration_kind:'in_transit',is_current:false},
    {id:5,status:'IN',office_name:reviewOffice.name,office_code:'ACC',user_name:reviewUser.name,scanned_at:'2026-10-02 08:00:00',elapsed_hours:4,duration_kind:'at_office',is_current:true},
  ],
}
const documents = [sample,
  {...sample, id: 'DOC-2026-000002', title: 'Approved budget for municipal road maintenance', type: 'Approved Budget', reference_no:'BUD-2026-001', origin_office_name:'Budget Office', last_scanned_at:'2026-10-01 10:00:00', due_at_display:'Oct 2, 2026 · 5:00 PM', current_status: 'OUT', tray: 'incoming', current_office_id:budgetOffice.id, current_office_name:budgetOffice.name, destination_office_id:reviewOffice.id, destination_office_name:reviewOffice.name, is_overdue:true, due_at:'2026-10-02 17:00:00', hours_waiting:26, last_movement_id:12, journey:[
    {id:10, status:'IN', office_name:'Budget Office', user_name:'Sample clerk', scanned_at:'2026-10-01 08:00:00', elapsed_hours:2, duration_kind:'at_office', is_current:false},
    {id:11, status:'OUT', office_name:budgetOffice.name, destination_office_name:reviewOffice.name, user_name:'Sample clerk', scanned_at:'2026-10-01 10:00:00', elapsed_hours:26, duration_kind:'in_transit', is_current:true},
  ]},
  {...sample, id: 'DOC-2026-000003', title: 'Completed inspection report', tray: 'completed'},
  {...sample, id: 'DOC-2026-000004', title: 'Supporting documents for rehabilitation of the municipal access road and drainage facilities in Barangay Poblacion', current_status: 'OUT', tray: 'forwarded', destination_office_name: 'Budget Office'},
  {...sample, id: 'DOC-2026-000005', title: 'Signed engineering plans and supporting schedules', type: 'Others: Engineering plans', reference_no: 'ENG-PLANS-001'},
]
if (reviewParams.get('state') === 'contents') {
  documents.find(document => document.id === 'DOC-2026-000002').folder_inventory = {
    total_pages: 8, status: 'complete', items: [
      {id:'main', name:'Main document', pages:2, required:true},
      {id:'attachment-1', name:'Signed supporting schedule for municipal road maintenance', pages:6, required:true},
    ],
  }
}
if (['correction', 'correction-read-retry'].includes(reviewParams.get('state'))) {
  Object.assign(sample, {current_status:'OUT', tray:'forwarded', destination_office_id:budgetOffice.id,
    destination_office_name:budgetOffice.name, destination_office_code:'BUD', last_movement_id:6,
    can_correct_destination:reviewRole === 'staff', last_destination_correction_id:0, destination_corrections:[],
    journey:[...sample.journey.map(row=>({...row,is_current:false})),{id:6,status:'OUT',office_name:reviewOffice.name,user_name:reviewUser.name,
      destination_office_name:budgetOffice.name,destination_office_code:'BUD',scanned_at:'2026-10-15 09:00:00',is_current:true,duration_kind:'in_transit',elapsed_hours:1}]})
}
if (reviewParams.get('state') === 'outside') Object.assign(sample, {
  current_status:'IN',current_office_id:offices.find(office=>office.code==='TRE').id,current_office_name:'Treasury Office',
  current_office_code:'TRE',can_file:false,can_correct_destination:false,
})
if (reviewParams.get('state') === 'receipt-history') {
  sample.folder_inventory = {total_pages:5, status:'complete', items:[{id:'main',name:'Main document',pages:2,required:true},{id:'schedule',name:'Signed supporting schedule',pages:3,required:true}]}
  const receipt = {total_pages:3,registered_total_pages:5,status:'incomplete',confirmed:true,reason:'Two signed supporting pages were missing.\nThe receiving clerk counted the physical folder.',items:[{id:'main',name:'Main document',registered_pages:2,pages:2,required:true},{id:'schedule',name:'Signed supporting schedule',registered_pages:3,pages:1,required:true}]}
  const latest = sample.journey.at(-1)
  latest.contents_receipt=receipt
  latest.remarks=`Received at ${reviewOffice.name}\nIncomplete contents: 3/5 registered pages; Signed supporting schedule: 1/3 pages; ${receipt.reason}`
  sample.current_contents_receipt={...receipt,checked_at:latest.scanned_at,checked_by:reviewUser.name,office_name:reviewOffice.name}
  sample.contents_status='incomplete'
}
if (reviewParams.get('state') === 'wrong-destination') {
  const destination = offices.find(office=>office.code==='TRE')
  const correction={id:1,previous_destination_office_name:reviewOffice.name,destination_office_name:destination.name,reason:'The receiving office was recorded incorrectly; the folder is addressed to Treasury.',corrected_by_name:'Sample Budget clerk',corrected_at:'2026-10-15 09:05:00'}
  Object.assign(sample,{current_status:'OUT',current_office_id:budgetOffice.id,current_office_name:budgetOffice.name,current_office_code:budgetOffice.code,destination_office_id:destination.id,destination_office_name:destination.name,destination_office_code:destination.code,tray:'elsewhere',last_movement_id:6,last_destination_correction_id:1,can_correct_destination:false,destination_corrections:[correction]})
  sample.journey=[...sample.journey.map(row=>({...row,is_current:false})),{id:6,status:'OUT',office_name:budgetOffice.name,office_code:budgetOffice.code,destination_office_name:destination.name,destination_office_code:destination.code,user_name:'Sample Budget clerk',scanned_at:'2026-10-15 09:00:00',destination_corrections:[correction],is_current:true}]
}
const requestBase = {
  request_kind: 'access', document_category: 'other', required_by: '2026-10-12', required_by_display: 'Oct 12, 2026',
  created_at: '2026-10-10 09:00:00', reviewed_at: null, fulfilled_at: null, related_document_id: null, review_notes: null,
  requester: { user_id: 9001, name: 'Engineering requester', office_id: engineeringOffice.id, office_name: engineeringOffice.name, office_code: 'ENG' },
  handler_office: { office_id: reviewOffice.id, office_name: reviewOffice.name, office_code: reviewOffice.code },
}
const seedCategory = documentTypesForOffice(reviewOffice.code).includes('Approved Budget') ? 'budget' : documentTypesForOffice(reviewOffice.code).includes('Disbursement Voucher') ? 'disbursement' : 'other'
const requests = [
  {...requestBase, id: 101, request_code: 'REQ-2026-0101', status: 'pending', is_overdue: true,
    purpose: 'Please review the complete engineering plans for the rehabilitation of the municipal access road and drainage facilities in Barangay Poblacion. Include the signed cost estimate, approved program of work, inspection photographs, and the schedule showing how each proposed item relates to the current project budget. This final sentence must remain fully readable before the receiving office decides whether to accept or decline the request.'},
  {...requestBase, id: 102, request_code: 'REQ-2026-0102', status: 'approved', is_overdue: true, reviewed_at: '2026-10-11 10:00:00',
    purpose: 'Provide signed engineering plans and supporting schedules for the road maintenance project.', review_notes: 'Accepted. The signed plans are being prepared; the delivery is still outstanding.'},
  {...requestBase, id: 103, request_code: 'REQ-2026-0103', status: 'rejected', is_overdue: false, reviewed_at: '2026-10-11 11:15:00',
    requester: {...requestBase.requester, user_id: reviewUser?.id || 9002, name: reviewUser?.name || 'Current requester'},
    purpose: 'Request the missing supporting documents for the road rehabilitation proposal.',
    review_notes: 'The program of work has not been signed by the project engineer. Attach the signed copy and include the correct project reference before submitting a new request.\nPlease call the handling office if the signed schedule has already been delivered.'},
  {...requestBase, id: 104, request_code: 'REQ-2026-0104', status: 'approved', is_overdue: false, document_category: 'disbursement',
    handler_office: {office_id: accountingOffice.id, office_name: accountingOffice.name, office_code: 'ACC'},
    purpose: 'Release payment for the completed road maintenance work after the DV route and supporting checks.', reviewed_at: '2026-10-11 14:00:00', related_document_id: sample.id,
    review_notes: 'Accounting accepted the DV request. Treasury records actual payment release.'},
  {...requestBase, id: 105, request_code: 'REQ-2026-0105', status: 'approved', is_overdue: false, document_category: seedCategory,
    purpose: 'Road maintenance project folder — registered from an accepted request', reviewed_at: '2026-10-11 15:00:00'},
]
if (reviewParams.get('state') === 'past-only') {
  for (const request of requests) { request.status = 'fulfilled'; request.is_overdue = false }
}
const sampleActor = {user_id:reviewUser.id,name:reviewUser.name,username:reviewUser.username,office_id:reviewOffice.id,office_name:reviewOffice.name,office_code:reviewOffice.code}
for (const request of requests) {
  request.revision='a'.repeat(64)
  request.review_notes_kind='review'
  if (request.reviewed_at) request.reviewer=sampleActor
}
if (reviewParams.get('state') === 'request-history') {
  Object.assign(requests.find(row=>row.id===104), {status:'fulfilled',review_notes_kind:'review',review_notes:'Accounting accepted the request after reviewing the signed schedules.\nThe original acceptance note remains available in full.',reviewer:{...sampleActor,name:'Sample Accounting reviewer'},fulfilled_notes:'Treasury recorded actual payment release.\nComplete release notes remain separate from acceptance.',fulfilled_at:'2026-10-15 14:30:00',fulfiller:{...sampleActor,name:'Sample Treasury clerk',office_name:'Treasury Office',office_code:'TRE'}})
  Object.assign(requests.find(row=>row.id===102), {status:'cancelled',cancelled_at:'2026-10-15 15:00:00',cancelled_notes:'The requester cancelled this work after the scope changed.\nKeep the original acceptance for reference.',canceller:{...sampleActor,name:'Sample requester'},review_notes:'Accepted by the handling office before the requester changed the scope.'})
  Object.assign(requests.find(row=>row.id===105), {status:'fulfilled',review_notes_kind:'legacy',review_notes:'Legacy recorded note; its original review or closing stage is unknown.',fulfilled_notes:null,fulfilled_at:'2026-10-13 16:00:00',reviewer:null,fulfiller:null})
}
if (['filing','filing-conflict','filing-read-retry','session'].includes(reviewParams.get('state'))) Object.assign(sample,{type:'Others: Inspection schedules',can_file:true})
let sampleWriteCount = 0
let offline = false
if (volumeReview) for (let index = 0; index < 115; index++) requests.push({ ...requestBase, id: 1000 + index, request_code: `REQ-2026-${1000 + index}`, purpose: `Sample paged request ${index + 1}`, status: index === 114 ? 'approved' : 'pending', is_overdue: true })
const creationResults = new Map()
if (reviewParams.get('state') === 'recovery') {
  const id = 'a'.repeat(32)
  const recovered = { ...requests[0], id: 9100, request_code: 'REQ-2026-9100', is_overdue: false, purpose: 'Sample interrupted submission — recover this same ticket', requester: { ...sampleActor }, handler_office: { office_id: budgetOffice.id, office_name: budgetOffice.name, office_code: budgetOffice.code } }
  requests.push(recovered)
  fixtureStorage.set(`sf_creation_v1_${reviewUser.id}_${reviewUser.office_id}_request`, JSON.stringify({ id, body: { request_kind: 'access', document_category: 'budget', purpose: 'Sample interrupted submission — recover this same ticket', required_by: '2026-10-20' } }))
  creationResults.set(id, { kind: 'request', result: { success: true, request: recovered } })
}
const report = {period:'month', month:'2026-10', year:'2026', quarter:null, period_label:'October 2026', office_id:4, export_allowed:true, period_start:'2026-10-01 00:00:00', period_end:'2026-10-31 23:59:59', generated_at:'2026-10-03 14:00:00', timezone:'Asia/Manila', scope:'Municipal system (all offices)', prepared_by:'Sample Accountant · Accounting Office', totals:{documents_in_period:40}, compliance:{on_time:{count:30, percent:75}, unforwarded:{count:6, percent:15}, delayed:{count:4, percent:10}}, office_totals:offices.map((o,i) => ({office_id:o.id, office_name:o.name, office_code:o.code, docs_processed:[40,30,24,16,8][i]}))}
const reportRows = Array.from({ length: 42 }, (_, index) => {
  const carried = index >= 40
  const classification = index < 30 ? 'on_time' : index < 36 || carried ? 'unforwarded' : 'delayed'
  const office = offices[index % offices.length]
  return { document_id: `DOC-2026-${String(index + 1).padStart(6, '0')}`, title: index === 0 ? sample.title : longReview ? `Signed supporting schedules for municipal road and infrastructure works — verification of supporting records and all original inspection attachments ${index + 1}` : `Sample custody folder ${index + 1}`, type: index % 2 ? 'Disbursement Voucher' : 'Others: Supporting schedules', classification,
    current_status: classification === 'unforwarded' ? 'OUT' : 'IN', current_office_id: office.id, current_office_name: office.name, current_office_code: office.code, destination_office_id: accountingOffice.id, destination_office_name: accountingOffice.name, destination_office_code: accountingOffice.code,
    last_scanned_at: carried ? '2026-09-28 09:00:00' : '2026-10-02 09:00:00', recorded_by: 'Sample recording clerk', last_received_at: carried ? '2026-09-27 08:00:00' : '2026-10-01 08:00:00', received_by: 'Sample receiving clerk', last_sent_at: carried ? '2026-09-28 09:00:00' : '2026-10-02 09:00:00', sent_by: 'Sample sending clerk', receipt_wait_hours: classification === 'unforwarded' ? (carried ? 121 : 24) : null, movement_count: 4, carried_forward: carried }
})
const adminOffices = offices.map((office, index) => ({office_id:office.id, office_code:office.code, office_name:office.name,
  thresholds: index === 4 || emptyReview ? [] : [
    {document_type:documentTypesForOffice(office.code)[0] || 'Others', max_hours:48, out_unconfirmed_hours:24},
    {document_type:'Others: Signed program of work, inspection photographs, supporting schedules, and complete project cost estimates', max_hours:72, out_unconfirmed_hours:12},
  ]}))
const users = [reviewUser,
  {id:9003, name:'Sample Maria Alexandra de los Santos — Financial Records Coordinator', username:'sample.financial.records.coordinator', role:'head', office_code:'ACC', office_name:accountingOffice.name, is_active:true},
  {id:9004, name:'Sample Engineering clerk', username:'sample.eng.clerk', role:'staff', office_code:'ENG', office_name:engineeringOffice.name, is_active:true},
  {id:9005, name:'Sample Treasury clerk', username:'sample.tre.clerk', role:'staff', office_code:'TRE', office_name:'Treasury Office', is_active:false},
]
const pendingSignups = [
  {id:601, request_code:'SIGNUP-2026-0601', full_name:'Sample Isabel Santiago — Municipal Infrastructure Records Assistant', username:'sample.infrastructure.assistant', email:'sample.infrastructure@smartflow.test', requested_role:'staff', office_name:engineeringOffice.name, office_code:'ENG', created_at:'2026-10-14 08:15:00'},
  {id:602, request_code:'SIGNUP-2026-0602', full_name:'Sample Budget reviewer', username:'sample.bud.reviewer', email:'sample.budget@smartflow.test', requested_role:'head', office_name:budgetOffice.name, office_code:'BUD', created_at:'2026-10-14 09:30:00'},
]
const alerts = documents.slice(0, 3).map((doc, index) => ({document_id:doc.id, document_title:doc.title,
  kind:['delayed','due_soon','unconfirmed'][index], last_office_name:index === 1 ? budgetOffice.name : reviewOffice.name,
  last_office_code:index === 1 ? 'BUD' : reviewOffice.code, hours_pending:[72,36,18][index], days_pending:index === 0 ? 3 : 0,
  last_status:index === 2 ? 'OUT' : 'IN', due_at:doc.due_at, last_scanned_at:doc.last_scanned_at,
  detail:index === 2 ? 'Receipt has not been recorded after this folder was sent.' : index === 0 ? 'The recorded folder deadline has passed.' : 'This folder is approaching its recorded deadline.'}))
const exceptions = [
  {document_id:documents[1].id, exception_type:'unforwarded', detail:'Folder has been waiting for the receiving office to confirm custody after the recorded OUT handoff.', last_scanned_at:'2026-10-12 09:00:00'},
  {document_id:documents[3].id, exception_type:'wrong_receiver', detail:longReview ? `Unexpected receiving office. ${'LongAuditReference'.repeat(10)}` : 'The receiving office differs from the destination recorded by the sending clerk.', last_scanned_at:'2026-10-13 10:30:00'},
  {document_id:documents[0].id, exception_type:'incomplete_contents', detail:'Declared required attachments are missing or short', last_scanned_at:'2026-10-12 08:00:00'},
]
const scanEvents = ['success','rejected','failed'].map((outcome, index) => ({id:701 + index, document_id:documents[index].id,
  created_at:`2026-10-14 ${10 + index}:15:00`, scanned_at:`2026-10-14 ${10 + index}:15:00`, username:users[index].username,
  office_code:users[index].office_code, outcome, event_type:'movement.create',
  message:['Received (IN) at Accounting Office. Folder contents confirmed.', 'Rejected duplicate IN scan: the folder is already recorded at this office.', longReview ? `Connection failed while recording the custody handoff. ${'LongAuditDiagnostic'.repeat(8)}` : 'Connection interruption. Clerk should check the latest record before retrying.'][index]}))
const activityEvents = [
  {id:801, created_at:'2026-10-14 10:00:00', username:reviewUser.username, office_code:reviewOffice.code, event_type:'signup.approve', message:'Approved the sample Engineering clerk account.'},
  {id:802, created_at:'2026-10-14 09:30:00', username:reviewUser.username, office_code:reviewOffice.code, event_type:'threshold.update', message:'Changed the Accounting processing threshold for Disbursement Voucher from 48 hours to 72 hours.'},
  {id:803, created_at:'2026-10-14 09:00:00', username:users[1].username, office_code:'ACC', event_type:'request.reject', message:requests[2].review_notes},
]
// Only the existing local workflow simulations may change these synthetic arrays.
const localWrites = new Set(['documents-create.php', 'documents-file.php', 'movements-create.php', 'movements-correct-destination.php', 'document-requests-update.php', 'document-requests-create.php', 'admin-thresholds-update.php'])
const movementResults = new Map()
let officeFailurePending = reviewParams.get('state') === 'offices-retry'
let detailFailurePending = reviewParams.get('state') === 'detail-retry'
let queryFailurePending = reviewParams.get('state') === 'query-retry'
let requestSawPast = false
let monitorFailurePending=reviewParams.get('state')==='monitor-retry'
let analyticsFirstMonth=null
let analyticsFailurePending=reviewParams.get('state')==='analytics-query-retry'
let selectedFailurePending=reviewParams.get('state')==='request-detail-retry'
let requestConflictPending=reviewParams.get('state')==='request-conflict'
let postWriteReadFailure = false
const failPostWriteRead = ['post-write-read-retry', 'filing-read-retry', 'correction-read-retry'].includes(reviewParams.get('state'))
const readFailurePending = new Set(reviewParams.get('state') === 'read-retry' ? ['reports-summary.php','users-list.php','signup-pending-list.php'] : reviewParams.get('state') === 'register-retry' ? ['reports-register.php'] : [])
window.fetch = async (url, options = {}) => {
  if (offline) throw new TypeError('Sample connection interruption')
  const parsed = new URL(url, location.origin)
  const endpoint = parsed.pathname.split('/').pop()
  if (endpoint === 'documents-show.php' && postWriteReadFailure) {
    postWriteReadFailure = false
    return new Response(JSON.stringify({success:false,message:'Sample: the action was saved, then the folder-details read failed once.'}),{status:503,headers:{'Content-Type':'application/json'}})
  }
  if (endpoint==='head-analytics.php' && !analyticsFirstMonth) analyticsFirstMonth=parsed.searchParams.get('month')
  const failMonitor=monitorFailurePending && endpoint==='audit-exceptions.php'
  const failAnalytics=analyticsFailurePending && endpoint==='head-analytics.php' && parsed.searchParams.get('month')!==analyticsFirstMonth
  const failSelected=selectedFailurePending && endpoint==='document-requests-list.php' && parsed.searchParams.has('id')
  if (failMonitor || failAnalytics || failSelected) {
    if (failMonitor) monitorFailurePending=false
    if (failAnalytics) analyticsFailurePending=false
    if (failSelected) selectedFailurePending=false
    return new Response(JSON.stringify({success:false,message:'Sample review: this read failed once. Retry the current view.'}),{status:503,headers:{'Content-Type':'application/json'}})
  }
  if ((detailFailurePending && endpoint === 'office-documents.php' && parsed.searchParams.has('id')) || readFailurePending.has(endpoint)) {
    detailFailurePending = false
    readFailurePending.delete(endpoint)
    return new Response(JSON.stringify({success:false,message:'Sample review: this read failed once. Retry to recover.'}),{status:503,headers:{'Content-Type':'application/json'}})
  }
  if (queryFailurePending && ((endpoint === 'office-documents.php' && parsed.searchParams.has('current_office_id')) || (endpoint === 'document-requests-list.php' && requestSawPast && parsed.searchParams.get('status') === 'active' && !parsed.searchParams.has('id')))) {
    queryFailurePending=false
    return new Response(JSON.stringify({success:false,message:'Sample review: the new query is unavailable. Retry this view.'}),{status:503,headers:{'Content-Type':'application/json'}})
  }
  if (endpoint === 'document-requests-list.php' && parsed.searchParams.get('status') === 'past') requestSawPast=true
  if (endpoint === 'offices-list.php' && officeFailurePending) {
    officeFailurePending = false
    return new Response(JSON.stringify({success:false,message:'Sample review: receiving offices could not be loaded.'}), {status:503,headers:{'Content-Type':'application/json'}})
  }
  if (failedReview && ['offices-list.php', 'dashboard-stats.php', 'head-dashboard.php', 'head-analytics.php', 'accountant-dashboard.php', 'office-documents.php', 'office-movements-list.php', 'document-requests-list.php', 'document-requests-summary.php', 'alerts-list.php', 'accountant-alerts.php', 'reports-summary.php', 'reports-register.php', 'users-list.php', 'signup-pending-list.php','audit-scans.php','audit-exceptions.php','audit-activity.php','system-status.php'].includes(endpoint)) {
    return new Response(JSON.stringify({success:false, message:'Sample review: office data is temporarily unavailable.'}), {status:503, headers:{'Content-Type':'application/json'}})
  }
  if (!['GET','HEAD'].includes(String(options.method || 'GET').toUpperCase()) && !localWrites.has(endpoint) && endpoint !== 'qr-verify.php') {
    return new Response(JSON.stringify({success:false, message:'Sample preview: account and configuration changes are disabled.'}), {status:405})
  }
  const body = options.body ? JSON.parse(options.body) : {}
  if (body.operation_id && creationResults.has(body.operation_id)) return new Response(JSON.stringify(creationResults.get(body.operation_id).result), {headers:{'Content-Type':'application/json'}})
  let data = {}
  if (endpoint === 'movement-requests.php') {
    const saved = movementResults.get(parsed.searchParams.get('request_id'))
    data = {state:saved ? 'recorded':'unknown',result:saved || null}
  }
  else if (endpoint === 'movements-correct-destination.php') {
    if (movementResults.has(body.request_id)) return new Response(JSON.stringify(movementResults.get(body.request_id)), {headers:{'Content-Type':'application/json'}})
    const document = documents.find(row=>row.id===body.document_id)
    const destination = offices.find(row=>row.id===body.destination_office_id)
    if (reviewRole !== 'staff' || !document || document.current_status !== 'OUT' || document.last_movement_id !== body.expected_movement_id || document.destination_office_id !== body.expected_destination_office_id || (document.last_destination_correction_id || 0) !== body.expected_correction_id || !destination || !body.correction_confirmed || String(body.reason || '').trim().length < 5) return new Response(JSON.stringify({success:false,message:'Sample custody changed or correction evidence is incomplete.'}),{status:409})
    const correction = {id:(document.last_destination_correction_id || 0)+1,previous_destination_office_name:document.destination_office_name,destination_office_name:destination.name,reason:body.reason,corrected_by_name:reviewUser.name,corrected_at:'2026-10-15 10:00:00'}
    document.destination_corrections = [...(document.destination_corrections || []),correction]
    document.last_destination_correction_id = correction.id
    document.destination_office_id=destination.id; document.destination_office_name=destination.name; document.destination_office_code=destination.code
    document.journey=document.journey.map(row=>row.id===document.last_movement_id ? {...row,destination_office_name:destination.name,destination_office_code:destination.code,destination_corrections:document.destination_corrections}:row)
    data={document_id:document.id,movement_id:document.last_movement_id,correction_id:correction.id,message:`Recorded destination corrected to ${destination.name}. No receipt or new handoff was recorded.`}
    movementResults.set(body.request_id,{success:true,...data})
    if (failPostWriteRead) postWriteReadFailure=true
  }
  else if (endpoint === 'creation-requests.php') {
    const saved = creationResults.get(parsed.searchParams.get('operation_id'))
    data = { state: saved?.kind === parsed.searchParams.get('kind') ? 'recorded' : 'unknown', result: saved?.kind === parsed.searchParams.get('kind') ? saved.result : null }
  }
  else if (endpoint === 'office-movements-list.php') {
    const events = emptyReview ? [] : Array.from({length: volumeReview ? 60 : 13}, (_, index) => ({ id: index + 1, document_id: sample.id, title: `Sample office movement ${index + 1}`, status: index % 2 ? 'OUT' : 'IN', user_name: 'Sample clerk', office_name: reviewOffice.name, scanned_at: `${parsed.searchParams.get('date') || '2026-10-15'} 10:${String(index % 60).padStart(2,'0')}:00`, remarks: 'Synthetic office activity' }))
    const status = parsed.searchParams.get('status')
    const rows = events.filter(row => !status || row.status === status)
    const pageSize = Number(parsed.searchParams.get('page_size') || 25)
    const page = Math.min(Number(parsed.searchParams.get('page') || 1), Math.max(1, Math.ceil(rows.length/pageSize)))
    data = {movements:rows.slice((page-1)*pageSize,page*pageSize),stats:{total:events.length,in_flow:events.filter(row=>row.status==='IN').length,out_flow:events.filter(row=>row.status==='OUT').length},total:rows.length,page,page_size:pageSize,has_more:page*pageSize<rows.length}
  }
  else if (endpoint === 'office-documents.php') {
    if (reviewParams.get('state') === 'outside' && parsed.searchParams.get('id') === sample.id && parsed.searchParams.get('scope') !== 'municipal') return new Response(JSON.stringify({success:false,message:'Document is not in your office tray'}),{status:404})
    const id = parsed.searchParams.get('id')
    const tray = parsed.searchParams.get('tray')
    const search = (parsed.searchParams.get('search') || '').toLowerCase()
    const overdue = parsed.searchParams.get('overdue') === '1'
    let rows = (emptyReview ? [] : documents).filter((doc) => (!tray || overdue || doc.tray === tray) && (!overdue || doc.is_overdue) && (!search || `${doc.id} ${doc.title} ${doc.reference_no}`.toLowerCase().includes(search)))
    if (parsed.searchParams.get('current_office_id')) rows = rows.filter((doc) => doc.current_office_id === Number(parsed.searchParams.get('current_office_id')))
    const offset = Number(parsed.searchParams.get('offset') || 0)
    const limit = Number(parsed.searchParams.get('limit') || rows.length || 25)
    const scope = parsed.searchParams.get('scope') || 'office'
    data = id ? {document: documents.find(d => d.id === id) || sample, scope, read_only: scope === 'municipal' || reviewUser?.role === 'admin'} : {documents: rows.slice(offset, offset + limit), scope, read_only: scope === 'municipal' || reviewUser?.role === 'admin', total:rows.length, offset, limit, has_more:offset + limit < rows.length, tray_counts:Object.fromEntries(['incoming','in_office','forwarded','completed'].map((name) => [name, documents.filter((doc) => doc.tray === name).length])), overdue_count:documents.filter((doc) => doc.is_overdue).length}
  }
  else if (endpoint === 'offices-list.php') data = {offices}
  else if (endpoint === 'documents-find-by-reference.php') data = {matches: []}
  else if (endpoint === 'documents-create.php') {
    const request = requests.find((row) => row.id === Number(body.request_id))
    if (body.request_id && (!request || request.status !== 'approved' || request.related_document_id)) return new Response(JSON.stringify({success:false, message:'Sample request is not available for registration.'}), {status:409})
    const id = `DOC-2026-${String(documents.length + 1).padStart(6,'0')}`
    const document = {...sample, id, qr_payload:id, title:body.title, type:body.type, reference_no:body.reference_no, payee:body.payee, fund_source:body.fund_source, folder_inventory:body.folder_inventory, request_id:request?.id || null, initial_in_recorded:reviewParams.get('state') !== 'registration-unverified'}
    documents.push(document)
    if (request) request.related_document_id = document.id
    data = {document}
  }
  else if (endpoint==='documents-file.php') {
    const document=documents.find(row=>row.id===body.document_id)
    if (reviewParams.get('state')==='filing-conflict' && document) document.last_movement_id+=1
    if (reviewRole!=='staff' || !document || !document.can_file || Number(body.expected_movement_id)!==document.last_movement_id) return new Response(JSON.stringify({success:false,message:'The folder changed. Refresh and review its current custody before filing.'}),{status:409})
    document.can_file=false; document.tray='completed'; document.trail_complete=true
    if (failPostWriteRead) postWriteReadFailure = true
    data={message:'Sample folder filed with its reviewed movement guard.'}
  }
  else if (endpoint === 'movements-create.php') {
    const document = documents.find((row) => row.id === body.document_id)
    if (!document || Number(body.expected_movement_id) !== document.last_movement_id) return new Response(JSON.stringify({success:false,message:'Sample custody changed. Refresh this folder.'}),{status:409})
    const destination = offices.find((office) => office.id === Number(body.destination_office_id))
    if (body.status === 'OUT' && (!destination || (body.is_return && String(body.remarks || '').trim().length < 5))) return new Response(JSON.stringify({success:false,message:'Choose a destination and provide the correction reason.'}),{status:400})
    document.current_status = body.status
    document.current_office_id = reviewOffice.id
    document.current_office_name = reviewOffice.name
    document.destination_office_id = destination?.id || null
    document.destination_office_name = destination?.name || null
    document.destination_office_code = destination?.code || null
    document.tray = body.status === 'OUT' ? 'forwarded' : 'in_office'
    document.last_movement_id += 1
    document.last_scanned_at = '2026-10-14 16:00:00'
    document.is_overdue = false
    document.hours_waiting = 0
    const remarks = body.is_return ? `Returned to ${destination.name} (${destination.code}): ${body.remarks}` : body.status === 'OUT' ? `Forwarded from ${reviewOffice.name} → ${destination.name}` : `Received at ${reviewOffice.name}`
    const movement = {id:document.last_movement_id,status:body.status,office_id:reviewOffice.id,office_name:reviewOffice.name,office_code:reviewOffice.code,destination_office_name:destination?.name,destination_office_code:destination?.code,user_name:reviewUser.name,scanned_at:document.last_scanned_at,remarks,is_current:true,duration_kind:body.status === 'OUT' ? 'in_transit' : 'at_office',elapsed_hours:0}
    document.journey = [...document.journey.map((row) => ({...row,is_current:false})),movement]
    if (body.contents_receipt && document.folder_inventory) {
      const items = document.folder_inventory.items.map(item => ({...item, registered_pages:item.pages,
        pages:body.contents_receipt.items.find(received => received.id === item.id)?.pages ?? 0}))
      const status = items.some(item => item.required && item.pages < item.registered_pages) ? 'incomplete'
        : items.some(item => item.pages !== item.registered_pages) ? 'discrepancy' : 'complete'
      document.current_contents_receipt = {...body.contents_receipt, items, status,
        total_pages:items.reduce((total,item) => total + item.pages,0), registered_total_pages:document.folder_inventory.total_pages,
        checked_at:document.last_scanned_at, checked_by:reviewUser.name, office_name:reviewOffice.name}
      document.contents_status = status
    }
    data = {movement,message:body.is_return ? `Sample folder returned to ${destination.name}. Correction reason recorded.` : `Sample folder marked ${body.status}.`}
    if (failPostWriteRead) postWriteReadFailure = true
  }
  else if (endpoint === 'alerts-list.php' || endpoint === 'accountant-alerts.php') data = {alerts:emptyReview ? [] : alerts}
  else if (endpoint === 'document-requests-list.php') {
    const view = parsed.searchParams.get('view') || 'inbox'
    const status = parsed.searchParams.get('status')
    const inbox = requests.filter((row) => row.handler_office.office_id === reviewOffice.id || (reviewOffice.code === 'TRE' && row.document_category === 'disbursement' && row.status === 'approved'))
    const scope = emptyReview ? [] : view === 'outbox' ? requests.filter((row) => row.requester.user_id === reviewUser?.id) : inbox
    const id = parsed.searchParams.get('id')
    const search = (parsed.searchParams.get('q') || '').toLowerCase()
    const rows = scope.filter(row => id ? String(row.id) === id : (!status || (status === 'active' ? ['pending', 'approved'].includes(row.status) : status === 'past' ? ['fulfilled', 'rejected', 'cancelled'].includes(row.status) : row.status === status)) && (parsed.searchParams.get('overdue') !== '1' || row.is_overdue) && (!search || `${row.request_code} ${row.purpose} ${row.related_document_id || ''}`.toLowerCase().includes(search)))
    const pageSize = Number(parsed.searchParams.get('page_size') || 25)
    const page = Math.min(Number(parsed.searchParams.get('page') || 1), Math.max(1, Math.ceil(rows.length/pageSize)))
    data = {requests:rows.slice((page-1)*pageSize,page*pageSize),pending_inbox_count:emptyReview?0:inbox.filter(row=>row.status==='pending').length,counts:{total:scope.length,pending:scope.filter(row=>row.status==='pending').length,active:scope.filter(row=>['pending','approved'].includes(row.status)).length,past:scope.filter(row=>['fulfilled','rejected','cancelled'].includes(row.status)).length,overdue:scope.filter(row=>row.is_overdue).length},total:rows.length,page,page_size:pageSize,has_more:page*pageSize<rows.length}
  }
  else if (endpoint === 'document-requests-summary.php') {
    const inbox = requests.filter((row) => row.handler_office.office_id === reviewOffice.id)
    const outboxRows = requests.filter((row) => row.requester.user_id === reviewUser?.id)
    const outbox = Object.fromEntries(['pending','approved','rejected','fulfilled','cancelled'].map((status) => [status,outboxRows.filter((row) => row.status === status).length]))
    data = {pending_inbox_count:inbox.filter((row) => row.status === 'pending').length, overdue_inbox_count:inbox.filter((row) => row.is_overdue).length, overdue_outbox_count:outboxRows.filter((row) => row.is_overdue).length, outbox, outbox_attention_count:outbox.approved + outbox.rejected + outbox.fulfilled, outbox_needs_action_count:outbox.approved + outbox.rejected}
    if (emptyReview || homeReview && !busyHome) data = {...data, pending_inbox_count:0, overdue_inbox_count:0}
  }
  else if (endpoint === 'document-requests-update.php') {
    const request = requests.find((row) => row.id === Number(body.request_id))
    if (!request) return new Response(JSON.stringify({success:false,message:'Sample request not found'}),{status:404})
    if (requestConflictPending) {
      requestConflictPending=false
      Object.assign(request,{status:'cancelled',is_overdue:false,revision:'b'.repeat(64),cancelled_at:'2026-10-15 15:10:00',cancelled_notes:'Cancelled in another sample session while the displayed details were open.',canceller:sampleActor})
      return new Response(JSON.stringify({success:false,message:'This request changed. Refresh and review the latest details before deciding.',request_error:'request_conflict'}),{status:409})
    }
    if (body.expected_status!==request.status || body.expected_revision!==request.revision) return new Response(JSON.stringify({success:false,message:'Sample request changed. Review current details.'}),{status:409})
    if (body.action === 'link') {
      if (request.status !== 'approved' || request.related_document_id) return new Response(JSON.stringify({success:false,message:'Sample request already linked or unavailable.'}),{status:409})
      request.related_document_id = body.related_document_id
    } else {
      request.status = {approve:'approved',reject:'rejected',fulfill:'fulfilled',cancel:'cancelled'}[body.action] || request.status
      if (['approve','reject'].includes(body.action)) {request.reviewed_at='2026-10-14 15:00:00';request.review_notes=body.review_notes || '';request.reviewer=sampleActor}
      if (body.action==='fulfill') {request.fulfilled_at='2026-10-14 15:00:00';request.fulfilled_notes=body.review_notes || '';request.fulfiller=sampleActor}
      if (body.action==='cancel') {request.cancelled_at='2026-10-14 15:00:00';request.cancelled_notes=body.review_notes || 'Cancelled';request.canceller=sampleActor}
    }
    request.is_overdue = ['pending','approved'].includes(request.status) && request.required_by < '2026-10-14'
    request.revision='b'.repeat(64)
    data = {request:{...request}, message:body.action === 'link' ? 'Folder linked. Request remains accepted.' : 'Sample request updated.'}
  }
  else if (endpoint === 'document-requests-create.php') {
    const id = Math.max(...requests.map((row) => row.id)) + 1
    const category = body.request_kind === 'pull' ? 'general' : body.document_category
    const office = category === 'budget' ? budgetOffice : category === 'disbursement' ? accountingOffice : offices.find((row) => row.id === body.target_office_id) || reviewOffice
    const request = {...requestBase, ...body, required_by_display:body.required_by, document_category: category, id, request_code:`REQ-2026-${String(id).padStart(4,'0')}`, status:'pending', is_overdue:false,
      requester:{...requestBase.requester, user_id:reviewUser?.id || 9002, name:reviewUser?.name || 'Current requester', office_id:reviewOffice.id, office_code:reviewOffice.code, office_name:reviewOffice.name}, handler_office:{office_id:office.id, office_code:office.code, office_name:office.name}}
    requests.push(request)
    data = {request}
  }
  else if (endpoint === 'documents-show.php') {
    const document = documents.find((doc) => doc.id === parsed.searchParams.get('id')) || sample
    data = {document:emptyReview ? {...document, registered_by:null, linked_requests:[], journey:[]} : document}
  }
  else if (endpoint === 'documents-movements.php') data = {movements:emptyReview ? [] : (documents.find((doc) => doc.id === parsed.searchParams.get('id')) || sample).journey}
  else if (endpoint === 'qr-verify.php') data = {document_id:sample.id, qr_payload:body.qr}
  else if (endpoint === 'dashboard-stats.php') data = {
    stats:{in_flow:busyHome ? 8 : 0, out_flow:busyHome ? 5 : 0, active_tags:busyHome ? 2 : 0},
    active_documents:busyHome ? documents.filter((doc) => doc.tray === 'in_office').map((doc) => ({...doc, document_id:doc.id})) : [],
    in_transit:busyHome ? documents.filter((doc) => doc.tray === 'incoming').map((doc) => ({...doc, document_id:doc.id, last_office_name:doc.current_office_name})) : [],
    recent_movements:busyHome ? sample.journey.map((movement) => ({...movement, document_id:sample.id, title:sample.title, type:sample.type})) : [],
  }
  else if (endpoint === 'head-dashboard.php') data = {stats:{in_office:busyHome ? 3 : 0, overdue:busyHome ? 1 : 0, avg_hours:busyHome ? 4.2 : 0}, queue:busyHome ? documents.map((doc) => ({...doc, document_id:doc.id, status_label:doc.is_overdue ? 'overdue' : 'in_office', hours_pending:doc.hours_waiting})) : []}
  else if (endpoint === 'accountant-dashboard.php') data = {stats:{active_documents:busyHome ? 3 : 0, overdue:busyHome ? 1 : 0, pending_signups:busyHome ? 2 : 0, pilot_offices:offices.length}, month:'2026-10', office_totals:offices.map((office, i) => ({office_id:office.id, office_name:office.name, office_code:office.code, in_office:busyHome && i === 0 ? 3 : 0, overdue:busyHome && i === 0 ? 1 : 0, docs_processed:busyHome ? 12 - i : 0}))}
  else if (endpoint === 'admin-offices.php') data = {offices:emptyReview ? [] : adminOffices}
  else if (endpoint === 'admin-thresholds-update.php') {
    const office = adminOffices.find(row => row.office_id === Number(body.office_id))
    if (reviewRole !== 'admin' || !office || !String(body.document_type || '').trim() || body.max_hours < 1 || body.max_hours > 720 || body.out_unconfirmed_hours < 1 || body.out_unconfirmed_hours > 168) return new Response(JSON.stringify({success:false,message:'Sample alert limits are incomplete or unavailable.'}), {status:400})
    const threshold = {document_type:body.document_type, max_hours:Number(body.max_hours), out_unconfirmed_hours:Number(body.out_unconfirmed_hours)}
    const previous = office.thresholds.findIndex(row => row.document_type === threshold.document_type)
    if (previous === -1) office.thresholds.push(threshold)
    else office.thresholds[previous] = threshold
    data = {threshold:{...threshold, office_id:office.office_id}, message:'Sample alert time limits saved in memory.'}
  }
  else if (endpoint === 'users-list.php') data = {users:emptyReview ? [] : users}
  else if (endpoint === 'signup-pending-list.php') data = {pending:emptyReview ? [] : pendingSignups}
  else if (endpoint === 'system-status.php') data = {checked_at:'2026-10-14 16:00:00', checked_at_display:'Oct 14, 2026 4:00 PM',
    status:{api:'Online', database:'Connected', documents:emptyReview ? 0 : 48, php_version:'8.2.12', mysql_version:'10.4.32-MariaDB', health:emptyReview ? 'healthy' : 'attention'},
    role_counts:{staff:emptyReview ? 0 : 10, head:emptyReview ? 0 : 5, admin:emptyReview ? 0 : 1}, users:{active:emptyReview ? 0 : 16, inactive:emptyReview ? 0 : 1, total:emptyReview ? 0 : 17},
    operations:{active_documents:emptyReview ? 0 : 12, overdue_in_office:emptyReview ? 0 : 2, unconfirmed_out:emptyReview ? 0 : 1, flagged_total:emptyReview ? 0 : 3, movements_today:emptyReview ? 0 : 24, movements_this_month:emptyReview ? 0 : 96, pending_signups:emptyReview ? 0 : 2, month:'2026-10'},
    office_snapshot:adminOffices.map((office, index) => ({...office, in_office:emptyReview ? 0 : index + 1}))}
  else if (endpoint === 'head-analytics.php') data = {office_id:reviewOffice.id, month:parsed.searchParams.get('month') || '2026-10',
    stats:emptyReview ? {processed:0, late_count:0, on_time_count:0, unforwarded_count:0, delayed_count:0, on_time_percent:0, unforwarded_percent:0, delayed_percent:0}
      : {processed:20, late_count:3, on_time_count:15, unforwarded_count:2, delayed_count:3, on_time_percent:75, unforwarded_percent:10, delayed_percent:15},
    slow_documents:emptyReview ? [] : documents.slice(0, 3).map((doc, index) => ({document_id:doc.id, hours:72 - index * 6}))}
  else if (endpoint === 'audit-scans.php') {
    const outcome = parsed.searchParams.get('outcome') || 'all'
    const events = emptyReview ? [] : scanEvents.filter((event) => outcome === 'all' || event.outcome === outcome)
    if (parsed.searchParams.get('format') === 'csv') return new Response('When,Document,Outcome\n' + events.map((event) => `${event.created_at},${event.document_id},${event.outcome}`).join('\n'), {headers:{'Content-Type':'text/csv;charset=utf-8'}})
    data = {events}
  }
  else if (endpoint === 'audit-activity.php') data = {events:emptyReview ? [] : activityEvents}
  else if (endpoint === 'reports-summary.php') {
    if (parsed.searchParams.get('format') === 'csv') return new Response(reportCsv, {headers:{'Content-Type':'text/csv;charset=utf-8'}})
    if (parsed.searchParams.get('format') === 'print') return new Response(reportPrint, {headers:{'Content-Type':'text/html;charset=utf-8'}})
    data = emptyReview ? {...report, as_of:report.generated_at, outstanding_transfers:0, carried_forward_transfers:0, totals:{documents_in_period:0}, office_totals:[], compliance:{on_time:{count:0,percent:0},unforwarded:{count:0,percent:0},delayed:{count:0,percent:0}}} : {...report, as_of:report.generated_at, period_end:report.generated_at, outstanding_transfers:8, carried_forward_transfers:2}
  }
  else if (endpoint === 'reports-register.php') {
    const scope = parsed.searchParams.get('scope') || 'activity'
    const classification = parsed.searchParams.get('classification') || 'all'
    const officeId = parsed.searchParams.get('office_id') || ''
    const search = (parsed.searchParams.get('q') || '').toLowerCase()
    const page = Math.max(1, Number(parsed.searchParams.get('page')) || 1)
    const pageSize = Number(parsed.searchParams.get('page_size')) || 25
    const rows = emptyReview ? [] : reportRows.filter(row => (scope === 'outstanding' ? row.current_status === 'OUT' : !row.carried_forward) && (classification === 'all' || row.classification === classification) && (!officeId || String(row.current_office_id) === officeId) && [row.document_id,row.title,row.type].join(' ').toLowerCase().includes(search))
    data = {scope, classification, page, page_size:pageSize, total:rows.length, total_pages:Math.max(1,Math.ceil(rows.length / pageSize)), documents:rows.slice((page-1)*pageSize,page*pageSize), as_of:parsed.searchParams.get('as_of') || report.generated_at, timezone:'Asia/Manila'}
  }
  else if (endpoint === 'audit-exceptions.php') data = {exceptions:emptyReview ? [] : exceptions}
  else if (endpoint === 'auth-session.php') {
    const storedUser = JSON.parse(fixtureStorage.get('sf_user') || 'null')
    if (!storedUser) return new Response(JSON.stringify({success:false,message:'Sample session ended'}), {status:401})
    data = {user:storedUser}
  }
  else return new Response(JSON.stringify({success:false, message:'Sample preview: this action is disabled.'}), {status:400})
  if (sessionReview && options.method === 'POST') { sampleWriteCount++; window.dispatchEvent(new CustomEvent('sf-fixture-write')) }
  if (body.operation_id && ['documents-create.php','document-requests-create.php'].includes(endpoint)) creationResults.set(body.operation_id, {kind:endpoint==='documents-create.php'?'document':'request',result:{success:true,...data}})
  return new Response(JSON.stringify({success:true, ...data}), {headers:{'Content-Type':'application/json'}})
}
function ReviewHistoryControls() {
  const navigate = useNavigate()
  return <><button type="button" style={{marginLeft:12}} onClick={()=>navigate(-1)}>Sample Back</button><button type="button" style={{marginLeft:8}} onClick={()=>navigate(1)}>Sample Forward</button></>
}

function SampleSessionControls() {
  const { user, sessionMessage } = useAuth()
  const [writes, setWrites] = useState(sampleWriteCount)
  React.useEffect(() => {
    const changed = () => setWrites(sampleWriteCount)
    window.addEventListener('sf-fixture-write', changed)
    return () => window.removeEventListener('sf-fixture-write', changed)
  }, [])
  return <div style={{padding:'10px 16px',background:'#fff8df'}}>
    <strong>Sample identity: {user?.name || 'Signed out / verifying'}</strong> · Sample writes: {writes}
    <button type="button" style={{marginLeft:12}} onClick={() => changeSampleSession(0)}>Use sample account A in both tabs</button>
    <button type="button" style={{marginLeft:12}} onClick={() => changeSampleSession(1)}>Use sample account B in both tabs</button>
    <button type="button" style={{marginLeft:12}} onClick={() => changeSampleSession(-1)}>Sign out sample tabs</button>
    {sessionMessage ? <p role="status">{sessionMessage}</p> : null}
  </div>
}

export default function Review() {
  const { user } = useAuth()
  const [connectionLost, setConnectionLost] = useState(false)
  function toggleConnection() { offline = !offline; setConnectionLost(offline); reportConnection(offline, !offline); window.dispatchEvent(new CustomEvent('sf-refresh-requested')) }
  return <MemoryRouter initialEntries={[initialEntry]}>
    {sessionReview ? <SampleSessionControls /> : null}
    {(!homeReview || reviewParams.get('state') === 'refresh-review') && reviewParams.get('chrome') !== '0' ? <div style={{padding:'10px 16px', background:'#fff8df', color:'#5c4a32', fontSize:14}}>UI review · Synthetic {reviewRole} session · Sample data · No backend writes <Link style={{marginLeft:16}} to={reviewHome}>Home</Link><Link style={{marginLeft:16}} to="/documents">Documents</Link><Link style={{marginLeft:16}} to="/requests">Requests</Link><Link style={{marginLeft:16}} to="/register">Registration</Link><Link style={{marginLeft:16}} to="/register?request_id=105">Register for accepted request</Link><Link style={{marginLeft:16}} to="/admin/reports">Reports</Link><button type="button" style={{marginLeft:16}} onClick={toggleConnection}>{connectionLost ? 'Restore sample connection' : 'Simulate connection loss'}</button><ReviewHistoryControls /></div> : null}
    {user ? <Routes><Route element={<Layout />}>{Object.entries(reviewPages).map(([path, Page]) => <Route key={path} path={path} element={<Page />} />)}</Route></Routes> : <p>Sign in to the local SmartFlow app, then reopen this preview.</p>}
  </MemoryRouter>
}
const root = import.meta.hot?.data.root || createRoot(document.getElementById('root'))
if (import.meta.hot) import.meta.hot.data.root = root
root.render(<AuthProvider><Review /></AuthProvider>)
