# SmartFlow: script para sa sabay-sabay na demo sa anim na offices

Prepared: 22 October 2026. Audience: Engineering, Human Resources, Budget, Accounting, Treasury, at Mayor's Office. Target: humigit-kumulang 12–15 minuto, depende sa pag-click at tanungan.

Ang nasa blockquote ang pwede mong sabihin. Ang nasa italics ay cues mo at hindi kailangang basahin. Palitan ang mga nasa [brackets]. Gamitin ang "ako/ko" o "kami/namin" ayon sa kung sino ang kasama mong magpresent.

**Nakahandang records:** May [sample-data guide na may actual tracking/request IDs](DEMO-DATA-2026-10-22.md). Ang main handoff example ay `DOC-2026-000009` — DEMO - Covered court materials, na hawak ng Engineering sa initial prepared state. Nauna nang na-register ang folder na iyon; ipakita ang Register form separately o gumamit ng bagong synthetic unlabelled sample sa halip na i-register ulit ito.

## Bago ang demo — para sa presenter

- Ihanda ang Dashboard, isang sample folder, sending at receiving staff demo views, sample full history, linked request, alerts, at authorized report view. Isang handoff lang ang kailangang ipakita; gamitin ang nakahandang history para sa mas mahabang journey. Hindi kailangang mag-sign in nang paisa-isa sa lahat ng anim na offices.
- Gumamit ng synthetic sample data sa in-memory web UI review fixture para sa practice interactions. Ang ibang isolated demo setup ay kailangang hiwalay sa operational records. Kapag actual system ang nakabukas, walkthrough lang at gumamit ng nakahandang sample screenshots para sa practice writes. Huwag magsulat ng kunwaring handoff o payment release sa tunay na records.
- Ihanda ang malinaw na sample screenshots bilang backup. Palakihin ang text ayon sa projector; ibalik ang anumang pansamantalang zoom pagkatapos. Itago ang notifications at huwag ipakita ang credentials o personal details.
- Staff demo view ang para sa registration, OUT at IN. Hiwalay ang monitoring/report view. Ang script na ito ay presentation material; hindi nito pinapatunayang nasubukan na ang aktuwal na demo setup, na may school approval, o na may client acceptance.

## 1. Opening

*Ipakita ang Dashboard. Huminto sandali at saka magsimula.*

> Magandang [umaga/hapon] po sa inyong lahat. Ako po si [pangalan], at salamat po sa oras ng Engineering, HR, Budget, Accounting, Treasury, at Mayor's Office.
>
> Ngayon po, ipapakita ko ang SmartFlow—isang system para sa pag-track ng physical folders na ipinapasa sa pagitan ng mga office.
>
> Bago po natin tingnan ang mga functions, maikli ko munang ipapaliwanag ang layunin ng pag-aaral namin.

## 2. Purpose of the study

*Mga 30–45 segundo. Manatili sa Dashboard o sa opening slide kung mayroon. Ipaliwanag ang layunin; huwag sabihing napatunayan na ang resulta ng client evaluation.*

> Bilang bahagi po ng pag-aaral namin, layunin naming bumuo at suriin ang isang QR-based system para sa pag-track ng physical folders sa anim na office ng Municipality of Urbiztondo.
>
> Nais po naming makatulong sa mas malinaw na pag-monitor ng handoffs at delays, at sa pagkakaroon ng records kung sino ang nagpadala at tumanggap ng folder.
>
> Bahagi rin po ng pag-aaral ang pagkuha ng feedback mula sa intended users para masuri kung malinaw, madaling gamitin, at tugma ang system sa actual na trabaho nila.

*Transition papunta sa demo:*

> Para maipakita po iyon, gagamit tayo ng sample records sa basic flow: pag-register, pag-forward, pag-receive, at pagbalik sa history. Ipapakita rin natin ang Requests, Alerts, at Reports.
>
> Pagkatapos po, hihingi ako ng feedback kung tugma ang steps at information sa actual na trabaho ninyo.

