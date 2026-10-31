Class SignalNoir.Application.Reference.Store Extends %RegisteredObject
{

/// The versioned reference data of the Validator (004, research D5): policies and approved
/// Mappings are fixture classes, one per version, found through the class dictionary and
/// checked before anything is registered. Registered versions and the versions in force live in
/// ^SignalNoir.Reference. A snapshot is built fresh from the fixture on every call, so a caller
/// can change what it got and nothing else sees it.
///   ^SignalNoir.Reference("fixture", "policy"|"mapping", version) = fixture class
///   ^SignalNoir.Reference("inForce", "policy"|"mapping")          = version in force (explicit)
///   ^SignalNoir.Reference("defaultPackage")                        = package loaded on first use
Parameter DEFAULTPACKAGE = "SignalNoir.Application.Reference";

Parameter POLICYKEYS = "version,attempt,substitution,maintenanceWindows,partnerHealth,approval";

Parameter CONDITIONFIELDS = "specimenType,specimenUnit";

/// Registers every fixture class of a package. All or nothing: one malformed fixture refuses
/// the whole package (FR-024) and leaves the registry and the versions in force as they were.
/// Loading the same package again changes nothing.
ClassMethod Load(package As %String) As SignalNoir.Core.Result
{
	Set classes = ..Discover(package)
	If $ListLength(classes) = 0 Return ##class(SignalNoir.Core.Result).Error("NOT_FOUND", "no reference fixture classes in package: " _ package)
	Set problems = [], found = 0
	For i = 1 : 1 : $ListLength(classes) {
		Set class = $List(classes, i)
		Set content = ..Content(class)
		If '$IsObject(content) {
			Do problems.%Push(class _ ": Content is not a JSON object")
			Continue
		}
		Set kind = ..KindOf(content)
		Set version = $Select(kind = "policy": content.%Get("version"), kind = "mapping": content.%Get("mappingVersion"), 1: "")
		Set found = 0
		Set list = ..Validate(content)
		For j = 0 : 1 : list.%Size() - 1 Do problems.%Push(class _ ": " _ list.%Get(j))
		If (kind = "") || (version = "") Continue
		If $Parameter(class, "VERSION") '= version Do problems.%Push(class _ ": VERSION parameter """ _ $Parameter(class, "VERSION") _ """ differs from the content's " _ version)
		If $Data(new(kind, version)) Do problems.%Push(class _ ": " _ kind _ " version " _ version _ " is also provided by " _ new(kind, version))
		If $Get(^SignalNoir.Reference("fixture", kind, version)) '= "" && (^SignalNoir.Reference("fixture", kind, version) '= class) {
			Do problems.%Push(class _ ": " _ kind _ " version " _ version _ " is already registered by " _ ^SignalNoir.Reference("fixture", kind, version))
		}
		Set new(kind, version) = class
	}
	If problems.%Size() > 0 {
		Return ##class(SignalNoir.Core.Result).ErrorWith("VALIDATION_FAILED", "reference data refused: " _ problems.%Get(0), {"problems": (problems)})
	}
	Set count = 0, kind = ""
	For {
		Set kind = $Order(new(kind))
		Quit:kind=""
		Set version = ""
		For {
			Set version = $Order(new(kind, version), 1, class)
			Quit:version=""
			Set ^SignalNoir.Reference("fixture", kind, version) = class
			Set count = count + 1
		}
	}
	Return ##class(SignalNoir.Core.Result).OkRef(count)
}

/// The problems of one fixture's JSON, empty when it is valid. A Policy Set has "version", a
/// Mapping Set "mappingVersion".
ClassMethod Validate(fixture As %DynamicObject) As %DynamicArray
{
	Set problems = []
	If '$IsObject(fixture) || 'fixture.%IsA("%Library.DynamicObject") {
		Do problems.%Push("the fixture is not a JSON object")
		Return problems
	}
	Set kind = ..KindOf(fixture)
	If kind = "policy" {
		Do ..CheckPolicy(fixture, problems)
	} ElseIf kind = "mapping" {
		Do ..CheckMappings(fixture, problems)
	} Else {
		Do problems.%Push("the fixture has neither ""version"" (policies) nor ""mappingVersion"" (mappings)")
	}
	Return problems
}

/// The snapshot of the versions in force: the explicit ones, else the highest of each kind
ClassMethod InForce() As SignalNoir.Core.Result
{
	Do ..Ensure()
	Set policy = $Get(^SignalNoir.Reference("inForce", "policy"), ..Highest("policy"))
	Set mapping = $Get(^SignalNoir.Reference("inForce", "mapping"), ..Highest("mapping"))
	If (policy = "") || (mapping = "") Return ..Unavailable()
	Return ..Snapshot(policy, mapping)
}

