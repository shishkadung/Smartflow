import { useMemo, useState } from 'react'
import { useAuth } from '../auth.jsx'
import { emptyInventory, FolderInventoryEditor } from '../components/FolderContents.jsx'
import FolderChecklists from '../components/FolderChecklists.jsx'
import { Overview } from '../components/ui.jsx'
import { documentTypesForOffice } from '../tracking.js'

/** Own-office definitions only. Publishing does not register a physical folder. */
export default function OfficeChecklistsPage() {
  const { user } = useAuth()
  const types = useMemo(() => documentTypesForOffice(user.office_code), [user.office_code])
  const [chosen, setChosen] = useState('')
  const [inventory, setInventory] = useState(emptyInventory)
  const type = types.includes(chosen) ? chosen : types[0] || ''

  if (user.role !== 'head' && user.role !== 'admin') {
    return <div className="sf-life checklists-page"><Overview title="Office checklists" /><div className="card sf-life__panel"><p>Office heads and administrators manage checklists.</p></div></div>
  }

  return (
    <div className="sf-life checklists-page">
      <Overview title="Office checklists" />
      <section className="card sf-life__panel checklists-page__panel" aria-label="Office checklists">
        <p className="checklists-page__office">Applies to {user.office_name}</p>
        <div className="field">
          <label htmlFor="checklist-document-type">Document type</label>
          <select id="checklist-document-type" value={type} onChange={(e) => setChosen(e.target.value)}>
            {types.map((item) => <option key={item} value={item}>{item}</option>)}
          </select>
        </div>
        <FolderChecklists type={type} inventory={inventory} onApply={setInventory} management />
        <FolderInventoryEditor value={inventory} onChange={setInventory} checklistOnly />
      </section>
    </div>
  )
}
