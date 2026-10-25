# SmartFlow docs

Start here. Do not browse every file — pick **one folder** for the job you are doing.

## SmartFlow context bundle

Prepared **15 October 2026** from the current source, client evidence and the user's review. These eight documents provide working context for both web and mobile. They distinguish implemented behavior, accepted requirements, proposed changes and open discrepancies; the documentation bundle does not implement the proposed UI redesign.

| Document | Use |
|---|---|
| [PRD.md](PRD.md) | Product scope, users, workflows, requirements and acceptance criteria |
| [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) | Current visual foundation, accepted preferences and proposed web/mobile direction |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Clients, PHP API, system structure and runtime/data flow |
| [DATABASE.md](DATABASE.md) | Runtime schema, relationships, constraints and custody transactions |
| [SECURITY.md](SECURITY.md) | Implemented protections, permission boundaries and unresolved gaps |
| [CODE_STYLE.md](CODE_STYLE.md) | Existing conventions and scoped implementation guidance |
| [TESTING.md](TESTING.md) | Safe commands, verification matrix and dated evidence |
| [../AGENTS.md](../AGENTS.md) | Workspace-wide guide and reading route for coding agents |

Start with PRD, then the relevant topic and linked source. `AGENTS.md` is at the workspace root so repository agents can discover it. Older thesis/demo/handover files remain available below and may describe earlier paths or behavior.

| I need to… | Open |
|---|---|
| Demo / defense tomorrow | [`defense/START-HERE.md`](defense/START-HERE.md) |
| Write or paste the thesis | [`thesis/`](thesis/) |
| Deploy the system | [`product/PRODUCTION-DEPLOYMENT.md`](product/PRODUCTION-DEPLOYMENT.md) |
| Give to the client (user manual) | [`client-handover/`](client-handover/) |
| Understand request vs scan | [`product/SIMPLE-FLOW.md`](product/SIMPLE-FLOW.md) |
| Client interview answers | [`client/CLIENT-DISCOVERY-RESPONSES-SUMMARY.md`](client/CLIENT-DISCOVERY-RESPONSES-SUMMARY.md) |
| Figma / QR / use-case pictures | [`design/`](design/) |
| Paper PDF / Word files | [`thesis/files/`](thesis/files/) |
| Old copies | [`../_archive/`](../_archive/) |

---

## Folders

```
docs/
  defense/   panel demo, scripts, revision matrix
  thesis/    proposal, manuscript, chapters, SRS, timeline
  product/   how the app works + production deploy
  client/    Municipal Accountant discovery notes
  design/    PDF, diagrams, use-case HTML
```

Old copies live in `_archive/` at the project root — do not use for demo or Word.

---

## Defense (read in this order)

1. [`defense/START-HERE.md`](defense/START-HERE.md) — 3 rules + DV table  
2. [`defense/DEMO-SCENARIOS-COMPLETE.md`](defense/DEMO-SCENARIOS-COMPLETE.md) — full scenarios  
3. [`defense/PRE-DEFENSE-BUKAS.md`](defense/PRE-DEFENSE-BUKAS.md) — night-before checklist  

Skip the rest unless the panel asks.

---

## Thesis (read in this order)

1. [`thesis/proposal.md`](thesis/proposal.md) — approved title proposal  
2. [`thesis/chapter-1/`](thesis/chapter-1/) — Chapter I  
3. [`thesis/chapter-2/`](thesis/chapter-2/) — Chapter II (open that folder’s README)  
4. [`thesis/SmartFlow_Capstone1.md`](thesis/SmartFlow_Capstone1.md) — compiled manuscript  

Chapter III is still a placeholder: [`thesis/chapter-03-system-design.md`](thesis/chapter-03-system-design.md).

---

## Product

| File | Use when |
|---|---|
| [`product/SIMPLE-FLOW.md`](product/SIMPLE-FLOW.md) | Request vs Register vs Scan |
| [`product/DOCUMENT-REQUESTS-LOGIC.md`](product/DOCUMENT-REQUESTS-LOGIC.md) | Request status rules |
| [`product/POLISH-CHECKLIST.md`](product/POLISH-CHECKLIST.md) | UI copy / smoke test |
| [`product/PRODUCTION-DEPLOYMENT.md`](product/PRODUCTION-DEPLOYMENT.md) | Server, HTTPS, APK |
| [`product/QR-Audit-Summary.md`](product/QR-Audit-Summary.md) | QR audit notes |