/// The snapshot a run evaluates against: inside a benchmark run, the versions it pinned (a
/// missing one falls back to the version in force); otherwise the versions in force
ClassMethod For(run As %DynamicObject) As SignalNoir.Core.Result
{
	If '$IsObject(run) || 'run.%Get("inRun") Return ..InForce()
	Set inForce = ..InForce()
	Set policy = run.%Get("policyVersion"), mapping = run.%Get("mappingVersion")
	If (policy = "") && (mapping = "") Return inForce
	If (policy = "") || (mapping = "") {
		If 'inForce.ok Return inForce
		If policy = "" Set policy = inForce.obj.policyVersion
		If mapping = "" Set mapping = inForce.obj.mappingVersion
	}
	Return ..Snapshot(policy, mapping)
}

/// Chooses the versions in force. Both must be registered; nothing changes otherwise.
ClassMethod SetInForce(policyVersion As %String, mappingVersion As %String) As SignalNoir.Core.Result
{
	Do ..Ensure()
	If $Get(^SignalNoir.Reference("fixture", "policy", policyVersion)) = "" Return ##class(SignalNoir.Core.Result).Error("NOT_FOUND", "policy version not found: " _ policyVersion)
	If $Get(^SignalNoir.Reference("fixture", "mapping", mappingVersion)) = "" Return ##class(SignalNoir.Core.Result).Error("NOT_FOUND", "mapping version not found: " _ mappingVersion)
	Set ^SignalNoir.Reference("inForce", "policy") = policyVersion
	Set ^SignalNoir.Reference("inForce", "mapping") = mappingVersion
	Return ##class(SignalNoir.Core.Result).OkRef(policyVersion _ ":" _ mappingVersion)
}

/// -1, 0 or 1: dotted versions compared number by number (2026.10.9 < 2026.10.10)
ClassMethod Compare(a As %String, b As %String) As %Integer
{
	Set n = $Length(a, "."), m = $Length(b, ".")
	For i = 1 : 1 : $Select(n > m: n, 1: m) {
		Set x = $Piece(a, ".", i), y = $Piece(b, ".", i)
		If (x = +x) && (y = +y) {
			If x < y Return -1
			If x > y Return 1
		} ElseIf x '= y {
			Return $Select(x ] y: 1, 1: -1)
		}
	}
	Return 0
}

/// A fresh, detached snapshot of one policy version and one mapping version
ClassMethod Snapshot(policyVersion As %String, mappingVersion As %String) As SignalNoir.Core.Result [ Private ]
{
	Set policyClass = $Get(^SignalNoir.Reference("fixture", "policy", policyVersion))
	If policyClass = "" Return ##class(SignalNoir.Core.Result).Error("NOT_FOUND", "reference data unavailable: policy version not found: " _ policyVersion)
	Set mappingClass = $Get(^SignalNoir.Reference("fixture", "mapping", mappingVersion))
	If mappingClass = "" Return ##class(SignalNoir.Core.Result).Error("NOT_FOUND", "reference data unavailable: mapping version not found: " _ mappingVersion)
	Set policy = ..Content(policyClass), mapping = ..Content(mappingClass)
	If '$IsObject(policy) || '$IsObject(mapping) Return ##class(SignalNoir.Core.Result).Error("NOT_FOUND", "reference data unavailable: a fixture could not be read")
	Set policies = {}
	Set it = policy.%GetIterator()
	While it.%GetNext(.key, .value) {
		If key = "version" Continue
		If $IsObject(value) {
			Do policies.%Set(key, value)
		} Else {
			Do policies.%Set(key, value, policy.%GetTypeOf(key))
		}
	}
	Set ref = ##class(SignalNoir.Core.Dto.ReferenceData).%New()
	Set ref.policyVersion = policyVersion, ref.mappingVersion = mappingVersion
	Set ref.policies = policies, ref.mappings = mapping.items
	Set ref.synonyms = $Select(mapping.%GetTypeOf("synonyms") = "object": mapping.synonyms, 1: {})
	Return ##class(SignalNoir.Core.Result).OkObj(ref)
}

ClassMethod Unavailable() As SignalNoir.Core.Result [ Private ]
{
	Return ##class(SignalNoir.Core.Result).Error("NOT_FOUND", "reference data unavailable: no policy or mapping version is in force")
}

