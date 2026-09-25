/**
 * Shared SmartFlow icons — mirror mobile/flutter/lib/theme/sf_icons.dart
 * Same glyph for every role (staff / head / admin) on shared destinations.
 */

export function SfIcon({ name, size = 20, stroke = 2, className }) {
  const paths = SF_ICON_PATHS[name]
  if (!paths) return null
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      width={size}
      height={size}
      fill="none"
      stroke="currentColor"
      strokeWidth={stroke}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
    >
      {paths.map((d, i) => (typeof d === 'string' ? <path key={i} d={d} /> : d))}
    </svg>
  )
}

/** Stroke-path icons (Material-aligned). */
export const SF_ICON_PATHS = {
  // Nav — same for all roles
  home: [
    'M4 10.5 12 4l8 6.5V20a1 1 0 0 1-1 1h-5v-6H10v6H5a1 1 0 0 1-1-1z',
  ],
  /** qr_code_scanner */
  scan: [
    'M4 7V5a2 2 0 0 1 2-2h2',
    'M20 7V5a2 2 0 0 0-2-2h-2',
    'M4 17v2a2 2 0 0 0 2 2h2',
    'M20 17v2a2 2 0 0 1-2 2h-2',
    'M7 8h4v4H7z',
    'M13 8h4',
    'M13 12h4',
    'M7 14h10',
  ],
  /** edit_note / register */
  register: [
    'M12 20h9',
    'M16.5 3.5a2.12 2.12 0 0 1 3 3L7 19l-4 1 1-4Z',
  ],
  /** document requests — swap_horiz (mobile header) */
  requests: [
    'M8 7h12',
    'M16 3l4 4-4 4',
    'M16 17H4',
    'M8 21l-4-4 4-4',
  ],
  /** view_list / history */
  history: [
    'M8 6h13',
    'M8 12h13',
    'M8 18h13',
    'M3 6h.01',
    'M3 12h.01',
    'M3 18h.01',
  ],
  /** notifications */
  alerts: [
    'M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9',
    'M10 19a2 2 0 0 0 4 0',
  ],
  /** person / profile */
  profile: [
    'M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2',
    'M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8Z',
  ],
  /** groups / users (admin) */
  users: [
    'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2',
    'M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8Z',
    'M22 21v-2a4 4 0 0 0-3-3.87',
    'M16 3.13a4 4 0 0 1 0 7.75',
  ],
  /** business / offices */
  offices: [
    'M3 21h18',
    'M5 21V7l7-4 7 4v14',
    'M9 21v-6h6v6',
    'M9 10h.01',
    'M15 10h.01',
    'M9 14h.01',
    'M15 14h.01',
  ],
  /** tune / thresholds */
  thresholds: [
    'M4 21v-7',
    'M4 10V3',
    'M12 21v-9',
    'M12 8V3',
    'M20 21v-5',
    'M20 12V3',
    'M1 14h6',
    'M9 8h6',
    'M17 16h6',
  ],
  /** cloud / system */
  system: [
    'M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z',
  ],
  /** assessment / COA */
  coa: [
    'M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z',
    'M14 2v6h6',
    'M16 13H8',
    'M16 17H8',
    'M10 9H8',
  ],
  /** QR monitor */
  qrMonitor: [
    'M3 7V5a2 2 0 0 1 2-2h2',
    'M21 7V5a2 2 0 0 0-2-2h-2',
    'M3 17v2a2 2 0 0 0 2 2h2',
    'M21 17v2a2 2 0 0 1-2 2h-2',
    'M7 12h10',
  ],
  // Get Started trust strip (mobile _AuthTrustStrip)
  /** qr_code_2 */
  qrHandoffs: [
    'M7 3H4a1 1 0 0 0-1 1v3',
    'M17 3h3a1 1 0 0 1 1 1v3',
    'M7 21H4a1 1 0 0 1-1-1v-3',
    'M17 21h3a1 1 0 0 0 1-1v-3',
    'M7 7h3v3H7z',
    'M14 7h3v3h-3z',
    'M7 14h3v3H7z',
    'M14 14h1v1h-1z',
    'M16 14h1v1h-1z',
    'M14 16h1v1h-1z',
    'M16 16h1v1h-1z',
  ],
  /** history_edu — custody log */
  custodyLog: [
    'M4 19.5A2.5 2.5 0 0 1 6.5 17H20',
    'M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z',
    'M8 7h8',
    'M8 11h8',
    'M8 15h5',
  ],
  /** verified — COA support */
  coaSupport: [
    'M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z',
    'M9 12l2 2 4-4',
  ],
  back: ['M15 18l-6-6 6-6'],
  logout: [
    'M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4',
    'M16 17l5-5-5-5',
    'M21 12H9',
  ],
  lock: [
    'M7 11V7a5 5 0 0 1 10 0v4',
    'M5 11h14v10H5z',
  ],
}
