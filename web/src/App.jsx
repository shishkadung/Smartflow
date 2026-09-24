import { Navigate, Route, Routes } from 'react-router-dom'
import { useAuth } from './auth.jsx'
import Layout from './components/Layout.jsx'
import AdminHomePage from './pages/AdminHomePage.jsx'
import AdminQrMonitorPage from './pages/AdminQrMonitorPage.jsx'
import AdminReportsPage from './pages/AdminReportsPage.jsx'
import AdminUsersPage from './pages/AdminUsersPage.jsx'
import AlertsPage from './pages/AlertsPage.jsx'
import ForgotPasswordPage from './pages/ForgotPasswordPage.jsx'
import GetStartedPage from './pages/GetStartedPage.jsx'
import HeadHomePage from './pages/HeadHomePage.jsx'
import HistoryPage from './pages/HistoryPage.jsx'
import LoginPage from './pages/LoginPage.jsx'
import ProfilePage from './pages/ProfilePage.jsx'
import RegisterPage from './pages/RegisterPage.jsx'
import RequestsPage from './pages/RequestsPage.jsx'
import ResetPasswordPage from './pages/ResetPasswordPage.jsx'
import ScanPage from './pages/ScanPage.jsx'
import SignupPage, { SignupPendingPage } from './pages/SignupPage.jsx'
import StaffHomePage from './pages/StaffHomePage.jsx'

function RequireAuth({ children }) {
  const { isAuthenticated } = useAuth()
  if (!isAuthenticated) return <Navigate to="/" replace />
  return children
}

function RequireAdmin({ children }) {
  const { user } = useAuth()
  if (user?.role !== 'admin') return <Navigate to="/home" replace />
  return children
}

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<LoginPage />} />
      <Route path="/login" element={<LoginPage />} />
      <Route path="/get-started" element={<GetStartedPage />} />
      <Route path="/signup" element={<SignupPage />} />
      <Route path="/signup/pending" element={<SignupPendingPage />} />
      <Route path="/forgot-password" element={<ForgotPasswordPage />} />
      <Route path="/reset-password" element={<ResetPasswordPage />} />
      <Route
        element={
          <RequireAuth>
            <Layout />
          </RequireAuth>
        }
      >
        <Route path="/home" element={<StaffHomePage />} />
        <Route path="/head" element={<HeadHomePage />} />
        <Route path="/admin" element={<AdminHomePage />} />
        <Route path="/scan" element={<ScanPage />} />
        <Route path="/register" element={<RegisterPage />} />
        <Route path="/requests" element={<RequestsPage />} />
        <Route path="/history" element={<HistoryPage />} />
        <Route path="/alerts" element={<AlertsPage />} />
        <Route path="/profile" element={<ProfilePage />} />
        <Route
          path="/admin/users"
          element={
            <RequireAdmin>
              <AdminUsersPage />
            </RequireAdmin>
          }
        />
        <Route
          path="/admin/reports"
          element={
            <RequireAdmin>
              <AdminReportsPage />
            </RequireAdmin>
          }
        />
        <Route
          path="/admin/qr-monitor"
          element={
            <RequireAdmin>
              <AdminQrMonitorPage />
            </RequireAdmin>
          }
        />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}
