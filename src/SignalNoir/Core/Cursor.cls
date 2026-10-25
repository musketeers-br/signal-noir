Class SignalNoir.Core.Cursor Extends %RegisteredObject
{

/// Opaque list cursor over (lastEventAt, caseId): base64url of
/// "lastEventAt|caseId", no padding. Pure.
ClassMethod Encode(lastEventAt As %String, caseId As %String) As %String
{
	Return ..B64(lastEventAt _ "|" _ caseId)
}

/// Returns 0 when the cursor does not decode to a UTC time and a caseId
ClassMethod Decode(cursor As %String, Output lastEventAt As %String, Output caseId As %String) As %Boolean
{
	Set (lastEventAt, caseId) = ""
	If (cursor = "") || (cursor '? 1.(1AN,1"-",1"_")) Return 0
	Set raw = $Translate(cursor, "-_", "+/")
	Set raw = raw _ $Extract("===", 1, (4 - ($Length(raw) # 4)) # 4)
	Set text = ""
	Try {
		Set text = $System.Encryption.Base64Decode(raw)
	}
	Catch {
		Return 0
	}
	If $Length(text, "|") '= 2 Return 0
	Set at = $Piece(text, "|", 1)
	Set id = $Piece(text, "|", 2)
	If at '? 4N1"-"2N1"-"2N1"T"2N1":"2N1":"2N.1(1"."1.6N)1"Z" Return 0
	If id '? 1"case_"4.64(1AN,1"_",1"-") Return 0
	Set lastEventAt = at
	Set caseId = id
	Return 1
}

ClassMethod B64(text As %String) As %String
{
	Set out = $System.Encryption.Base64Encode(text, 1)
	Return $Translate(out, "+/=", "-_")
}

}
