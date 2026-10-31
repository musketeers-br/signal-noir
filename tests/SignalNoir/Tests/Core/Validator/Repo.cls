Class SignalNoir.Tests.Core.Validator.Repo Extends %RegisteredObject
{

/// Test-only. Where the repository is mounted for the process that runs the tests: CI mounts it at
/// /repo (tests/ci/core-tests.script), the dev container at /home/irisowner/dev. The tests that
/// read files of the repository (the contract tables, the fixtures) ask here instead of
/// writing one of the two paths.
ClassMethod Root() As %String
{
	For root = "/repo/", "/home/irisowner/dev/" {
		If ##class(%File).Exists(root _ "contracts/fixtures/manifest.json") Return root
	}
	Return "/home/irisowner/dev/"
}

/// The full path of a file given relative to the repository root
ClassMethod Path(relative As %String) As %String
{
	Return ..Root() _ relative
}

}
