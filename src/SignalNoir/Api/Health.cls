Class SignalNoir.Api.Health Extends %CSP.REST
{

/// Operational health surface (contract change 001).
/// Liveness, readiness and provider availability are distinct:
/// liveness=alive whenever the process answers, status=ready when the
/// provider is configured and degraded when it is not. A missing key is a
/// reported value, never an error: this endpoint never returns 5xx for it.
XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/health" Method="GET" Call="Health"/>
</Routes>
}

ClassMethod Health() As %Status
{
	Set %response.ContentType = "application/json"
	Write ##class(SignalNoir.Api.Health).Payload().%ToJSON()
	Return $$$OK
}

/// The health payload exactly as the frozen contract requires.
ClassMethod Payload() As %DynamicObject
{
	Set payload = ##class(%DynamicObject).%New()
	Do payload.%Set("status", ##class(SignalNoir.Api.Health).StatusValue())
	Do payload.%Set("liveness", "alive")
	Set provider = ##class(%DynamicObject).%New()
	Set configured = +$Get(^SignalNoir.Provider("configured"))
	Do provider.%Set("configured", configured)
	If configured = 0 {
		Do provider.%Set("reason", ##class(SignalNoir.Api.Health).ProviderReason())
	}
	Do payload.%Set("provider", provider)
	Do payload.%Set("serverTime", ##class(SignalNoir.Application.SystemClock).%New().NowUtc())
	Return payload
}

/// ready when the provider is configured, degraded otherwise
ClassMethod StatusValue() As %String
{
	If +$Get(^SignalNoir.Provider("configured")) = 1 Return "ready"
	Return "degraded"
}

/// The reason names the unavailable provider.
ClassMethod ProviderReason() As %String
{
	Set reason = $Get(^SignalNoir.Provider("reason"))
	If reason = "" Set reason = "provider unavailable: " _ $Get(^SignalNoir.Provider("provider"), "unknown-provider")
	Return reason
}

}
