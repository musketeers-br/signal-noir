Class SignalNoir.Tests.Seam.TestFakesNotRuntime Extends %UnitTest.TestCase
{

/// T033 - Runtime-exclusion test: the test doubles must not ship in the
/// runtime resource of module signalnoir. module.xml reserves the runtime
/// SourcesRoot for src/ (Resource SignalNoir.PKG) and loads /tests only in the
/// test phase, so every fake lives exclusively under SignalNoir.Tests.*.
Method TestFakesExistOnlyInTheTestPackage()
{
	Set fakes = $ListBuild(
		"SignalNoir.Tests.Fakes.FakeCaseCommands",
		"SignalNoir.Tests.Fakes.FakeCaseQueries",
		"SignalNoir.Tests.Fakes.FakeValidator",
		"SignalNoir.Tests.Fakes.FakeProposer",
		"SignalNoir.Tests.Fakes.FakeTools",
		"SignalNoir.Tests.Fakes.FakePartnerClient",
		"SignalNoir.Tests.Fakes.FixedClock",
		"SignalNoir.Tests.Fakes.SeqIdGenerator"
	)
	For i = 1 : 1 : $ListLength(fakes) {
		Set name = $ListGet(fakes, i)
		Do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId(name), name _ " exists as a compiled class")
	}
	Set roots = $ListBuild(
		"SignalNoir.Core.",
		"SignalNoir.Application.",
		"SignalNoir.Api.",
		"SignalNoir.Interop.",
		"SignalNoir.Proposers."
	)
	For i = 1 : 1 : $ListLength(roots) {
		Set root = $ListGet(roots, i)
		Do $$$AssertTrue('(##class(%Dictionary.ClassDefinition).%ExistsId(root _ "FakeCaseCommands")), "no runtime fake under " _ root)
		Do $$$AssertTrue('(##class(%Dictionary.ClassDefinition).%ExistsId(root _ "FakeCaseQueries")), "no runtime fake under " _ root)
		Do $$$AssertTrue('(##class(%Dictionary.ClassDefinition).%ExistsId(root _ "FakeValidator")), "no runtime fake under " _ root)
		Do $$$AssertTrue('(##class(%Dictionary.ClassDefinition).%ExistsId(root _ "FakeProposer")), "no runtime fake under " _ root)
	}
}

/// Sanity companion: the genuine seam classes (production code) live under their
/// own roots and are resolvable, so the fakes are not shadowing them.
Method TestRuntimeClassesStillExist()
{
	Do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("SignalNoir.Core.CaseMachine"), "runtime seam class exists")
	Do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("SignalNoir.Application.CaseService"), "runtime service class exists")
	Do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("SignalNoir.Api.Dispatch"), "runtime API class exists")
	Do $$$AssertTrue(##class(%Dictionary.ClassDefinition).%ExistsId("SignalNoir.Interop.Bootstrap"), "runtime interop class exists")
}

}
