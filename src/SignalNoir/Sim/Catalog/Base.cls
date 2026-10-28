Class SignalNoir.Sim.Catalog.Base [ Abstract ]
{

/// A family of scenario variants as versioned data (research D7). Each
/// subclass holds its variants as a JSON array in XData Variants, in the
/// format of contracts/scenario-script.md. The private partnerRule of a
/// variant is never served (D8).
Parameter CATALOGVERSION = "2026.10.28";

XData Variants [ MimeType = application/json ]
{
[]
}

}