## 3. Ano ang problemang tinutugunan?

*Manatili muna sa Dashboard; huwag magpalipat-lipat habang nagpapaliwanag.*

> Kapag may hinahanap na folder, karaniwan nating kailangang malaman: saang office ito huling naitala, sino ang nagpadala o tumanggap, at ano pa ang pending na action?
>
> Layunin ng SmartFlow na pagsamahin ang mga record na iyon para may malinaw na pagbabasehan sa pag-follow up.
>
> Yung physical folder pa rin po ang ipinapasa. Ang nire-record sa system ay ang custody at paggalaw nito. Ang ipinapakitang location ay batay sa pinakahuling recorded movement.

## 4. Sino ang gagamit?

> Depende po sa role ang makikita at magagawa ng account.
>
> Ang staff ng holding office ang magre-register at magre-record ng pagpapadala, pagtanggap, at filing kapag applicable. Ang department heads ay may monitoring at mga request o checklist actions na para sa kanilang role.
>
> Para sa municipal oversight, may monitoring ang Accounting administrator, kasama ang authorized custody-report exports.
>
> Sa demo natin, malinaw kong babanggitin kung sending staff, receiving staff, o monitoring view ang ipinapakita.

## 5. Register folder

*Buksan ang Register folder sa staff demo view. Gamitin ang synthetic sample na pisikal nang hawak ng registering office, halimbawa isang Engineering DV. Kung may existing tracking ID na ang sample, buksan ang existing record sa halip na mag-register ulit.*

> Simulan po natin sa isang sample folder na nasa Engineering na at wala pang tracking label.
>
> Dito ilalagay ang title, document type, required reference at logbook details, at ang contents inventory kung itatala ang laman. Iche-check muna ang information at actual page counts bago i-confirm.
>
> Kapag na-register, magkakaroon ito ng tracking ID at QR label. Recorded na rin ang initial IN sa office na may hawak nito.
>
> Yung tracking ID at QR na iyon ang gagamitin para hanapin ang parehong folder sa susunod nitong mga handoff.

*Ipakita ang ID, QR, at folder details. Mag-pause para makita nila.*

## 6. I-forward ang sample folder

*Sa holding staff demo view, buksan ang sample sa Documents o Scan. Para sa DV sample, gamitin ang Engineering → Budget. Isang prepared sample handoff lang ang ipakita.*

> Kapag ipapasa na ang folder, bubuksan muna ng staff ang record at iche-check kung tamang folder ang hawak niya.
>
> Pipiliin ang destination office—Budget sa halimbawa natin—at saka iko-confirm ang pagpapadala o OUT.
>
> Pagkatapos nito, makikita sa record na ipinadala na ito sa Budget at hinihintay pa ang receiving confirmation.

*Ipakita ang resulta. Ituro ang destination at transfer state.*

## 7. Tanggapin sa destination office

*Buksan ang nakahandang receiving staff demo view para sa Budget. Huwag mag-record ng IN gamit ang sending office o monitoring account.*

> Ngayon naman po, receiving office view ang ipinapakita natin.
>
> Kapag dumating ang physical folder, hahanapin ito gamit ang QR o tracking ID. Lalabas muna ang details para ma-check ng receiver.
>
> Ang scan o lookup ay pagbubukas ng record. Kailangan pa ring piliin at kumpirmahin ang Receive para maitala ang actual receipt.
>
> Dahil may recorded contents inventory ang sample natin, ilalagay dito ang aktuwal na natanggap na page counts. Kapag may kulang o ibang count, ilalagay ang discrepancy at dahilan bago i-confirm.
>
> Kapag nakumpirma na, may IN record na tayo sa Budget, kasama kung sino at kailan tumanggap.

*Ipakita ang saved result at updated custody. Sa simulated setup, malinaw na demo handoff ito.*

## 8. Balikan ang History at ipaliwanag ang office flow

