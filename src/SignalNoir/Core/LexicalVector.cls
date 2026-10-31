Class SignalNoir.Core.LexicalVector Extends %RegisteredObject
{

/// The lexical similarity vector (feature 015, research R3): every
/// "label=value" token of a precedent text is hashed (signed feature hashing)
/// into DIMENSION buckets and the vector is L2-normalized. Deterministic, no
/// I/O, no corpus statistics, so a stored vector never changes. It is word
/// overlap, not semantics, and is always reported as mode "lexical".
Parameter DIMENSION = 1536;

Parameter MODEL = "lexical-hash-v1";

/// $List of DIMENSION numbers (all zero for an empty text)
ClassMethod Of(text As %String) As %List
{
	Set n = ..#DIMENSION
	For i = 1 : 1 : $Length(text, " ") {
		Set token = $ZConvert($Piece(text, " ", i), "L")
		If token = "" Continue
		Set h = $ZCRC(token, 7)
		Set bucket = h # n
		Set sign = $Select((h \ n) # 2: -1, 1: 1)
		Set acc(bucket) = $Get(acc(bucket)) + sign
	}
	Set norm = 0, b = ""
	For {
		Set b = $Order(acc(b), 1, v)
		Quit:b=""
		Set norm = norm + (v * v)
	}
	Set norm = $ZSqr(norm)
	Set out = ""
	For b = 0 : 1 : n - 1 {
		Set v = $Get(acc(b), 0)
		Set out = out _ $ListBuild($Select((v = 0) || (norm = 0): 0, 1: $Normalize(v / norm, 8)))
	}
	Return out
}

/// Comma list for TO_VECTOR
ClassMethod Csv(vector As %List) As %String
{
	Return $ListToString(vector, ",")
}

/// Cosine similarity of two vectors of the same length (0 when either is zero)
ClassMethod Cosine(a As %List, b As %List) As %Numeric
{
	Set dot = 0, na = 0, nb = 0
	For i = 1 : 1 : $ListLength(a) {
		Set x = +$ListGet(a, i), y = +$ListGet(b, i)
		Set dot = dot + (x * y), na = na + (x * x), nb = nb + (y * y)
	}
	If (na = 0) || (nb = 0) Return 0
	Return dot / ($ZSqr(na) * $ZSqr(nb))
}

}