/// Loads the default package when a kind has no registered version (first use)
ClassMethod Ensure() [ Private ]
{
	If (..Highest("policy") '= "") && (..Highest("mapping") '= "") Quit
	Do ..Load($Get(^SignalNoir.Reference("defaultPackage"), ..#DEFAULTPACKAGE))
}

/// The highest registered version of a kind, "" when none
ClassMethod Highest(kind As %String) As %String [ Private ]
{
	Set best = "", version = ""
	For {
		Set version = $Order(^SignalNoir.Reference("fixture", kind, version))
		Quit:version=""
		If (best = "") || (..Compare(version, best) > 0) Set best = version
	}
	Return best
}

/// Classes of the package (and its sub-packages) that carry an XData Content block
ClassMethod Discover(package As %String) As %List [ Private ]
{
	Set out = ""
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM %Dictionary.CompiledClass WHERE ID %STARTSWITH ? ORDER BY ID", package _ ".")
	While rs.%Next() {
		Set id = rs.%Get("ID")
		If ##class(%Dictionary.CompiledXData).%ExistsId(id _ "||Content") Set out = out _ $ListBuild(id)
	}
	Return out
}

/// The JSON of a fixture class's Content block, "" when it cannot be read
ClassMethod Content(class As %String) As %DynamicObject [ Private ]
{
	Try {
		Set x = ##class(%Dictionary.CompiledXData).%OpenId(class _ "||Content")
		If '$IsObject(x) Return ""
		Set json = {}.%FromJSON(x.Data)
	} Catch {
		Set json = ""
	}
	Return json
}

ClassMethod KindOf(fixture As %DynamicObject) As %String [ Private ]
{
	If fixture.%GetTypeOf("version") '= "unassigned" Return "policy"
	If fixture.%GetTypeOf("mappingVersion") '= "unassigned" Return "mapping"
	Return ""
}

// ---------------------------------------------------------------- validation

ClassMethod CheckPolicy(p As %DynamicObject, problems As %DynamicArray) [ Private ]
{
	Do ..OnlyKeys(p, ..#POLICYKEYS, "policy", problems)
	For key = "version", "attempt", "substitution", "maintenanceWindows", "partnerHealth", "approval" {
		If p.%GetTypeOf(key) = "unassigned" Do problems.%Push("missing policy key: " _ key)
	}
	If (p.%GetTypeOf("version") '= "unassigned") && ((p.%GetTypeOf("version") '= "string") || (p.version = "")) Do problems.%Push("version must be a non-empty string")
	Set a = ..Section(p, "attempt", "attempt", problems)
	If $IsObject(a) {
		Do ..OnlyKeys(a, "maxAttempts", "attempt", problems)
		Do ..Number(a, "maxAttempts", "attempt.maxAttempts", 1, "", 1, problems)
	}
	Set s = ..Section(p, "substitution", "substitution", problems)
	If $IsObject(s) {
		Do ..OnlyKeys(s, "enabled", "substitution", problems)
		If s.%GetTypeOf("enabled") '= "boolean" Do problems.%Push("substitution.enabled must be a boolean")
	}
	If p.%GetTypeOf("maintenanceWindows") = "array" {
		For i = 0 : 1 : p.maintenanceWindows.%Size() - 1 {
			Set w = p.maintenanceWindows.%Get(i), where = "maintenanceWindows[" _ i _ "]"
			If p.maintenanceWindows.%GetTypeOf(i) '= "object" {
				Do problems.%Push(where _ " must be an object")
				Continue
			}
			Do ..OnlyKeys(w, "partnerId,startsAt,endsAt", where, problems)
			For key = "partnerId", "startsAt", "endsAt" {
				If (w.%GetTypeOf(key) '= "string") || (w.%Get(key) = "") Do problems.%Push(where _ "." _ key _ " must be a non-empty string")
			}
		}
	} ElseIf p.%GetTypeOf("maintenanceWindows") '= "unassigned" {
		Do problems.%Push("maintenanceWindows must be an array")
	}
	Set h = ..Section(p, "partnerHealth", "partnerHealth", problems)
	If $IsObject(h) {
		Do ..OnlyKeys(h, "windowSeconds,maxErrorRate", "partnerHealth", problems)
		Do ..Number(h, "windowSeconds", "partnerHealth.windowSeconds", 1, "", 0, problems)
		Do ..Number(h, "maxErrorRate", "partnerHealth.maxErrorRate", 0, 1, 0, problems)
	}
	Set d = ..Section(p, "approval", "approval", problems)
	If $IsObject(d) {
		Do ..OnlyKeys(d, "deadlineSeconds", "approval", problems)
		Do ..Number(d, "deadlineSeconds", "approval.deadlineSeconds", 1, "", 0, problems)
	}
}

ClassMethod CheckMappings(m As %DynamicObject, problems As %DynamicArray) [ Private ]
{
	Do ..OnlyKeys(m, "mappingVersion,items,synonyms", "mapping set", problems)
	If (m.%GetTypeOf("mappingVersion") '= "string") || (m.mappingVersion = "") Do problems.%Push("mappingVersion must be a non-empty string")
	If m.%GetTypeOf("items") '= "array" {
		Do problems.%Push("items must be an array")
	} Else {
		For i = 0 : 1 : m.items.%Size() - 1 {
			Set where = "items[" _ i _ "]"
			If m.items.%GetTypeOf(i) '= "object" {
				Do problems.%Push(where _ " must be an object")
				Continue
			}
			Set item = m.items.%Get(i)
			Do ..OnlyKeys(item, "mappingId,mappingVersion,sourceCode,targetCode,conditions", where, problems)
			For key = "mappingId", "mappingVersion", "sourceCode", "targetCode" {
				If (item.%GetTypeOf(key) '= "string") || (item.%Get(key) = "") Do problems.%Push(where _ "." _ key _ " must be a non-empty string")
			}
			If (item.%GetTypeOf("mappingVersion") = "string") && (item.mappingVersion '= m.mappingVersion) Do problems.%Push(where _ ".mappingVersion " _ item.mappingVersion _ " differs from the set's " _ m.mappingVersion)
			If (item.%GetTypeOf("mappingId") = "string") && (item.mappingId '= "") {
				If $Data(ids(item.mappingId)) Do problems.%Push("duplicate mappingId: " _ item.mappingId)
				Set ids(item.mappingId) = ""
			}
			If item.%GetTypeOf("conditions") '= "object" {
				Do problems.%Push(where _ ".conditions must be an object")
			} Else {
				Set it = item.conditions.%GetIterator()
				While it.%GetNext(.field, .value) {
					If '$ListFind($ListFromString(..#CONDITIONFIELDS), field) Do problems.%Push(where _ ": unknown condition field: " _ field)
					If item.conditions.%GetTypeOf(field) '= "string" Do problems.%Push(where _ ".conditions." _ field _ " must be a string")
				}
			}
		}
	}
	If m.%GetTypeOf("synonyms") = "object" {
		Set it = m.synonyms.%GetIterator()
		While it.%GetNext(.field, .canon) {
			If '$ListFind($ListFromString(..#CONDITIONFIELDS), field) Do problems.%Push("synonyms: unknown condition field: " _ field)
			If m.synonyms.%GetTypeOf(field) '= "object" {
				Do problems.%Push("synonyms." _ field _ " must be an object")
				Continue
			}
			Set c = canon.%GetIterator()
			While c.%GetNext(.name, .variants) {
				If canon.%GetTypeOf(name) '= "array" Do problems.%Push("synonyms." _ field _ "." _ name _ " must be an array")
			}
		}
	} ElseIf m.%GetTypeOf("synonyms") '= "unassigned" {
		Do problems.%Push("synonyms must be an object")
	}
}

