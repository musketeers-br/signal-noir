Class SignalNoir.Application.Benchmark.RunService Extends %RegisteredObject
{

/// Creates, starts and reads BenchmarkRuns (feature 010, plan D3, D4). The rules of
/// what a request may ask for are the Core's (RunPolicy); this class adds what needs
/// I/O: the Simulator's catalog, the pinned reference data, the one-run lock and the
/// records. It never touches a Case.
Property Clock As SignalNoir.Core.Port.Clock;

Property Ids As SignalNoir.Core.Port.IdGenerator;

/// When true (the default) Create starts the driver in its own process; tests turn it off
/// and call Runner.Step themselves
Property AutoStart As %Boolean [ InitialExpression = 1 ];

/// A catalog to use instead of the Simulator's (array of {family, subtype, variant, set})
Property Catalog As %DynamicArray;

/// The committed records the freeze check reads ({freeze, roles, reviews, usage}); tests set it, otherwise the
/// records of SignalNoir.Benchmark.Data are used
Property Data As %DynamicObject;

Parameter LOCKTIMEOUT = 5;

Parameter LOCKNAME = "^SignalNoir.BenchmarkRun";

Method %OnNew() As %Status
{
	Set ..Clock = ##class(SignalNoir.Application.SystemClock).%New()
	Set ..Ids = ##class(SignalNoir.Application.IdFactory).%New()
	Return $$$OK
}

/// The Simulator's catalog of scenario variants. Result.obj = the items (array)
Method LoadCatalog() As SignalNoir.Core.Result
{
	; an unset property can read as an empty array: only a non-empty catalog overrides the Simulator's
	If $IsObject(..Catalog) && ..Catalog.%Size() Return ##class(SignalNoir.Core.Result).OkObj(..Catalog)
	Set http = ##class(SignalNoir.Interop.SimulatorHttp).Call("", "GET", "/scenario-catalog", "", 10)
	If 'http.answered Return ##class(SignalNoir.Core.Result).Error("", "simulator unreachable: " _ http.error)
	If (http.status '= 200) || '$IsObject(http.json) || (http.json.%GetTypeOf("items") '= "array") Return ##class(SignalNoir.Core.Result).Error("", "simulator answered HTTP " _ http.status _ " for the catalog")
	Return ##class(SignalNoir.Core.Result).OkObj(http.json.items)
}

/// Validates, persists and starts a run. Result.obj = the run (contract BenchmarkRun).
/// Refusals are values: VALIDATION_FAILED (400), INVALID_TRANSITION (409, a run is
/// already created or running), "" for an internal failure (the Simulator is down).
Method Create(request As %DynamicObject) As SignalNoir.Core.Result
{
	Set catalog = ..LoadCatalog()
	If 'catalog.ok Return catalog
	Set valid = ##class(SignalNoir.Core.Benchmark.RunPolicy).Validate(request, catalog.obj)
	If 'valid.ok Return valid
	Set plan = valid.obj
	Set refusal = ..Complete(plan)
	If $IsObject(refusal) Return refusal
	Do ..Judge(plan, catalog.obj)
	Set lockName = ..#LOCKNAME
	Lock +@lockName:..#LOCKTIMEOUT
	If '$Test Return ##class(SignalNoir.Core.Result).Error("INVALID_TRANSITION", "another run is being created")
	Set result = ""
	Try {
		Set active = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS n FROM SignalNoir_Application_Model.BenchmarkRunRecord WHERE status IN ('created','running')")
		Do active.%Next()
		If '##class(SignalNoir.Core.Benchmark.RunPolicy).StartAllowed(active.%Get("n")) {
			Set result = ##class(SignalNoir.Core.Result).Error("INVALID_TRANSITION", "a BenchmarkRun is already created or running")
		} Else {
			Set rec = ..Persist(plan)
			Set result = ##class(SignalNoir.Core.Result).OkObj(..ToDto(rec))
			Set runId = rec.runId
		}
	}
	Catch ex {
		Set result = ##class(SignalNoir.Core.Result).Error("", "run not created: " _ ex.DisplayString())
	}
	Lock -@lockName
	If result.ok && ..AutoStart Job ##class(SignalNoir.Application.Benchmark.Runner).Drive(runId)
	Return result
}

/// Whether the run is development data (FreezeCheck), with the freeze it ran under and the inputs it saw
Method Judge(plan As %DynamicObject, catalog As %DynamicArray) [ Private ]
{
	Set data = ..Records()
	; the model is an input of an agent run only: a rules run has none, so it matches the freeze's
	Set model = $Select(plan.mode = "rules": data.freeze.%Get("model"), 1: plan.model)
	Set inputs = ##class(SignalNoir.Application.Benchmark.Inputs).Current(model, plan.policyVersion, plan.mappingVersion, catalog)
	Set verdict = ##class(SignalNoir.Core.Benchmark.FreezeCheck).Evaluate(data.freeze, inputs, data.roles, data.reviews, data.usage, {"purpose": (plan.purpose), "variants": (plan.variants)})
	Do plan.%Set("inputs", inputs)
	Do plan.%Set("freeze", data.freeze)
	Do plan.%Set("verdict", verdict)
}

/// The freeze record, roles, reviews and declarations of used sets
Method Records() As %DynamicObject
{
	If $IsObject(..Data) && ..Data.%IsDefined("freeze") Return ..Data
	Set D = "SignalNoir.Benchmark.Data."
	Return {"freeze": ($ClassMethod(D _ "Freeze", "Load", "Record")), "roles": ($ClassMethod(D _ "Roles", "Load", "Record")), "reviews": ($ClassMethod(D _ "Reviews", "Load", "Records")), "usage": ($ClassMethod(D _ "SetUsage", "Load", "Records"))}
}

/// Provider and model defaults for an agent run, and the pinned versions. Returns a
/// refusal (Result) or "".
Method Complete(plan As %DynamicObject) As SignalNoir.Core.Result [ Private ]
{
	If plan.mode = "agent" {
		If plan.provider = "" Do plan.%Set("provider", $System.Util.GetEnviron("SN_AI_PROVIDER"))
		If plan.model = "" Do plan.%Set("model", $System.Util.GetEnviron("SN_AI_MODEL"))
		If '##class(SignalNoir.Proposers.Factory).Ready("agent") Return ..Refuse("no AI provider is configured for an agent run")
	}
	Set policy = "", mapping = ""
	If plan.%GetTypeOf("fixtureSet") = "object" {
		If plan.fixtureSet.%GetTypeOf("policyVersion") = "string" Set policy = plan.fixtureSet.policyVersion
		If plan.fixtureSet.%GetTypeOf("mappingVersion") = "string" Set mapping = plan.fixtureSet.mappingVersion
	}
	Set snapshot = ##class(SignalNoir.Application.Reference.Store).For({"inRun": true, "policyVersion": (policy), "mappingVersion": (mapping)})
	If 'snapshot.ok Return ..Refuse(snapshot.message)
	Do plan.%Set("policyVersion", snapshot.obj.policyVersion)
	Do plan.%Set("mappingVersion", snapshot.obj.mappingVersion)
	Return ""
}

/// The run and its items in one transaction, then the start (created > running)
Method Persist(plan As %DynamicObject) As SignalNoir.Application.Model.BenchmarkRunRecord [ Private ]
{
	Set now = ..Clock.NowUtc()
	Set rec = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%New()
	Set rec.runId = ..Ids.New("run_")
	Set rec.mode = plan.mode, rec.purpose = plan.purpose, rec.provider = plan.provider, rec.model = plan.model
	Set rec.repetitions = plan.repetitions, rec.seed = plan.seed, rec.label = plan.label
	Set rec.policyVersion = plan.policyVersion, rec.mappingVersion = plan.mappingVersion
	Set rec.scenariosJson = plan.variants.%ToJSON()
	Set rec.casesPlanned = plan.variants.%Size() * plan.repetitions
	Set rec.development = plan.verdict.development
	Set rec.developmentReasonsJson = plan.verdict.reasons.%ToJSON()
	Set rec.freezeId = plan.freeze.%Get("freezeId")
	Set rec.freezeJson = plan.freeze.%ToJSON()
	Set rec.inputsDigestJson = plan.inputs.%ToJSON()
	Set rec.createdAt = now
	TSTART
	Try {
		$$$ThrowOnError(rec.%Save())
		Set no = 0
		For repetition = 1 : 1 : plan.repetitions {
			For i = 0 : 1 : plan.variants.%Size() - 1 {
				Set v = plan.variants.%Get(i)
				Set item = ##class(SignalNoir.Application.Model.BenchmarkItemRecord).%New()
				Set no = no + 1
				Set item.runId = rec.runId, item.itemNo = no
				Set item.family = v.family, item.subtype = v.subtype, item.variant = v.variant, item.set = v.set
				Set item.repetition = repetition
				Set item.seed = ##class(SignalNoir.Core.Benchmark.Seed).For(plan.seed, v.family, v.variant, repetition)
				$$$ThrowOnError(item.%Save())
			}
		}
		Set rec.status = ##class(SignalNoir.Core.Benchmark.RunPolicy).Next(rec.status, "start")
		Set rec.startedAt = now, rec.heartbeatAt = now
		$$$ThrowOnError(rec.%Save())
		TCOMMIT
	}
	Catch ex {
		TROLLBACK
		Throw ex
	}
	Return rec
}

/// Applies an event of the state machine to a stored run. Returns the new status, or ""
/// when the event is not allowed in the run's status.
Method Move(runId As %String, event As %String, reason As %String = "") As %String
{
	Set rec = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%OpenId(runId)
	If '$IsObject(rec) Return ""
	Set next = ##class(SignalNoir.Core.Benchmark.RunPolicy).Next(rec.status, event)
	If next = "" Return ""
	Set rec.status = next
	If (next = "completed") || (next = "failed") Set rec.completedAt = ..Clock.NowUtc()
	If next = "failed" Set rec.failureReason = reason
	$$$ThrowOnError(rec.%Save())
	Return next
}

Method Get(runId As %String) As SignalNoir.Core.Result
{
	Set rec = $Select(runId = "": "", 1: ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%OpenId(runId))
	If '$IsObject(rec) Return ##class(SignalNoir.Core.Result).Error("NOT_FOUND", "no such BenchmarkRun: " _ runId)
	Return ##class(SignalNoir.Core.Result).OkObj(..ToDto(rec))
}

/// Runs, newest first. status "" = all
Method List(status As %String = "", limit As %Integer = 20) As SignalNoir.Core.Result
{
	If (status '= "") && ((",created,running,completed,failed,") '[ ("," _ status _ ",")) Return ..Refuse("status must be created, running, completed or failed")
	If (limit < 1) || (limit > 100) || (limit '= (limit \ 1)) Return ..Refuse("limit must be an integer from 1 to 100")
	Set items = []
	; an empty string binds as NULL in SQL, so the unfiltered list is its own statement
	If status = "" {
		Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP ? runId FROM SignalNoir_Application_Model.BenchmarkRunRecord ORDER BY createdAt DESC, runId DESC", limit)
	} Else {
		Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP ? runId FROM SignalNoir_Application_Model.BenchmarkRunRecord WHERE status = ? ORDER BY createdAt DESC, runId DESC", limit, status)
	}
	While rs.%Next() {
		Do items.%Push(..ToDto(##class(SignalNoir.Application.Model.BenchmarkRunRecord).%OpenId(rs.%Get("runId"))))
	}
	Return ##class(SignalNoir.Core.Result).OkObj({"items": (items), "serverTime": (..Clock.NowUtc())})
}

/// The contract's BenchmarkRun, with the progress counted from the items
Method ToDto(rec As SignalNoir.Application.Model.BenchmarkRunRecord) As %DynamicObject
{
	Set dto = {"runId": (rec.runId), "mode": (rec.mode), "purpose": (rec.purpose), "status": (rec.status)}
	Do dto.%Set("provider", rec.provider, $Select(rec.provider = "": "null", 1: "string"))
	Do dto.%Set("model", rec.model, $Select(rec.model = "": "null", 1: "string"))
	Do dto.%Set("repetitions", rec.repetitions, "number")
	Do dto.%Set("seed", rec.seed, "number")
	Set dto.policyVersion = rec.policyVersion, dto.mappingVersion = rec.mappingVersion
	Do dto.%Set("scenarios", ..Selections(rec.scenariosJson))
	Set counts = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS planned, SUM(CASE WHEN status <> 'planned' THEN 1 ELSE 0 END) AS opened, SUM(CASE WHEN status IN ('ended','not_decided') THEN 1 ELSE 0 END) AS ended FROM SignalNoir_Application_Model.BenchmarkItemRecord WHERE runId = ?", rec.runId)
	Do counts.%Next()
	Do dto.%Set("progress", {"casesPlanned": (+counts.%Get("planned")), "casesOpened": (+counts.%Get("opened")), "casesTerminal": (+counts.%Get("ended"))})
	Set labels = {"synthetic": true}
	Do labels.%Set("replay", (rec.mode = "replay"), "boolean")
	Set dto.labels = labels
	If rec.label '= "" Set dto.label = rec.label
	Set dto.createdAt = rec.createdAt
	Do dto.%Set("startedAt", rec.startedAt, $Select(rec.startedAt = "": "null", 1: "string"))
	Do dto.%Set("completedAt", rec.completedAt, $Select(rec.completedAt = "": "null", 1: "string"))
	Do dto.%Set("failureReason", rec.failureReason, $Select(rec.failureReason = "": "null", 1: "string"))
	Do dto.%Set("development", rec.development, "boolean")
	Do dto.%Set("developmentReasons", $Select(rec.developmentReasonsJson = "": [], 1: [].%FromJSON(rec.developmentReasonsJson)))
	Do dto.%Set("freezeId", rec.freezeId, $Select(rec.freezeId = "": "null", 1: "string"))
	Set dto.serverTime = ..Clock.NowUtc()
	Return dto
}

/// The expanded variants grouped as the contract's ScenarioSelection list
ClassMethod Selections(variantsJson As %String) As %DynamicArray
{
	Set out = [], variants = [].%FromJSON(variantsJson), keys = ""
	For i = 0 : 1 : variants.%Size() - 1 {
		Set v = variants.%Get(i), key = v.family _ "|" _ v.set
		If '$Data(at(key)) {
			Do out.%Push({"family": (v.family), "variants": [], "set": (v.set)})
			Set at(key) = out.%Size() - 1
		}
		Do out.%Get(at(key)).variants.%Push(v.variant)
	}
	Return out
}

ClassMethod Refuse(message As %String) As SignalNoir.Core.Result [ Private ]
{
	Return ##class(SignalNoir.Core.Result).ErrorWith("VALIDATION_FAILED", message, {"errors": [(message)]})
}

}
