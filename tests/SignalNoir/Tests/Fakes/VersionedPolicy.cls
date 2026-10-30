Class SignalNoir.Tests.Fakes.VersionedPolicy Extends SignalNoir.Core.ExecutionPolicy
{

/// Test-only execution policy whose reference data moved on: the policy in
/// force is not the one fixture Proposals recorded (008 US2)
Method CurrentVersions() As %DynamicObject
{
	Return {"policy": "pol-v2", "mapping": ""}
}

}
