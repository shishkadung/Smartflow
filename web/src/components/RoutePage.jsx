import { Component, Suspense } from 'react'
import { useLocation } from 'react-router-dom'
import { LifeSkeleton } from './ui.jsx'

class PageLoadBoundary extends Component {
  state = { failed: false }

  static getDerivedStateFromError() { return { failed: true } }

  render() {
    if (this.state.failed) return (
      <div className="card" role="alert">
        <h2>Could not load this page</h2>
        <p>Check your connection, then reload to try again.</p>
        <button className="btn" onClick={() => window.location.reload()}>Reload page</button>
      </div>
    )
    return this.props.children
  }
}

export default function RoutePage({ page: Page }) {
  const { pathname } = useLocation()
  return (
    <PageLoadBoundary key={pathname}>
      <Suspense fallback={<LifeSkeleton label="Loading page" />}>
        <Page />
      </Suspense>
    </PageLoadBoundary>
  )
}
