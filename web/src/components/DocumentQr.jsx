import { useMemo, useState } from 'react'

export default function DocumentQr({ id, payload, showId = true }) {
  const [error, setError] = useState('')
  const svg = useMemo(() => globalThis.SmartflowQrLabel.createQrSvg(payload, 600), [payload])
  function download() {
    setError('')
    const image = new Image()
    const source = URL.createObjectURL(new Blob([svg], { type: 'image/svg+xml' }))
    image.onerror = () => { URL.revokeObjectURL(source); setError('Could not save QR image. Try again.') }
    image.onload = () => {
      const canvas = document.createElement('canvas')
      canvas.width = canvas.height = 600
      canvas.getContext('2d').drawImage(image, 0, 0)
      URL.revokeObjectURL(source)
      canvas.toBlob((blob) => {
      if (!blob) return
      const url = URL.createObjectURL(blob)
      const link = document.createElement('a')
      link.download = `${id}-QR.png`
      link.href = url
      document.body.appendChild(link)
      link.click()
      link.remove()
      setTimeout(() => URL.revokeObjectURL(url), 1000)
      }, 'image/png')
    }
    image.src = source
  }
  return (
    <div className="document-qr">
      <div className="flow-qr" role="img" aria-label="SmartFlow secured tracking QR" dangerouslySetInnerHTML={{ __html: svg }} />
      {showId ? <p><strong>{id}</strong></p> : null}
      <p className="muted">The QR stays linked to this document. Printing is optional.</p>
      <button className="btn-secondary" type="button" onClick={download}>Download QR image</button>
      {error ? <p className="error" role="alert">{error}</p> : null}
    </div>
  )
}
