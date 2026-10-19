import { smartflow } from './api.js'

export async function loadDocumentDetail(id, municipal, source = smartflow) {
  try { return await source.officeDocuments(id, municipal ? { scope: 'municipal' } : {}) }
  catch (error) {
    if (municipal || error.status !== 404) throw error
    // Existing authenticated tracking access stays read-only outside this office's tray.
    const [shown, activity] = await Promise.all([source.documentShow(id), source.documentMovements(id)])
    return { read_only: true, document: { ...shown.document, tray: shown.document.trail_complete ? 'completed' : 'elsewhere', can_file: false, can_correct_destination: false, journey: activity.movements || [] } }
  }
}
