Class SignalNoir.Sim.Script Extends %RegisteredObject
{

/// The scenario script (contracts/scenario-script.md): attempt rules decided
/// against the private partnerRule, holds (research D6) and active events.
/// Nominal holds, in seconds
Parameter FAST = 0.05;

Parameter SLOW = 5;

Parameter TIMEOUT = 90;

/// Seconds added to the client timeout so a scripted timeout is always one
Parameter MARGIN = 5;

/// The respond rule of the first matching attempt rule (a copy), or a 500 if none
ClassMethod Match(variant As %DynamicObject, attempt As %Integer, order As %DynamicObject, active As %List = "") As %DynamicObject
{
	Set rules = $Select($IsObject(variant.script) && $IsObject(variant.script.attempts): variant.script.attempts, 1: [])
	Set state = ..RuleState(variant, order)
	For i = 0 : 1 : rules.%Size() - 1 {
		Set rule = rules.%Get(i), m = rule.match
		Set hit = 0
		If m = "any" {
			Set hit = 1
		} ElseIf $Extract(m, 1, 8) = "attempt:" {
			Set n = $Extract(m, 9, *)
			Set hit = $Select($Extract(n, *) = "+": attempt >= +n, 1: attempt = +n)
		} ElseIf $Extract(m, 1, 11) = "afterEvent:" {
			Set hit = ($ListFind(active, $Extract(m, 12, *)) > 0)
		} ElseIf (m = "beforeMapping") || (m = "wrongMapping") || (m = "accepted") {
			Set hit = (state = m)
		}
		If hit Return {}.%FromJSON(rule.respond.%ToJSON())
	}
	Return {"status": 500, "body": "empty", "delay": "fast"}
}

/// beforeMapping, wrongMapping or accepted for a variant with a private
/// rule; "" without one. Codes and contexts compare trimmed and upper-case.
ClassMethod RuleState(variant As %DynamicObject, order As %DynamicObject) As %String
{
	If '$IsObject(variant.partnerRule) || '$IsObject(variant.partnerRule.accepts) Return ""
	Set accepts = variant.partnerRule.accepts
	Set exams = $Select($IsObject(order) && $IsObject(order.exams): order.exams, 1: [])
	Set known = 0
	For i = 0 : 1 : exams.%Size() - 1 {
		Set code = ..Norm($Select($IsObject(exams.%Get(i)): exams.%Get(i).code, 1: exams.%Get(i)))
		For j = 0 : 1 : accepts.%Size() - 1 {
			Set a = accepts.%Get(j)
			If ..Norm(a.code) '= code Continue
			Set known = 1
			If ..When(a.when, order) Return "accepted"
		}
	}
	Return $Select(known: "wrongMapping", 1: "beforeMapping")
}

/// Seconds the Partner holds its answer: fast, slow (scaled) or timeout,
/// which always exceeds the client timeout (research D6, SIM-Q5)
ClassMethod Hold(delayClass As %String, timeScale As %Numeric = 1, clientTimeout As %Numeric = "") As %Numeric
{
	If clientTimeout = "" Set clientTimeout = ..ClientTimeout()
	If delayClass = "timeout" {
		Set nominal = ..#TIMEOUT * timeScale, floor = clientTimeout + ..#MARGIN
		Return $Select(nominal > floor: nominal, 1: floor)
	}
	If delayClass = "slow" Return ..#SLOW * timeScale
	Return ..#FAST
}

/// The client timeout the Partner must outlast: a test override, then
/// SN_PARTNER_TIMEOUT_SECONDS (the product's own setting), then 60
ClassMethod ClientTimeout() As %Numeric
{
	Set v = $Get(^SignalNoir.Sim.Config("clientTimeoutSeconds"))
	If v = "" Set v = $System.Util.GetEnviron("SN_PARTNER_TIMEOUT_SECONDS")
	Return $Select(+v > 0: +v, 1: 60)
}

/// Event types in force for an instance: a degradation until a recovery, a
/// maintenance until its end; a cancellation stays
ClassMethod Active(appliedEvents As %DynamicArray) As %List
{
	Set degraded = 0, maintenance = 0, cancelled = 0
	For i = 0 : 1 : appliedEvents.%Size() - 1 {
		Set t = appliedEvents.%Get(i).type
		If t = "PARTNER_DEGRADES" Set degraded = 1
		If t = "PARTNER_RECOVERS" Set degraded = 0
		If t = "MAINTENANCE_STARTS" Set maintenance = 1
		If t = "MAINTENANCE_ENDS" Set maintenance = 0
		If t = "ORDER_CANCELLED_AT_ORIGIN" Set cancelled = 1
	}
	Set out = ""
	If degraded Set out = out _ $ListBuild("PARTNER_DEGRADES")
	If maintenance Set out = out _ $ListBuild("MAINTENANCE_STARTS")
	If cancelled Set out = out _ $ListBuild("ORDER_CANCELLED_AT_ORIGIN")
	Return out
}

ClassMethod When(when, order As %DynamicObject) As %Boolean [ Private ]
{
	If '$IsObject(when) Return 1
	Set it = when.%GetIterator()
	While it.%GetNext(.path, .allowed) {
		Set value = order
		For p = 1 : 1 : $Length(path, ".") {
			Set value = $Select($IsObject(value): value.%Get($Piece(path, ".", p)), 1: "")
		}
		Set ok = 0
		For k = 0 : 1 : allowed.%Size() - 1 If ..Norm(allowed.%Get(k)) = ..Norm(value) Set ok = 1
		If 'ok Return 0
	}
	Return 1
}

ClassMethod Norm(value As %String) As %String [ Private ]
{
	Return $ZConvert($ZStrip(value, "<>W"), "U")
}

}
