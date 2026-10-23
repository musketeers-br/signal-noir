Class SignalNoir.Core.Vocab Extends %RegisteredObject
{

/// Closed state vocabulary (frozen, data-model.md section States)
Parameter STATES = "Open,Investigating,DecisionProposed,PendingApproval,Approved,Rejected,Executing,Held,ReviewRequired,Resolved,ResolvedByPriorReceipt,Cancelled,Failed";

/// Closed action catalog (Constitution II)
Parameter ACTIONS = "RETRY,APPLY_APPROVED_MAPPING,HOLD,REQUEST_REVIEW";

/// Actor vocabulary; operator actors carry the operator:<name> shape
Parameter ACTORS = "system,sweeper,benchmark,agent";

/// Closed command vocabulary (outbox types)
Parameter COMMANDS = "Investigate,Execute,Reconcile,Expire,Reassess,Resume";

/// Closed error-code vocabulary taken from the frozen OpenAPI (ErrorCode enum);
/// the seam MUST NOT invent new codes
Parameter ERRORCODES = "STALE_VERSION,INVALID_TRANSITION,INVALID_ACTOR,VALIDATION_FAILED,NOT_FOUND";

/// Precondition checks (declared now, evaluated in later slices)
Parameter PRECONDITIONS = "PARTNER_HEALTHY_WINDOW,ORDER_ACTIVE_AT_ORIGIN,APPROVAL_VALID,POLICY_VERSION_UNCHANGED,MAPPING_VERSION_UNCHANGED";

/// Terminal states (no implicit reopen)
Parameter TERMINALSTATES = "Resolved,ResolvedByPriorReceipt,Cancelled,Failed";

/// ID prefixes (seam conventions)
Parameter IDPREFIXES = "case_,prop_,appr_,exec_,evid_,cmd_,run_";

ClassMethod States() As %ListOfDataTypes
{
	Return $ListFromString(..#STATES, ",")
}

ClassMethod Actions() As %ListOfDataTypes
{
	Return $ListFromString(..#ACTIONS, ",")
}

ClassMethod Actors() As %ListOfDataTypes
{
	Return $ListFromString(..#ACTORS, ",")
}

ClassMethod Commands() As %ListOfDataTypes
{
	Return $ListFromString(..#COMMANDS, ",")
}

ClassMethod ErrorCodes() As %ListOfDataTypes
{
	Return $ListFromString(..#ERRORCODES, ",")
}

ClassMethod Preconditions() As %ListOfDataTypes
{
	Return $ListFromString(..#PRECONDITIONS, ",")
}

ClassMethod TerminalStates() As %ListOfDataTypes
{
	Return $ListFromString(..#TERMINALSTATES, ",")
}

ClassMethod IdPrefixes() As %ListOfDataTypes
{
	Return $ListFromString(..#IDPREFIXES, ",")
}

ClassMethod IsState(state As %String) As %Boolean
{
	If state = "" Return 0
	Return ($ListFind($ListFromString(..#STATES, ","), state) > 0)
}

ClassMethod IsAction(action As %String) As %Boolean
{
	Return ($ListFind($ListFromString(..#ACTIONS, ","), action) > 0)
}

ClassMethod IsCommand(command As %String) As %Boolean
{
	Return ($ListFind($ListFromString(..#COMMANDS, ","), command) > 0)
}

ClassMethod IsErrorCode(code As %String) As %Boolean
{
	Return ($ListFind($ListFromString(..#ERRORCODES, ","), code) > 0)
}

ClassMethod IsIdPrefix(prefix As %String) As %Boolean
{
	Return ($ListFind($ListFromString(..#IDPREFIXES, ","), prefix) > 0)
}

/// An actor is one of the fixed actors or operator:<name> with a non-empty name
ClassMethod IsActor(actor As %String) As %Boolean
{
	If actor = "" Return 0
	If $ListFind($ListFromString(..#ACTORS, ","), actor) > 0 Return 1
	If $Extract(actor, 1, 9) = "operator:" Return ($Length(actor) > 9)
	Return 0
}

ClassMethod IsTerminal(state As %String) As %Boolean
{
	Return ($ListFind($ListFromString(..#TERMINALSTATES, ","), state) > 0)
}

}