*Buksan ang full folder history. Gamitin ang prepared sample history kung kailangan ng mas mahabang journey.*

> Dito po makikita ang recorded journey ng folder: registration, pagpapadala, pagtanggap, at mga note sa bawat handoff. Kapag may receiving discrepancy na naitala, mababalikan din iyon dito.
>
> Sa usual DV flow na ginagamit nating gabay, ang ruta ay Engineering, Budget, Accounting, Treasury, Mayor, at balik sa Treasury, na may applicable na optional return sa Accounting.
>
> Ang ipinakita nating DV ay isang halimbawa. Ang HR at ibang office ay may applicable na folder at request workflows din. Ang paggamit ng system ay naaayon sa document type, office, at role.
>
> Kung may actual na exception sa usual flow, makakatulong pong maitala natin ang specific example para ma-review kung tugma ang system.

## 9. Requests

*Buksan ang nakahandang sample request. Ipakita ang purpose, required-by date, status, at linked-folder action kung mayroon.*

> Para naman po sa formal request sa ibang office, dito ilalagay kung ano ang kailangan, para saan ito, at kailan kailangan.
>
> Makikita ng requester ang status sa My requests, at makikita ng handling office ang mga request na para rito sa Inbox.
>
> Kapag accepted na ang request, ibig sabihin ay tinanggap ng handler ang hinihinging trabaho. Hiwalay pa rin ang actual na pagpapadala at pagtanggap ng physical folder, kaya may sarili pa ring OUT at IN records.
>
> Kapag may linked folder, mabubuksan ang related record mula sa request, ayon sa access ng account.
>
> Para sa DV, hiwalay din ang payment-release recording ng Treasury pagkatapos ng actual payment release. Ang financial approvals at signatures ay nananatili sa regular na proseso ninyo.

*Kung wala sa demo ang release action, sapat nang ipaliwanag ito. Huwag mag-record ng sample payment release sa operational system.*

## 10. Alerts at monitoring

*Buksan ang prepared sample alerts. Hindi kailangang maghintay ng aktuwal na pagka-overdue habang nagde-demo.*

> Sa Alerts naman po, may magkakaibang dahilan kung bakit kailangan ng follow-up.
>
> Maaaring matagal na ang processing sa office, naipadala na ang folder pero wala pang receipt confirmation, o lumampas na ang nakatakdang deadline.
>
> May processing at receipt limits na naka-set ayon sa office at document type. Makakatulong ang malinaw na alert reason para malaman kung anong record at action ang kailangang tingnan.

## 11. Custody Reports

*Buksan ang authorized municipal report view. Ipakita ang selected period at isang kilalang sample entry. Accounting admin lang ang gamitin kung ipapakita ang export.*

> Dito naman po sa Custody Reports, makikita ang summary ng recorded custody activity para sa napiling period.
>
> Makakatulong ito sa pag-review ng galaw ng folders at sa paghahanda ng supporting custody records. Ang authorized Accounting admin ay maaari ring mag-export ng report.
>
> Ang counts at classifications dito ay dapat basahin ayon sa kanilang labels at selected period. Ang report na ito ay custody summary; ang financial statements at payment records ay nasa kani-kanilang official process.

## 12. Ano ang ambag ng SmartFlow?

*Bumalik sa sample folder o Dashboard.*

> Ang pangunahing ambag po ng SmartFlow ay ang pag-uugnay ng formal requests, confirmed sending at receiving records, contents-discrepancy evidence kapag may recorded inventory, at delay monitoring.
>
> Sa web at mobile, may iisang pinagbabasehang record ang authorized users para sa folder na hinahanap o pina-follow up nila.
>
> Ang gusto nating ma-check kasama ninyo ay kung malinaw ang steps at sapat ang information para sa actual na trabaho ng bawat office.

## 13. Feedback at questions

*Huminto sa pag-click. Maghanda ng notes at hayaang matapos ang sagot.*

