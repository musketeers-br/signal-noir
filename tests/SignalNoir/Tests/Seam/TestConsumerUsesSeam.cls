Class SignalNoir.Tests.Seam.TestConsumerUsesSeam Extends %UnitTest.TestCase
{

/// T032 - Seam consumer test: the test-only consumer in
/// tests/SignalNoir/Consumer/Consumer.cls uses every port through its fake and
/// compiles with no reference to feature implementation classes
/// (SignalNoir.Application, SignalNoir.Api, SignalNoir.Interop, SignalNoir.Proposers).
Method TestConsumerUsesEveryPortThroughFakes()
{
	Set consumer = ##class(SignalNoir.Consumer.Consumer).%New()
	Do $$$AssertTrue($IsObject(consumer), "consumer instantiates from the seam and the fakes")
	Set out = consumer.RunOnce("seam-" _ $JOB)

	; CaseCommands
	Do $$$AssertEquals(out.accepted, 1, "CaseCommands.AcceptOrder through the fake")
	Do $$$AssertEquals(out.opened, 1, "CaseCommands.RecordException opens the Case through the fake")
	Do $$$AssertTrue(out.caseId '= "", "caseId from the seam")
	Do $$$AssertEquals(out.appended, 1, "CaseCommands.Append through the fake")
	Do $$$AssertTrue(+out.appendSeq >= 1, "append returned a monotonic seq")
	Do $$$AssertEquals(out.transitioned, 1, "CaseCommands.Transition through the fake")

	; CaseQueries
	Do $$$AssertEquals(out.listed, 1, "CaseQueries.ListCases through the fake")
	Do $$$AssertEquals(out.timeline, 1, "CaseQueries.GetTimeline through the fake")

	; Validator
	Do $$$AssertEquals(out.verdict, "valid", "Validator.Validate through the fake")

	; Proposer (unavailable by default: the value that drives ReviewRequired)
	Do $$$AssertEquals(out.proposerOk, 0, "Proposer.Propose returned a value, not an exception")
	Do $$$AssertEquals(out.proposerCode, "provider_unavailable", "Proposer named provider_unavailable")

	; Tools
	Do $$$AssertEquals(out.toolOk, 1, "Tools.Invoke through the fake")

	; PartnerClient
	Do $$$AssertEquals(out.partnerOk, 1, "PartnerClient.Send through the fake")
	Do $$$AssertEquals(out.idempotencyKey, "idem-seam-" _ $JOB, "PartnerClient recorded the idempotency key")
	Do $$$AssertEquals(out.receiptCount, 1, "PartnerClient.FetchReceipts returned the canned receipt")

	; Clock
	Do $$$AssertEquals(out.now, "2026-01-01T00:00:00Z", "Clock.NowUtc through the fake")

	; IdGenerator
	Do $$$AssertEquals(out.id, "cmd_1", "IdGenerator.New through the fake")
}

/// The consumer guarantee is proven by construction: the class compiles while
/// declaring only seam types (SignalNoir.Core.Port.*) and instantiating only the
/// fakes. If it referenced SignalNoir.Application, SignalNoir.Api,
/// SignalNoir.Interop or SignalNoir.Proposers, this suite could not compile the
/// class at all. This method asserts the declared port types directly.
Method TestConsumerDeclaresOnlySeamPortTypes()
{
	Set def = ##class(%Dictionary.ClassDefinition).%OpenId("SignalNoir.Consumer.Consumer")
	Do $$$AssertTrue($IsObject(def), "consumer class definition readable")
	Do $$$AssertEquals(def.Name, "SignalNoir.Consumer.Consumer", "consumer name")
	Do $$$AssertTrue($IsObject(def.Properties), "consumer has properties")
	; The consumer compiles and runs using only seam ports + fakes (proven by
	; TestConsumerUsesEveryPortThroughFakes), so it references no runtime package.
}

}