/// Pushes a problem for every key of the object that is not in the comma list
ClassMethod OnlyKeys(o As %DynamicObject, allowed As %String, where As %String, problems As %DynamicArray) [ Private ]
{
	Set list = $ListFromString(allowed)
	Set it = o.%GetIterator()
	While it.%GetNext(.key) {
		If '$ListFind(list, key) Do problems.%Push("unknown " _ $Select(where = "policy": "policy key", 1: "key in " _ where) _ ": " _ key)
	}
}

/// The object under a key, "" (with a problem) when missing or not an object
ClassMethod Section(p As %DynamicObject, key As %String, where As %String, problems As %DynamicArray) As %DynamicObject [ Private ]
{
	If p.%GetTypeOf(key) = "object" Return p.%Get(key)
	If p.%GetTypeOf(key) '= "unassigned" Do problems.%Push(where _ " must be an object")
	Return ""
}

/// A number within [min, max] ("" = unbounded); whole when integer
ClassMethod Number(o As %DynamicObject, key As %String, where As %String, min, max, integer As %Boolean, problems As %DynamicArray) [ Private ]
{
	If o.%GetTypeOf(key) '= "number" {
		Do problems.%Push(where _ " must be a number")
		Return
	}
	Set v = o.%Get(key)
	If integer && (v '= (v \ 1)) Do problems.%Push(where _ " must be a whole number")
	If (min '= "") && (v < min) Do problems.%Push(where _ " must be at least " _ min _ " (got " _ v _ ")")
	If (max '= "") && (v > max) Do problems.%Push(where _ " must be at most " _ max _ " (got " _ v _ ")")
}

}
