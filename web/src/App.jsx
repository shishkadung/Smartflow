import { lazy, useEffect } from 'react'
import { Navigate, Route, Routes, useLocation } from 'react-router-dom'
import { useAuth } from './auth.jsx'
import { pageTitle } from './page-title.js'
import { homePath } from './tracking.js'
import ForcedPasswordChange from './components/ForcedPasswordChange.jsx'
import Layout from './components/Layout.jsx'
import RoutePage from './components/RoutePage.jsx'
import LoginPage from './pages/LoginPage.jsx'

const AdminHomePage = lazy(() => import('./pages/AdminHomePage.jsx'))
const AdminOfficesPage = lazy(() => import('./pages/AdminOfficesPage.jsx'))
const AdminQrMonitorPage = lazy(() => import('./pages/AdminQrMonitorPage.jsx'))
const AdminReportsPage = lazy(() => import('./pages/AdminReportsPage.jsx'))
const AdminSystemPage = lazy(() => import('./pages/AdminSystemPage.jsx'))
const AdminThresholdsPage = lazy(() => import('./pages/AdminThresholdsPage.jsx'))
const AdminUsersPage = lazy(() => import('./pages/AdminUsersPage.jsx'))
const AlertsPage = lazy(() => import('./pages/AlertsPage.jsx'))
const ForgotPasswordPage = lazy(() => import('./pages/ForgotPasswordPage.jsx'))
const GetStartedPage = lazy(() => import('./pages/GetStartedPage.jsx'))
const HeadAnalyticsPage = lazy(() => import('./pages/HeadAnalyticsPage.jsx'))
const HeadHomePage = lazy(() => import('./pages/HeadHomePage.jsx'))
const HistoryPage = lazy(() => import('./pages/HistoryPage.jsx'))
const ProfilePage = lazy(() => import('./pages/ProfilePage.jsx'))
const RegisterPage = lazy(() => import('./pages/RegisterPage.jsx'))
const RequestsPage = lazy(() => import('./pages/RequestsPage.jsx'))
const ResetPasswordPage = lazy(() => import('./pages/ResetPasswordPage.jsx'))
const ScanPage = lazy(() => import('./pages/ScanPage.jsx'))
const DocumentsPage = lazy(() => import('./pages/DocumentsPage.jsx'))
const SignupPage = lazy(() => import('./pages/SignupPage.jsx'))
const SignupPendingPage = lazy(() => import('./pages/SignupPage.jsx').then(module => ({ default: module.SignupPendingPage })))
const SignupApprovedPage = lazy(() => import('./pages/SignupPage.jsx').then(module => ({ default: module.SignupApprovedPage })))
const StaffHomePage = lazy(() => import('./pages/StaffHomePage.jsx'))

function RequireAuth({ children }) {
  const { isAuthenticated, user } = useAuth()
  const location = useLocation()
  if (!isAuthenticated) return <Navigate to="/" replace state={location.pathname === '/documents' ? { from: `/documents${location.search}` } : undefined} />
  // A temporary password from an administrator must be replaced before any page is usable.
  if (user?.must_change_password) return <ForcedPasswordChange />
  return children
}

// Client routes only keep people on their own pages; the API remains the authorization boundary.
function RequireAdmin({ children }) {
  const { user } = useAuth()
  if (user?.role !== 'admin') return <Navigate to={homePath(user?.role)} replace />
  return children
}

function RequireHead({ children }) {
  const { user } = useAuth()
  if (user?.role !== 'head') return <Navigate to={homePath(user?.role)} replace />
  return children
}

function RequireStaffHome({ children }) {
  const { user } = useAuth()
  if (user?.role === 'head' || user?.role === 'admin') return <Navigate to={homePath(user.role)} replace />
  return children
}

// Admin navigation omits Scan on every layout, so a typed /scan URL returns to the Dashboard instead of opening a hidden page.
function RequireScanAccess({ children }) {
  const { user } = useAuth()
  if (user?.role === 'admin') return <Navigate to={homePath(user.role)} replace />
  return children
}

function RequireStaff({ children }) {
  const { user } = useAuth()
  if (user?.role !== 'staff') return <Navigate to={homePath(user?.role)} replace />
  return children
}

function PageTitle() {
  const { pathname } = useLocation()
  useEffect(() => { document.title = pageTitle(pathname) }, [pathname])
  return null
}

export default function App() {
  return (
    <>
    <PageTitle />
    <Routes>
      <Route path="/" element={<LoginPage />} />
      <Route path="/login" element={<LoginPage />} />
      <Route path="/get-started" element={<RoutePage page={GetStartedPage} />} />
      <Route path="/signup" element={<RoutePage page={SignupPage} />} />
      <Route path="/signup/pending" element={<RoutePage page={SignupPendingPage} />} />
      <Route path="/signup/approved" element={<RoutePage page={SignupApprovedPage} />} />
      <Route path="/forgot-password" element={<RoutePage page={ForgotPasswordPage} />} />
      <Route path="/reset-password" element={<RoutePage page={ResetPasswordPage} />} />
      <Route
        element={
          <RequireAuth>
            <Layout />
          </RequireAuth>
        }
      >
        <Route path="/home" element={<RequireStaffHome><RoutePage page={StaffHomePage} /></RequireStaffHome>} />
        <Route path="/head" element={<RequireHead><RoutePage page={HeadHomePage} /></RequireHead>} />
        <Route
          path="/head/analytics"
          element={
            <RequireHead>
              <RoutePage page={HeadAnalyticsPage} />
            </RequireHead>
          }
        />
        <Route path="/admin" element={<RequireAdmin><RoutePage page={AdminHomePage} /></RequireAdmin>} />
        <Route path="/scan" element={<RequireScanAccess><RoutePage page={ScanPage} /></RequireScanAccess>} />
        <Route path="/documents" element={<RoutePage page={DocumentsPage} />} />
        <Route path="/register" element={<RequireStaff><RoutePage page={RegisterPage} /></RequireStaff>} />
        <Route path="/requests" element={<RoutePage page={RequestsPage} />} />
        <Route path="/history" element={<RoutePage page={HistoryPage} />} />
        <Route path="/alerts" element={<RoutePage page={AlertsPage} />} />
        <Route path="/profile" element={<RoutePage page={ProfilePage} />} />
        <Route
          path="/admin/users"
          element={
            <RequireAdmin>
              <RoutePage page={AdminUsersPage} />
            </RequireAdmin>
          }
        />
        <Route
          path="/admin/offices"
          element={
            <RequireAdmin>
              <RoutePage page={AdminOfficesPage} />
            </RequireAdmin>
          }
        />
        <Route
          path="/admin/thresholds"
          element={
            <RequireAdmin>
              <RoutePage page={AdminThresholdsPage} />
            </RequireAdmin>
          }
        />
        <Route
          path="/admin/reports"
          element={
            <RequireAdmin>
              <RoutePage page={AdminReportsPage} />
            </RequireAdmin>
          }
        />
        <Route
          path="/admin/qr-monitor"
          element={
            <RequireAdmin>
              <RoutePage page={AdminQrMonitorPage} />
            </RequireAdmin>
          }
        />
        <Route
          path="/admin/system"
          element={
            <RequireAdmin>
              <RoutePage page={AdminSystemPage} />
            </RequireAdmin>
          }
        />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
    </>
  )
}
