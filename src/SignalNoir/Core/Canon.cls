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
			Set c = $ZCONVERT(##class(SignalNoir.Core.Canon).Trim(examCodes.GetAt(i)), "U")
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
			If $ListGet(list, i) ] $ListGet(list, j) {
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

/// Normalizes a timestamp to ISO-8601 UTC with Z (seconds precision).
/// Accepts "YYYY-MM-DD[T ]HH:MM:SS[.fff][Z|+HH:MM|-HH:MM|+HHMM|-HHMM]";
/// no zone means UTC. Offsets are applied, so the result is the same instant
/// in UTC. Returns "" when the input cannot be read.
ClassMethod NormalizeUtc(ts As %String) As %String
{
	Set ts = ##class(SignalNoir.Core.Canon).Trim($Get(ts))
	If ts = "" Return ""
	Set ts = $Replace(ts, "T", " ")
	Set date = $Piece(ts, " ", 1)
	Set rest = $Piece(ts, " ", 2, 9)
	If (date '? 4N1"-"2N1"-"2N) || ($Length(rest) < 8) Return ""
	Set time = $Extract(rest, 1, 8)
	Set zone = $Extract(rest, 9, *)
	If $Extract(zone) = "." {
		Set zone = $Extract(zone, 2, *)
		While (zone '= "") && ($Extract(zone) ? 1N) {
			Set zone = $Extract(zone, 2, *)
		}
	}
	If time '? 2N1":"2N1":"2N Return ""
	Set h = +$Piece(time, ":", 1), m = +$Piece(time, ":", 2), s = +$Piece(time, ":", 3)
	If (h > 23) || (m > 59) || (s > 59) Return ""
	Set offset = 0
	If (zone = "") || (zone = "Z") {
		Set offset = 0
	} ElseIf zone ? 1(1"+",1"-")2N.1":"2N {
		Set digits = $Translate($Extract(zone, 2, *), ":")
		Set oh = +$Extract(digits, 1, 2), om = +$Extract(digits, 3, 4)
		If (oh > 23) || (om > 59) Return ""
		Set offset = ((oh * 3600) + (om * 60)) * $Select($Extract(zone) = "-": -1, 1: 1)
	} Else {
		Return ""
	}
	Set day = $ZDateH(date, 3, , , , , , , "")
	If day = "" Return ""
	If $ZDate(day, 3) '= date Return ""
	Set secs = (h * 3600) + (m * 60) + s - offset
	While secs < 0 {
		Set secs = secs + 86400
		Set day = day - 1
	}
	While secs >= 86400 {
		Set secs = secs - 86400
		Set day = day + 1
	}
	Return $ZDate(day, 3) _ "T" _ $ZTime(secs, 1) _ "Z"
}

/// The key of an Origin Order snapshot (FR-006): patientId, exam codes,
/// collection time in UTC and specimenId, canonized.
ClassMethod FromSnapshot(snapshot As %DynamicObject) As %String
{
	If '$IsObject(snapshot) Return ""
	Set patientId = "", specimenId = "", collectedAt = ""
	If $IsObject(snapshot.patient) Set patientId = snapshot.patient.patientId
	If $IsObject(snapshot.specimen) {
		Set specimenId = snapshot.specimen.specimenId
		Set collectedAt = snapshot.specimen.collectedAt
	}
	Set codes = ##class(%ListOfDataTypes).%New()
	If $IsObject(snapshot.exams) {
		For i = 0 : 1 : snapshot.exams.%Size() - 1 {
			Set exam = snapshot.exams.%Get(i)
			If $IsObject(exam) Do codes.Insert(exam.code)
		}
	}
	Set utc = ##class(SignalNoir.Core.Canon).NormalizeUtc(collectedAt)
	If utc = "" Return ""
	Return ##class(SignalNoir.Core.Canon).Canonize(##class(SignalNoir.Core.Canon).EquivalenceKey(patientId, codes, utc, specimenId))
}

/// The key split into the contract EquivalenceKey object
ClassMethod Parts(key As %String) As %DynamicObject
{
	Set parts = ##class(%DynamicObject).%New()
	Do parts.%Set("patientId", $Piece(key, "|", 1))
	Set codes = ##class(%DynamicArray).%New()
	Set list = $Piece(key, "|", 2)
	For i = 1 : 1 : $Length(list, ",") {
		If $Piece(list, ",", i) '= "" Do codes.%Push($Piece(list, ",", i))
	}
	Do parts.%Set("examCodes", codes)
	Do parts.%Set("collectedAt", $Piece(key, "|", 3))
	Do parts.%Set("specimenId", $Piece(key, "|", 4))
	Return parts
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
