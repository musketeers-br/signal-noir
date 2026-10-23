Class SignalNoir.Core.Canon Extends %RegisteredObject
{

/// Equivalence-key canonization seam: ordered codes, UTC, normalized case.
/// Canonical shape: patientId|CODE1,CODE2|<ISO-8601 UTC Z>|specimenId
/// Used by Order acceptance; the Simulador never supplies a canonized key.

ClassMethod EquivalenceKey(patientId As %String, examCodes As %ListOfDataTypes, collectedAt As %String, specimenId As %String) As %String
{
	Set codes = ""
	Set n = 0
	If $IsObject(examCodes) {
		For i = 1 : 1 : examCodes.Count() {
			Set c = $ZCONVERT(##class(SignalNoir.Core.Canon).Trim($Get(examCodes.GetAt(i))), "U")
			If c = "" Continue
			If $ListFind($ListFromString(codes, ","), c) > 0 Continue
			Set codes = codes _ $Select(n = 0 : "", 1 : ",") _ c
			Set n = n + 1
		}
	}
	Set codes = ##class(SignalNoir.Core.Canon).OrderCodes(codes)
	Return ##class(SignalNoir.Core.Canon).Trim($Get(patientId)) _ "|" _ codes _ "|" _ ##class(SignalNoir.Core.Canon).NormalizeUtc($Get(collectedAt)) _ "|" _ ##class(SignalNoir.Core.Canon).Trim($Get(specimenId))
}

/// Canonizes an existing pipe-format key (idempotent)
ClassMethod Canonize(key As %String) As %String
{
	If key = "" Return ""
	Set patientId = $Piece(key, "|", 1)
	Set codes = $Piece(key, "|", 2)
	Set collectedAt = $Piece(key, "|", 3)
	Set specimenId = $Piece(key, "|", 4)
	Set patientId = $ZCONVERT(##class(SignalNoir.Core.Canon).Trim(patientId), "U")
	Set specimenId = $ZCONVERT(##class(SignalNoir.Core.Canon).Trim(specimenId), "U")
	Set codes = ##class(SignalNoir.Core.Canon).OrderCodes($ZCONVERT(##class(SignalNoir.Core.Canon).Trim(codes), "U"))
	Return patientId _ "|" _ codes _ "|" _ ##class(SignalNoir.Core.Canon).NormalizeUtc(collectedAt) _ "|" _ specimenId
}

/// Uppercased, deduplicated, ordered code list (normalized case + ordered codes)
ClassMethod OrderCodes(codes As %String) As %String
{
	Set out = ""
	Set rest = codes
	While rest '= "" {
		Set c = $Piece(rest, ",", 1)
		Set rest = $Piece(rest, ",", 2, 999)
		Set c = $ZCONVERT(##class(SignalNoir.Core.Canon).Trim(c), "U")
		If c = "" Continue
		If $ListFind($ListFromString(out, ","), c) > 0 Continue
		Set out = out _ $Select(out = "" : "", 1 : ",") _ c
	}
	; order the codes
	Set list = $ListFromString(out, ",")
	Set n = $ListLength(list)
	For i = 1 : 1 : n {
		For j = i + 1 : 1 : n {
			If $ListGet(list, j) < $ListGet(list, i) {
				Set tmp = $ListGet(list, i)
				Set $List(list, i) = $ListGet(list, j)
				Set $List(list, j) = tmp
			}
		}
	}
	Set sorted = ""
	For i = 1 : 1 : n {
		Set sorted = sorted _ $Select(i = 1 : "", 1 : ",") _ $ListGet(list, i)
	}
	Return sorted
}

/// Normalizes a timestamp to ISO-8601 UTC with Z. Accepts
/// "YYYY-MM-DD HH:MM:SS" (and fractional/ISO-T variants). Returns "" when the
/// input cannot be parsed.
ClassMethod NormalizeUtc(ts As %String) As %String
{
	Set ts = ##class(SignalNoir.Core.Canon).Trim($Get(ts))
	If ts = "" Return ""
	Set ts = $Replace(ts, "T", " ")
	Set date = $Piece(ts, " ", 1)
	Set time = $Piece(ts, " ", 2)
	If time = "" Return ""
	Set time = $Piece(time, ".")   ; strip fraction
	Set time = $Piece(time, "Z")   ; strip suffix if present
	If $Length(date) '= 10 Return ""
	If $Length(time) < 8 Return ""
	Set time = $Extract(time, 1, 8)
	Set h = $Piece(time, ":", 1)
	Set m = $Piece(time, ":", 2)
	Set s = $Piece(time, ":", 3)
	If h > 23 Return ""
	If m > 59 Return ""
	If s > 59 Return ""
	Return date _ "T" _ time _ "Z"
}

/// Trims leading and trailing whitespace (spaces and tabs). The platform
/// build in use exposes no $ZTRIM, so trimming lives here.
ClassMethod Trim(s As %String) As %String
{
	Set s = $Get(s)
	Set n = $Length(s)
	Set start = 1
	Set stop = n
	Set tab = $Char(9)
	Set exit = 0
	While ((start <= stop) && (exit = 0)) {
		Set c = $Extract(s, start)
		If ((c = " ") || (c = tab)) {
			Set start = start + 1
		} Else {
			Set exit = 1
		}
	}
	Set exit = 0
	While ((start <= stop) && (exit = 0)) {
		Set c = $Extract(s, stop)
		If ((c = " ") || (c = tab)) {
			Set stop = stop - 1
		} Else {
			Set exit = 1
		}
	}
	If start > stop Return ""
	Return $Extract(s, start, stop)
}

}
