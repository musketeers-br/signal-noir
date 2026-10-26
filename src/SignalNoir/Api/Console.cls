Class SignalNoir.Api.Console Extends %CSP.REST
{

/// /signalnoir: the console's entry point (feature 005). A static IRIS web
/// application does not serve its empty path (404 on this build, 005
/// research R3), so /signalnoir/ redirects to the static console at
/// /signalnoir/ui/. The API keeps its own application at /signalnoir/api/v1.
XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/" Method="GET" Call="Entry"/>
</Routes>
}

ClassMethod Entry() As %Status
{
	Set %response.Status = "302 Found"
	Do %response.SetHeader("Location", ..Target())
	Return $$$OK
}

/// The console path, relative to /signalnoir/
ClassMethod Target() As %String
{
	Return "ui/index.html#/cases"
}

}
