Class SignalNoir.Tests.Proposers.TestDecisionsHttp Extends %UnitTest.TestCase
{

/// 013 - the Decisions transport in Embedded Python (httpx, shipped with build
/// 154). No call reaches OpenAI: the request is built and inspected, and the
/// failure path goes to a port where nothing listens. Not in the Core suite,
/// because the public IRIS image of CI may lack httpx.
/// The request leaves as UTF-8 (a Latin-1 "código" made the API answer 400)
Method TestRequestIsUtf8()
{
	Set json = {"note": ("use o c" _ $Char(243) _ "digo")}.%ToJSON()
	Set request = ##class(SignalNoir.Proposers.DecisionsHttp).Request("https://example.invalid/v1/decisions", "sk-test", json)
	Set bytes = request.content
	Do $$$AssertTrue(bytes [ ("c" _ $Char(195, 179) _ "digo"), "ó is the UTF-8 pair C3 B3")
	Do $$$AssertEquals($ZConvert(bytes, "I", "UTF8"), json, "round trip")
	Do $$$AssertEquals(request.method, "POST", "POST")
	Do $$$AssertEquals(request.headers."__getitem__"("content-type"), "application/json; charset=utf-8", "JSON in UTF-8")
}

/// The key goes only in the Authorization header, never in the URL or body
Method TestKeyOnlyInHeader()
{
	Set request = ##class(SignalNoir.Proposers.DecisionsHttp).Request("https://example.invalid/v1/decisions", "sk-secret-123", "{}")
	Do $$$AssertEquals(request.headers."__getitem__"("authorization"), "Bearer sk-secret-123", "bearer header")
	Do $$$AssertNotTrue(request.url."__str__"() [ "sk-secret", "not in the URL")
	Do $$$AssertNotTrue(request.content [ "sk-secret", "not in the body")
}

/// A transport failure comes back as the exception's name only
Method TestFailureKeepsOnlyTheName()
{
	Set out = {}.%FromJSON(##class(SignalNoir.Proposers.DecisionsHttp).Post("https://127.0.0.1:1/v1/decisions", "sk-secret-123", "{}", 2))
	Do $$$AssertEquals(out.error, "ConnectError", "the exception's class name")
	Do $$$AssertNotTrue(out.%ToJSON() [ "sk-secret", "the key never comes back")
	Do $$$AssertEquals(out.status, "", "no status")
}

}
