Class SignalNoir.Core.Identity Extends %RegisteredObject
{

/// Patient-identity rule (feature 009): one place decides whether recorded
/// synthetic patient records collide with the Order's patient, for the Rules
/// proposer and for the Review Dossier alike. Pure: it reads only Evidence
/// already recorded (tool.receipts_and_orders_by_patient) and the Order.
/// Patients in recorded receipts/orders evidence that share the Order's
/// patient name but differ in identity
ClassMethod Collisions(evidence As %ListOfObjects, order As %DynamicObject) As %DynamicArray
{
	Set out = []
	Set own = $Select($IsObject(order) && $IsObject(order.patient): order.patient, 1: "")
	If '$IsObject(own) || (own.name = "") Return out
	Set name = ..Norm(own.name)
	Kill seen
	Set records = []
	Do records.%Push({"patient": (own), "source": "order"})
	For i = 1 : 1 : evidence.Count() {
		Set ev = evidence.GetAt(i)
		If (ev.source '= "tool.receipts_and_orders_by_patient") || (ev.kind '= "fact") || '$IsObject(ev.result) || '$IsObject(ev.result.items) Continue
		For j = 0 : 1 : ev.result.items.%Size() - 1 {
			Set item = ev.result.items.%Get(j)
			Set snap = item.orderSnapshot
			If '$IsObject(snap) || '$IsObject(snap.patient) Continue
			Do records.%Push({"patient": (snap.patient), "source": (ev.evidenceId)})
		}
	}
	; one record per patientId with the same normalized name
	For i = 0 : 1 : records.%Size() - 1 {
		Set p = records.%Get(i).patient
		If (..Norm(p.name) '= name) || (p.patientId = "") Continue
		If $Data(seen(p.patientId)) Continue
		Set seen(p.patientId) = i
	}
	Set n = 0, k = ""
	For {
		Set k = $Order(seen(k))
		Quit:k=""
		Set n = n + 1
	}
	If n < 2 Return out
	Set k = ""
	For {
		Set k = $Order(seen(k), 1, i)
		Quit:k=""
		Set rec = records.%Get(i)
		Set p = rec.patient
		Set fields = {}, divergent = []
		For f = "patientId", "name", "birthDate", "sex" {
			Set v = p.%Get(f)
			If v '= "" Do fields.%Set(f, v)
			Set other = own.%Get(f)
			Set differs = $Select(f = "name": ..Norm(v) '= ..Norm(other), 1: v '= other)
			If differs && ((v '= "") || (other '= "")) Do divergent.%Push(f)
		}
		; the Order's own record is the reference: it lists what the others diverge on
		If rec.source = "order" {
			Set divergent = []
			Set j = ""
			For {
				Set j = $Order(seen(j), 1, idx)
				Quit:j=""
				If idx = i Continue
				Set q = records.%Get(idx).patient
				For f = "patientId", "name", "birthDate", "sex" {
					Set differs = $Select(f = "name": ..Norm(q.%Get(f)) '= ..Norm(p.%Get(f)), 1: q.%Get(f) '= p.%Get(f))
					If differs && '..Has(divergent, f) Do divergent.%Push(f)
				}
			}
		}
		Do out.%Push({"recordRef": (p.patientId), "source": (rec.source), "fields": (fields), "divergentFields": (divergent)})
	}
	Return out
}

ClassMethod Norm(text) As %String [ Private ]
{
	Return $ZConvert(##class(SignalNoir.Core.Canon).Trim($Get(text)), "L")
}

ClassMethod Has(arr As %DynamicArray, value As %String) As %Boolean [ Private ]
{
	For i = 0 : 1 : arr.%Size() - 1 {
		If arr.%Get(i) = value Return 1
	}
	Return 0
}

}
