// Smooth scrolling is skipped for people who ask their system to reduce motion.
export function scrollBehavior() {
  const reduced = typeof window !== 'undefined' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches
  return reduced ? 'auto' : 'smooth'
}
