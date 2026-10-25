Class SignalNoir.Interop.Bootstrap Extends %RegisteredObject
{

/// Idempotent startup (D6, D7): read the provider settings from the runtime
/// environment, materialize the AI Hub provider configuration, record the
/// availability the health surface reports, verify the lease budget and
/// register the web applications.
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
	Try {
		Set previousNamespace = $NAMESPACE
		Set $NAMESPACE = "%SYS"
		Kill props
		Set props("DispatchClass") = "SignalNoir.Api.Dispatch"
		; 2 = CSP/REST application (18 is refused on 2026.2: MAXVAL 9)
		Set props("Type") = 2
		Set props("NameSpace") = previousNamespace
		Set props("Name") = "Signal Noir API"
		Set props("AutheEnabled") = 64
		Set props("MatchRoles") = ":%All"
		Set sc = ##class(Security.Applications).Delete("/signalnoir/api/v1")
		Set sc = ##class(Security.Applications).Create("/signalnoir/api/v1", .props)
		If $$$ISOK(sc) {
			Set status = "registered"
		} Else {
			Set status = "failed"
		}
		Set $NAMESPACE = previousNamespace
	}
	Catch ex {
		Set status = "failed"
	}
	Return status
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
