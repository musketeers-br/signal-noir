Class SignalNoir.Interop.Bootstrap Extends %RegisteredObject
{

/// Idempotent startup (D6, D7): read the provider settings from the runtime
/// environment, materialize the AI Hub provider configuration, record the
/// availability the health surface reports, verify the lease budget,
/// register the web applications and, when SN_BACKGROUND_TASKS is 1,
/// schedule the sweeper and the Origin feed. The Simulator's application is
/// registered by the start-up hook, outside the product (002 research D10).
/// OnStart never throws and never logs the API key: the key is only passed
/// to the platform calls that need it.
/// Configuration name of the AI Hub provider configuration
Parameter CONFIGNAME = "SignalNoir";

/// Secret reference name used inside the ConfigStore details
Parameter SECRETLINK = "secret://SignalNoir.AIKey";

/// Default lease: must stay greater than partner timeout + investigation budget
Parameter LEASESECONDS = 300;

Parameter PARTNERTIMEOUTSECONDS = 60;

Parameter INVESTIGATIONBUDGETSECONDS = 120;

ClassMethod OnStart() As SignalNoir.Core.Result
{
	Set result = ##class(SignalNoir.Core.Result).Error("", "bootstrap did not run")
	Try {
		Set provider = ##class(SignalNoir.Interop.Bootstrap).Env("SN_AI_PROVIDER")
		Set model = ##class(SignalNoir.Interop.Bootstrap).Env("SN_AI_MODEL")
		Set key = ##class(SignalNoir.Interop.Bootstrap).Env("SN_AI_API_KEY")
		Set lease = ##class(SignalNoir.Interop.Bootstrap).EnvSeconds("SN_AI_LEASE_SECONDS", ..#LEASESECONDS)
		Set partnerTimeout = ##class(SignalNoir.Interop.Bootstrap).EnvSeconds("SN_PARTNER_TIMEOUT_SECONDS", ..#PARTNERTIMEOUTSECONDS)
		Set budget = ##class(SignalNoir.Interop.Bootstrap).EnvSeconds("SN_INVESTIGATION_BUDGET_SECONDS", ..#INVESTIGATIONBUDGETSECONDS)
		Set configured = ((provider '= "") && (model '= "") && (key '= ""))
		Set reason = ""
		If 'configured {
			Set reason = ##class(SignalNoir.Interop.Bootstrap).UnavailableReason(provider, key)
		}
		Set materialized = "none"
		If configured {
			Set materialized = ##class(SignalNoir.Interop.Bootstrap).Materialize(provider, model, key)
		}
		Set timeoutOk = (lease > (partnerTimeout + budget))
		If 'timeoutOk {
			Set reason = "lease " _ lease _ "s must be greater than partner timeout " _ partnerTimeout _ "s plus investigation budget " _ budget _ "s"
		}
		Set ^SignalNoir.Provider("provider") = provider
		Set ^SignalNoir.Provider("model") = model
		Set ^SignalNoir.Provider("configured") = configured
		Set ^SignalNoir.Provider("reason") = reason
		Set ^SignalNoir.Provider("materialized") = materialized
		Set ^SignalNoir.Provider("leaseSeconds") = lease
		Set ^SignalNoir.Provider("partnerTimeoutSeconds") = partnerTimeout
		Set ^SignalNoir.Provider("investigationBudgetSeconds") = budget
		Set ^SignalNoir.Provider("timeoutCheck") = $SELECT(timeoutOk: "ok", 1: "violation")
		Set ^SignalNoir.Provider("bootstrappedAt") = ##class(SignalNoir.Application.SystemClock).%New().NowUtc()
		Set webStatus = ##class(SignalNoir.Interop.Bootstrap).EnsureWebApplications()
		Set interopStatus = ##class(SignalNoir.Interop.Bootstrap).EnsureInterop()
		Set ^SignalNoir.Provider("webApplications") = webStatus
		Set ^SignalNoir.Provider("interop") = interopStatus
		; gate G1: the periodic work of a clean database
		Set ^SignalNoir.Provider("backgroundTasks") = ##class(SignalNoir.Interop.Bootstrap).EnsureBackgroundTasks(##class(SignalNoir.Interop.Bootstrap).Env("SN_BACKGROUND_TASKS") = "1")
		; 003 FR-027: an investigation interrupted by the restart goes to review
		Set recovered = ##class(SignalNoir.Application.CaseService).Default().RecoverInterrupted()
		Set ^SignalNoir.Provider("recoveredCases") = $Select(recovered.ok: recovered.ref, 1: "failed: " _ recovered.message)
		Set result = ##class(SignalNoir.Core.Result).OkRef("bootstrap")
	}
	Catch ex {
		Set result = ##class(SignalNoir.Core.Result).Error("", "bootstrap failed: " _ ex.DisplayString())
	}
	Return result
}

/// Materializes the provider configuration in the AI Hub: the ConfigStore
/// path first, the direct provider creation as fallback. Returns which path
/// was taken; the key is never written to a global or a log.
ClassMethod Materialize(provider As %String, model As %String, key As %String) As %String
{
	Set outcome = "none"
	Try {
		Set details = ##class(%DynamicObject).%New()
		Do details.%Set("model_provider", provider)
		Do details.%Set("model", model)
		Do details.%Set("api_key", ..#SECRETLINK)
		If ##class(SignalNoir.Interop.Bootstrap).EnsureSecret(key) {
			Set outcome = "configstore"
		} Else {
			Do details.%Set("api_key", key)
		}
		Set sc = ##class(SignalNoir.Interop.Bootstrap).StoreConfiguration(details)
		If $$$ISOK(sc) {
			Set sc = ##class(%ConfigStore.DescriptorManager).RebuildRegistry()
			If $$$ISOK(sc) {
				Return outcome
			}
		}
	}
	Catch ex {
		Set outcome = "none"
	}
	Try {
		Set settings = ##class(%DynamicObject).%New()
		Do settings.%Set("api_key", key)
		Do settings.%Set("model", model)
		Set p = ##class(%AI.Provider).Create(provider, settings)
		If $IsObject(p) Return "provider"
	}
	Catch ex {
	}
	Return "none"
}

ClassMethod StoreConfiguration(details As %DynamicObject) As %Status
{
	Set fqn = ##class(SignalNoir.Interop.Bootstrap).ConfigFQN()
	If ##class(%ConfigStore.Configuration).Exists(fqn) {
		Set sc = ##class(%ConfigStore.Configuration).Get(fqn, .config)
		If $$$ISOK(sc) {
			Set config.Details = details
			Return config.%Save()
		}
		Return sc
	}
	Return ##class(%ConfigStore.Configuration).Create("AI", "LLM", "", ..#CONFIGNAME, details, "Signal Noir provider", "AI Hub provider for Signal Noir")
}