> Bago po tayo magtapos, gusto ko pong marinig ang feedback ninyo.
>
> Una, tugma po ba ang ipinakitang pagpapadala at pagtanggap sa ginagawa ninyo?
>
> Pangalawa, sapat po ba ang details na nakikita ninyo para makahanap at makapag-follow up ng folder?
>
> Pangatlo, may step, field, o term po bang kailangang linawin para mas madaling gamitin sa inyong office?

*Kung mahaba ang discussion, unahin ang tanong sa actual workflow at isulat ang ibang item para mabalikan. Huwag mangakong implemented na ang bagong request.*

## 14. Closing

*Kung may feedback, basahin pabalik ang tunay na notes. Laktawan ang feedback sentence kung wala pang ibinigay.*

> Confirm ko lang po ang main notes natin: [maikling actual feedback]. Tama po ba ang pagkaintindi ko?
>
> Salamat po sa mga comments at suggestions. Ire-review namin ang mga ito laban sa actual workflow at agreed scope, at iko-coordinate ang anumang kailangang linawin o subukan pa.
>
> Maraming salamat po sa oras ng bawat office at sa pagtulong na masuri kung paano magagamit ang SmartFlow sa inyong trabaho.

## Mga linyang pwedeng balikan kapag kinakabahan

**Kapag na-blank:**

> Balikan lang po natin ang sample folder: ito ang huling recorded office, ito ang huling movement, at ito ang pending na action.

**Kapag may tanong habang nagde-demo:**

> Salamat po. [Sagutin kung malinaw ang sagot.] I-note ko rin po iyan para mabalikan natin pagkatapos nitong sample flow.

**Kapag may hindi ka pa sigurado:**

> Iche-check ko po ang specific case na iyan para tama ang maibigay kong sagot. Isusulat ko muna ang example ninyo.

**Kapag may bagong feature request:**

> Noted po. Pwede po bang ilarawan kung anong actual na situation ninyo ito kailangan? Ire-review namin kung paano ito papasok sa agreed scope at existing flow.

**Kapag huminto o nag-error ang demo:**

> Sandali lang po, iche-check ko ang nangyari. Kung hindi agad bumalik, ipapakita ko muna ang nakahandang sample screen para maituloy ang paliwanag. I-note natin ang issue para mabalikan.

*Kung nag-error pagkatapos ng Save/Confirm, i-check muna ang saved outcome bago ulitin. Huwag basta mag-submit ulit ng posibleng na-record nang action.*

**Kapag tinanong kung automatic nang nagbabago ang location dahil na-scan:**

> Sa scan po, bubuksan muna ang record. Ang confirmed OUT o IN action ang nagre-record ng handoff. Kaya ang location ay batay sa huling recorded movement.

**Kapag tinanong kung lahat ng anim na offices ay dadaan sa DV route:**

> Yung route na ipinakita ay para sa usual DV example. Ang ibang document types at office workflows ay may sarili nilang applicable na handling. Pwede nating tingnan ang specific case ng inyong office.

## Batayan ng script

- [PRD](../PRD.md): purpose, actors, physical handoffs, requests, route guidance, alerts, at report scope.
- [Existing client meeting script](CLIENT-MEETING-SCRIPT.md): demo at feedback format. Ang school-approval at evaluation-schedule statements nito ay hindi ipinapalagay sa script na ito.
- [Study objectives](../thesis/SmartFlow_Capstone1.md): development at user-feedback evaluation purpose. Ang maikling spoken purpose ay layunin ng pag-aaral; hindi ito pahayag na kumpleto na ang client evaluation o na napatunayan na ang improvement. Hindi nito ina-adopt ang luma o hindi pa resolved na platform, COA, at objective-count claims sa manuscript.
- [Testing guide](../TESTING.md): isolation at data-preservation requirements. Walang live demo o bagong acceptance check na isinagawa para sa pagsulat ng script.
