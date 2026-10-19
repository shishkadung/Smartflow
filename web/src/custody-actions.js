// A cancelled or incomplete physical check never reaches the movement API.
export async function recordConfirmedReceipt(document, requestReceipt, recordMovement, body) {
  const contents = await requestReceipt(document)
  if (contents?.confirmed !== true) return null
  return recordMovement({ ...body, receipt_confirmed: true, contents_receipt: contents })
}

export async function recordConfirmedFiling(document, requestFiling, fileDocument) {
  const reviewed = { ...document }
  if (!Number.isSafeInteger(Number(reviewed.last_movement_id)) || Number(reviewed.last_movement_id) <= 0) throw new Error('Current movement unavailable. Refresh and review this folder before filing.')
  if (await requestFiling(reviewed) !== true) return null
  return fileDocument(reviewed.id, reviewed.last_movement_id)
}

// A failed follow-up read cannot change a confirmed save into a failed write.
export async function saveCustodyAndRefresh(save, read, onSaved, onReadError) {
  const result = await save()
  if (!result) return null
  onSaved(result)
  try { return (await read()).document }
  catch (error) { onReadError(error); return null }
}

export function requestReturnPath(value) {
  return typeof value === 'string' && /^\/requests(?:\?[^#]*)?$/.test(value) ? value : null
}

export function preferredForwardDestination(document, offices) {
  if (document?.can_return_to_accounting) return String(offices.find(office => office.code === 'ACC')?.id || document.suggested_forward?.office_id || '')
  return String(document?.suggested_forward?.office_id || '')
}

export function handoffDestinations(document, offices, user, isReturn) {
  const previous = (document.visited_office_codes || []).map(code => String(code).toUpperCase())
  return offices.filter(office => Number(office.id) !== Number(user.office_id)
    && (document.can_return_to_accounting ? office.code === 'ACC' : !isReturn || previous.includes(String(office.code).toUpperCase())))
}
