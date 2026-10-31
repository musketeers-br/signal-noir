Class SignalNoir.Application.PrecedentService Extends %RegisteredObject
{

/// Case precedents (feature 015): closed Cases kept as similarity records and
/// searched with IRIS vector search. Precedents are information for the
/// Operator, never Evidence and never a decision: nothing here is read by the
/// Validator, a proposer (unless the optional Agent block is on) or a
/// resolution. Indexing is a scan of terminal Cases without a record for the
/// configured model (research R2), so redelivery, failures, restarts and an
/// interrupted rebuild all resume by running it again.
Property Embedder As SignalNoir.Core.Port.Embedder;

Property Service As SignalNoir.Application.CaseService;

/// Results below it are not returned (FR-007)
Property MinSimilarity As %Numeric [ InitialExpression = 0.6 ];

Property DefaultK As %Integer [ InitialExpression = 5 ];

Property MaxK As %Integer [ InitialExpression = 10 ];

/// At most one search record per Case and requester in this window (FR-016)
Property RecordSeconds As %Integer [ InitialExpression = 60 ];

/// Replay Cases become precedents only when allowed (FR-004)
Property IncludeReplay As %Boolean [ InitialExpression = 0 ];

Parameter NOTICE = "Similarity search over earlier Cases. Not Evidence about this Case.";

Parameter TABLE = "SignalNoir_Application_Model.PrecedentRecord";

ClassMethod Default() As SignalNoir.Application.PrecedentService
{
	Set svc = ..%New()
	Set svc.Service = ##class(SignalNoir.Application.CaseService).Default()
	Set svc.Embedder = $Select(##class(SignalNoir.Precedents.ProviderEmbedder).Configured(): ##class(SignalNoir.Precedents.ProviderEmbedder).%New(), 1: ##class(SignalNoir.Precedents.LexicalEmbedder).%New())
	If ..Env("SN_PRECEDENTS_MIN_SIMILARITY") '= "" Set svc.MinSimilarity = +..Env("SN_PRECEDENTS_MIN_SIMILARITY")
	If ..Env("SN_PRECEDENTS_DEFAULT_K") '= "" Set svc.DefaultK = +..Env("SN_PRECEDENTS_DEFAULT_K")
	If ..Env("SN_PRECEDENTS_MAX_K") '= "" Set svc.MaxK = +..Env("SN_PRECEDENTS_MAX_K")
	If ..Env("SN_PRECEDENTS_RECORD_SECONDS") '= "" Set svc.RecordSeconds = +..Env("SN_PRECEDENTS_RECORD_SECONDS")
	Set svc.IncludeReplay = (..Env("SN_PRECEDENTS_INCLUDE_REPLAY") = "1")
	Return svc
}

/// The optional Agent precedents block (US6): off unless SN_PRECEDENTS_AGENT=1,
/// and it MUST stay off in the frozen reference run (FR-020)
ClassMethod AgentEnabled() As %Boolean
{
	Return (..Env("SN_PRECEDENTS_AGENT") = "1")
}

// ------------------------------------------------------------- indexing

/// Indexes up to max eligible closed Cases that have no record for the
/// configured model, oldest first. Result.ref = number indexed;
/// details: indexed, failed, reason (of the last failure).
Method IndexPending(max As %Integer = 50) As SignalNoir.Core.Result
{
	Set indexed = 0, failed = 0, reason = ""
	Set sql = "SELECT TOP " _ (+max) _ " c.caseId FROM SignalNoir_Application_Model.CaseRecord c WHERE c.state IN ('Resolved','ResolvedByPriorReceipt','Cancelled','Failed') AND (c.runId IS NULL OR c.runId = '')" _ $Select(..IncludeReplay: "", 1: " AND (c.replay IS NULL OR c.replay = 0)") _ " AND NOT EXISTS (SELECT 1 FROM " _ ..#TABLE _ " p WHERE p.caseId = c.caseId AND p.embeddingModel = ?) ORDER BY c.updatedAt, c.caseId"
	Set rs = ##class(%SQL.Statement).%ExecDirect(, sql, ..Embedder.Model())
	While rs.%Next() {
		Set r = ..IndexCase(rs.%Get("caseId"))
		If r.ok {
			Set indexed = indexed + (r.ref = "indexed")
		} Else {
			Set failed = failed + 1, reason = r.code _ ": " _ r.message
		}
	}
	Set state = ##class(SignalNoir.Application.Model.PrecedentIndexState).Current()
	If indexed Set state.lastIndexedAt = ..Now()
	If failed Set state.lastError = $Extract(reason, 1, 256)
	If indexed || failed Do state.%Save()
	Set result = ##class(SignalNoir.Core.Result).OkRef(indexed)
	Set result.details = {"indexed": (indexed), "failed": (failed), "reason": (reason)}
	Return result
}

/// One closed Case as a precedent of the configured model. Result.ref:
/// indexed, already, or not_eligible. A failed embedding is a value and
/// leaves the Case pending (FR-005).
Method IndexCase(caseId As %String) As SignalNoir.Core.Result
{
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId)
	If '$IsObject(rec) Return ##class(SignalNoir.Core.Result).Error("NOT_FOUND", "case not found: " _ caseId)
	If '..Eligible(rec) Return ##class(SignalNoir.Core.Result).OkRef("not_eligible")
	Set model = ..Embedder.Model()
	If ..Exists(caseId, model) Return ##class(SignalNoir.Core.Result).OkRef("already")
	Set facts = ..Facts(rec)
	Set built = ##class(SignalNoir.Core.PrecedentText).Build(facts)
	Set embedded = ..Embedder.Embed(built.text)
	If 'embedded.ok Return embedded
	Set sql = "INSERT INTO " _ ..#TABLE _ " (caseId, embeddingModel, orderId, partnerId, factsJson, description, rawText, mode, dimension, embedding, finalState, action, closedAt, durationSeconds, synthetic, replay, indexedAt) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, TO_VECTOR(?, DOUBLE, 1536), ?, ?, ?, ?, ?, ?, ?)"
	Set rs = ##class(%SQL.Statement).%ExecDirect(, sql, caseId, model, rec.orderId, rec.partnerId, facts.%ToJSON(), ..Describe(facts), built.text, embedded.details.mode, embedded.details.dimension, embedded.ref, rec.state, facts.action, rec.updatedAt, +facts.closeSeconds, +rec.synthetic, +rec.replay, ..Now())
	If rs.%SQLCODE < 0 {
		; a concurrent index of the same Case won the unique key (FR-001)
		If ..Exists(caseId, model) Return ##class(SignalNoir.Core.Result).OkRef("already")
		Return ##class(SignalNoir.Core.Result).Error("", "precedent insert failed: " _ rs.%SQLCODE)
	}
	Return ##class(SignalNoir.Core.Result).OkRef("indexed")
}

/// Terminal, not a Benchmark Case, not Replay unless allowed (FR-001, FR-004)
Method Eligible(rec As SignalNoir.Application.Model.CaseRecord) As %Boolean
{
	If '##class(SignalNoir.Core.Vocab).IsTerminal(rec.state) Return 0
	If rec.runId '= "" Return 0
	If rec.replay && '..IncludeReplay Return 0
	Return 1
}

/// The structured facts of a Case (research R4): codes only, from the Case,
/// the Order's exam codes, the first Exception, the current Proposal's
/// Action, the latest Dossier's reason code and the execution outcome. No
/// Evidence, no Order notes, no Operator or Agent text.
Method Facts(rec As SignalNoir.Application.Model.CaseRecord, query As %Boolean = 0) As %DynamicObject
{
	Set facts = {"partner": (rec.partnerId)}
	Set orderRec = ##class(SignalNoir.Application.Model.OrderRecord).%OpenId(rec.orderId)
	If $IsObject(orderRec) && (orderRec.snapshotJson '= "") {
		Try {
			Set snapshot = {}.%FromJSON(orderRec.snapshotJson)
			Set codes = []
			If $IsObject(snapshot.exams) {
				Set it = snapshot.exams.%GetIterator()
				While it.%GetNext(, .exam) {
					If $IsObject(exam) && (exam.code '= "") Do codes.%Push(exam.code)
				}
			}
			Set facts.examCodes = codes
		}
		Catch {
		}
	}
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 kind, httpStatus, responseClass FROM SignalNoir_Application_Model.ExceptionRecord WHERE caseId = ? ORDER BY observedAt, exceptionId", rec.caseId)
	If rs.%Next() {
		Set facts.exceptionKind = rs.%Get("kind")
		If rs.%Get("httpStatus") '= "" Set facts.httpStatus = rs.%Get("httpStatus")
		If rs.%Get("responseClass") '= "" Set facts.responseClass = rs.%Get("responseClass")
	}
	If query Return ..Clean(facts)
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 reason FROM SignalNoir_Application_Model.DossierRecord WHERE caseId = ? ORDER BY createdAt DESC", rec.caseId)
	If rs.%Next() && (rs.%Get("reason") '= "") Set facts.reviewReason = rs.%Get("reason")
	; the Action that settled it; a cancelled Case had none
	If (rec.state '= "Cancelled") && (rec.currentProposalId '= "") {
		Set pr = ##class(SignalNoir.Application.Model.ProposalRecord).%OpenId(rec.currentProposalId)
		If $IsObject(pr) {
			Set facts.action = pr.action
			If pr.paramsJson '= "" {
				Try {
					Set params = {}.%FromJSON(pr.paramsJson)
					If params.mappingId '= "" Set facts.mappingId = params.mappingId
				}
				Catch {
				}
			}
		}
	}
	If rec.executionOutcome '= "" Set facts.executionOutcome = rec.executionOutcome
	Set facts.finalState = rec.state
	Set policy = "SignalNoir.Core.ApprovalPolicy"
	If (rec.createdAt '= "") && (rec.updatedAt '= "") Set facts.closeSeconds = $ClassMethod(policy, "Seconds", rec.updatedAt) - $ClassMethod(policy, "Seconds", rec.createdAt)
	Return ..Clean(facts)
}

/// Drops every value that is not a code, so neither the stored facts nor the
/// display text can carry free text (FR-003, FR-015)
ClassMethod Clean(facts As %DynamicObject) As %DynamicObject
{
	Set out = {}
	Set it = facts.%GetIterator()
	While it.%GetNext(.key, .value) {
		If key = "examCodes" {
			Set codes = []
			Set ci = value.%GetIterator()
			While ci.%GetNext(, .code) {
				If ##class(SignalNoir.Core.PrecedentText).IsCode(code) Do codes.%Push(code)
			}
			Set out.examCodes = codes
		} ElseIf key = "closeSeconds" {
			Set out.closeSeconds = +value
		} ElseIf ##class(SignalNoir.Core.PrecedentText).IsCode(value) {
			Do out.%Set(key, value)
		}
	}
	Return out
}

/// The short display text of a precedent: how it failed and how it ended
ClassMethod Describe(facts As %DynamicObject) As %String
{
	Set failure = facts.exceptionKind
	If facts.httpStatus '= "" Set failure = failure _ " " _ facts.httpStatus
	If facts.responseClass '= "" Set failure = failure _ " (" _ facts.responseClass _ ")"
	Set exams = ""
	If $IsObject(facts.examCodes) {
		Set it = facts.examCodes.%GetIterator()
		While it.%GetNext(, .code) { Set exams = exams _ $Select(exams = "": "", 1: ", ") _ code }
	}
	Set text = $Select(failure = "": "Unknown failure", 1: failure) _ $Select(exams = "": "", 1: " on " _ exams)
	If facts.reviewReason '= "" Set text = text _ "; review: " _ facts.reviewReason
	Set text = text _ "; " _ $Select(facts.action '= "": facts.action _ " -> ", 1: "") _ facts.finalState
	If facts.executionOutcome '= "" Set text = text _ " (" _ facts.executionOutcome _ ")"
	Return $Extract(text, 1, 600)
}

// ------------------------------------------------------------ searching

/// Up to k precedents of a Case, never the Case itself (FR-006 to FR-011).
/// requester: console or agent. A search failure is a value in
/// details.status, so the Case always opens. Result.details is the contract
/// PrecedentSearch.
Method Search(caseId As %String, k As %String = "", requester As %String = "console") As SignalNoir.Core.Result
{
	If k = "" Set k = ..DefaultK
	If (k '= +k) || (k \ 1 '= k) || (k < 1) || (k > ..MaxK) Return ##class(SignalNoir.Core.Result).ErrorWith("VALIDATION_FAILED", "k must be an integer from 1 to " _ ..MaxK, {"reasons": ["invalid:k"]})
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId)
	If '$IsObject(rec) Return ##class(SignalNoir.Core.Result).Error("NOT_FOUND", "case not found: " _ caseId)
	Set started = $ZHorolog
	Set model = ..Embedder.Model()
	Set answer = {"caseId": (caseId), "status": "", "mode": (..Embedder.Mode()), "model": (model), "dimension": (..Embedder.#DIMENSION), "k": (+k), "minSimilarity": (+..MinSimilarity), "items": [], "recorded": false, "notice": (..#NOTICE)}
	Set state = ##class(SignalNoir.Application.Model.PrecedentIndexState).Current()
	Set configured = ..Count("embeddingModel = ?", model), other = ..Count("embeddingModel <> ?", model)
	Set embedError = 0, reason = ""
	If 'state.rebuilding && (configured > 0) {
		Set built = ##class(SignalNoir.Core.PrecedentText).Build(..Facts(rec, 1), 1)
		Set embedded = ..Embedder.Embed(built.text)
		If 'embedded.ok {
			Set embedError = 1, reason = $Select(embedded.code = "unsupported_dimension": "unsupported_dimension", 1: "provider_unavailable")
		} Else {
			Set found = ..Nearest(embedded.ref, model, caseId, k, .sqlError)
			If sqlError Set embedError = 1, reason = "index_error"
		}
	}
	Set matches = $Select($IsObject($Get(found)): found.%Size(), 1: 0)
	Set status = ##class(SignalNoir.Core.PrecedentStatus).Decide(state.rebuilding, embedError, configured, other, matches)
	Set answer.status = status
	If status = "results" Set answer.items = found
	If status = "needs_rebuild" Set reason = "model_changed"
	If reason '= "" Set answer.reason = reason
	Set durationMs = ($ZHorolog - started) * 1000 \ 1
	Set ids = []
	Set it = answer.items.%GetIterator()
	While it.%GetNext(, .item) { Do ids.%Push(item.caseId) }
	Do answer.%Set("recorded", ..Record(caseId, requester, {"kind": "precedent_search", "requester": (requester), "status": (status), "mode": (answer.mode), "model": (model), "count": (ids.%Size()), "precedentCaseIds": (ids), "durationMs": (durationMs), "reason": (reason)}), "boolean")
	Set result = ##class(SignalNoir.Core.Result).OkRef(caseId)
	Set result.details = answer
	Return result
}

/// Nearest records of the model by cosine, then by recency; at or above the
/// minimum. Over-fetches so a post-filtered candidate list still fills k.
Method Nearest(vector As %String, model As %String, caseId As %String, k As %Integer, Output sqlError As %Boolean) As %DynamicArray [ Private ]
{
	Set sqlError = 0, out = []
	Set sql = "SELECT TOP " _ (k * 4) _ " caseId, orderId, partnerId, description, action, finalState, closedAt, durationSeconds, synthetic, replay, VECTOR_COSINE(embedding, TO_VECTOR(?, DOUBLE, 1536)) AS similarity FROM " _ ..#TABLE _ " WHERE embeddingModel = ? AND caseId <> ? ORDER BY similarity DESC, closedAt DESC"
	Set rs = ##class(%SQL.Statement).%ExecDirect(, sql, vector, model, caseId)
	If rs.%SQLCODE < 0 {
		Set sqlError = 1
		Return out
	}
	While rs.%Next() && (out.%Size() < k) {
		Set sim = +rs.%Get("similarity")
		If sim < ..MinSimilarity Quit
		Set item = {"caseId": (rs.%Get("caseId")), "orderId": (rs.%Get("orderId")), "partnerId": (rs.%Get("partnerId")), "description": (rs.%Get("description")), "action": (rs.%Get("action")), "finalState": (rs.%Get("finalState")), "closedAt": (rs.%Get("closedAt")), "durationSeconds": (+rs.%Get("durationSeconds")), "similarity": ($Normalize(sim, 4)), "synthetic": (''rs.%Get("synthetic")), "replay": (''rs.%Get("replay"))}
		Do item.%Set("synthetic", ''rs.%Get("synthetic"), "boolean")
		Do item.%Set("replay", ''rs.%Get("replay"), "boolean")
		If item.action = "" Do item.%Set("action", "", "null")
		Do out.%Push(item)
	}
	Return out
}

/// Appends the search record (Timeline Annotation, FR-016), at most once per
/// Case and requester per window; a busy Case skips it. Returns whether it
/// was recorded. Never fails the search.
Method Record(caseId As %String, requester As %String, payload As %DynamicObject) As %Boolean
{
	Set now = ##class(SignalNoir.Core.ApprovalPolicy).Seconds(..Now())
	Set last = $Get(^SignalNoir.PrecedentSeen(caseId, requester))
	If (last '= "") && ((now - last) < ..RecordSeconds) Return 0
	Set event = ##class(SignalNoir.Core.Dto.TimelineEvent).%New()
	Set event.type = "Annotation"
	Set event.actor = $Select(requester = "agent": "agent", 1: "system")
	Set event.refId = caseId
	Set event.payload = payload
	Set r = ..Service.Append(caseId, event)
	If 'r.ok Return 0
	Set ^SignalNoir.PrecedentSeen(caseId, requester) = now
	Return 1
}

// ------------------------------------------------------------- rebuild

/// Rebuilds every precedent for the configured model (FR-019): marks the
/// index as rebuilding, indexes every eligible Case missing for this model,
/// removes records of other models and clears the mark. Interrupted, the
/// next call resumes without duplicates. Result.details: indexed, failed,
/// removed, total.
Method Rebuild(batch As %Integer = 200) As SignalNoir.Core.Result
{
	Set state = ##class(SignalNoir.Application.Model.PrecedentIndexState).Current()
	Set state.rebuilding = 1, state.rebuildStartedAt = ..Now()
	Do state.%Save()
	Set indexed = 0, failed = 0
	For {
		Set r = ..IndexPending(batch)
		Set indexed = indexed + r.details.indexed, failed = failed + r.details.failed
		Quit:(r.details.indexed = 0)
	}
	If failed {
		; leave the mark: searches keep saying rebuilding until it completes
		Return ##class(SignalNoir.Core.Result).ErrorWith("provider_unavailable", "rebuild incomplete: " _ r.details.reason, {"indexed": (indexed), "failed": (failed)})
	}
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM " _ ..#TABLE _ " WHERE embeddingModel <> ?", ..Embedder.Model())
	Set removed = rs.%ROWCOUNT
	Set state = ##class(SignalNoir.Application.Model.PrecedentIndexState).Current()
	Set state.rebuilding = 0, state.rebuildStartedAt = "", state.lastError = ""
	Do state.%Save()
	Set result = ##class(SignalNoir.Core.Result).OkRef(indexed)
	Set result.details = {"indexed": (indexed), "failed": 0, "removed": (removed), "total": (..Count("embeddingModel = ?", ..Embedder.Model()))}
	Return result
}

// --------------------------------------------------------------- helpers

Method Exists(caseId As %String, model As %String) As %Boolean [ Private ]
{
	Return ##class(SignalNoir.Application.Model.PrecedentRecord).precedentKeyExists(caseId, model)
}

Method Count(where As %String, arg As %String) As %Integer [ Private ]
{
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS n FROM " _ ..#TABLE _ " WHERE " _ where, arg)
	Return $Select(rs.%Next(): +rs.%Get("n"), 1: 0)
}

Method Now() As %String [ Private ]
{
	Return ..Service.Clock.NowUtc()
}

ClassMethod Env(name As %String) As %String [ Private ]
{
	Return $System.Util.GetEnviron(name)
}

}