ClassMethod ConfigFQN() As %String
{
	Return "AI.LLM." _ ..#CONFIGNAME
}

/// Stores the key in the platform wallet so the ConfigStore keeps only a
/// reference to it. Returns 0 when the wallet refuses the secret.
ClassMethod EnsureSecret(key As %String) As %Boolean
{
	Try {
		Set props = ##class(%DynamicObject).%New()
		Set secret = ##class(%DynamicObject).%New()
		Do secret.%Set("api_key", key)
		Do props.%Set("Secret", secret)
		Do props.%Set("Resource", "%Admin_Wallet")
		Do props.%Set("Usage", "CUSTOM")
		Do props.%Set("RequireTLS", 0)
		Set sc = ##class(%Wallet.KeyValue).Create("SignalNoir.AIKey", props)
		If $$$ISOK(sc) Return 1
		Set sc = ##class(%Wallet.KeyValue).UpdateSecret("SignalNoir.AIKey", secret)
		If $$$ISOK(sc) Return 1
	}
	Catch ex {
	}
	Return 0
}

/// Registers the product API and the health route. Idempotent: the existing
/// application is replaced with the same definition.
ClassMethod EnsureWebApplications() As %String
{
	Set status = "unknown"
	Set ns = $NAMESPACE
	; everything about the application is computed here: in %SYS the
	; SignalNoir classes are not visible
	Set apps = 3
	; the product API (2 = CSP/REST application; 18 is refused on 2026.2: MAXVAL 9)
	Set apps(1) = "/signalnoir/api/v1", apps(1, "DispatchClass") = "SignalNoir.Api.Dispatch", apps(1, "Name") = "Signal Noir API"
	; the operator console: static files (feature 005) and the entry redirect
	Set apps(2) = "/signalnoir/ui", apps(2, "Path") = ##class(SignalNoir.Interop.Bootstrap).UiPath(), apps(2, "ServeFiles") = 1, apps(2, "Name") = "Signal Noir console"
	Set apps(3) = "/signalnoir", apps(3, "DispatchClass") = "SignalNoir.Api.Console", apps(3, "Name") = "Signal Noir entry"
	Try {
		Set $NAMESPACE = "%SYS"
		Set ok = 1
		For i = 1 : 1 : apps {
			Kill props
			Merge props = apps(i)
			Set props("Type") = 2
			Set props("NameSpace") = ns
			Set props("AutheEnabled") = 64
			Set props("MatchRoles") = ":%All"
			If ##class(Security.Applications).Exists(apps(i)) Do ##class(Security.Applications).Delete(apps(i))
			Set ok = ok && $$$ISOK(##class(Security.Applications).Create(apps(i), .props))
		}
		Set status = $Select(ok: "registered", 1: "failed")
	}
	Catch ex {
		Set status = "failed"
	}
	Set $NAMESPACE = ns
	Return status
}

/// The scheduled tasks of the product: the sweeper, the Origin feed reader and (feature
/// 010) the one that drives again a BenchmarkRun whose driver stopped
ClassMethod TaskClasses() As %String
{
	Return "SignalNoir.Tasks.SweeperTask,SignalNoir.Tasks.OriginFeedTask,SignalNoir.Tasks.BenchmarkTask"
}

/// Schedules the sweeper and the Origin feed reader, or removes them. Off
/// by default: the dev database holds test requests that the sweeper would
/// redeliver (007 research R6). Returns "scheduled", "off" or "failed".
ClassMethod EnsureBackgroundTasks(enabled As %Boolean) As %String
{
	Set ok = 1
	Set classes = ..TaskClasses()
	For i = 1 : 1 : $Length(classes, ",") {
		Set cls = $Piece(classes, ",", i)
		Set sc = $Select(enabled: $ClassMethod(cls, "Ensure"), 1: $ClassMethod(cls, "Remove"))
		Set ok = ok && $$$ISOK(sc)
	}
	If 'ok Return "failed"
	Return $Select(enabled: "scheduled", 1: "off")
}

/// Directory with the built console (ui/build); SN_UI_PATH overrides the
/// dev-container default
ClassMethod UiPath() As %String
{
	Set path = ##class(SignalNoir.Interop.Bootstrap).Env("SN_UI_PATH")
	If path = "" Set path = "/home/irisowner/dev/ui/build/"
	If $Extract(path, *) '= "/" Set path = path _ "/"
	Return path
}


/// Ensures the namespace has Interop enabled, which the Production needs.
ClassMethod EnsureInterop() As %String
{
	Set status = "unknown"
	Try {
		Set ns = ##class(Config.Namespaces).Get($NAMESPACE)
		If $IsObject(ns) {
			If ns.Interop '= 1 {
				Set ns.Interop = 1
				Set sc = ns.%Save()
				If $$$ISOK(sc) {
					Set status = "enabled"
				} Else {
					Set status = "failed"
				}
			} Else {
				Set status = "already enabled"
			}
		} Else {
			Set status = "namespace not found"
		}
	}
	Catch ex {
		Set status = "failed"
	}
	Return status
}

/// The reason names the provider that is not available.
ClassMethod UnavailableReason(provider As %String, key As %String) As %String
{
	Set name = provider
	If name = "" Set name = "unknown-provider"
	If key = "" {
		Return "provider unavailable: " _ name _ " (no API key configured)"
	}
	Return "provider unavailable: " _ name _ " (provider or model not configured)"
}

ClassMethod Env(name As %String) As %String
{
	Try {
		Return $SYSTEM.Util.GetEnviron(name)
	}
	Catch ex {
		Return ""
	}
}

ClassMethod EnvSeconds(name As %String, defaultValue As %Integer) As %Integer
{
	Set raw = ##class(SignalNoir.Interop.Bootstrap).Env(name)
	If raw = "" Return defaultValue
	If +raw '= raw Return defaultValue
	Set value = +raw
	If value <= 0 Return defaultValue
	Return value
}

}
