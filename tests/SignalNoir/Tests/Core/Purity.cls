/// The Core performs no I/O and depends on nothing outside itself (Constitution Principle I,
/// specs/002 FR-001). Scans the compiled source of every SignalNoir.Core class.
Class SignalNoir.Tests.Core.Purity Extends %UnitTest.TestCase
{

/// Lower-case fragments that must not appear in any Core method.
Parameter FORBIDDEN = "&sql,%sql.,%file,%stream.file,%net.,$ztimestamp,$zts,$horolog,$increment,$incr,^";

Method TestCoreClassesExist()
{
    do $$$AssertTrue(..CoreClasses().Count() > 0, "SignalNoir.Core has classes")
}

Method TestNoPersistentCoreClass()
{
    set classes = ..CoreClasses()
    for i = 1:1:classes.Count() {
        set name = classes.GetAt(i)
        do $$$AssertNotTrue($classmethod(name, "%Extends", "%Library.Persistent"), name_" is not persistent")
    }
}

Method TestNoIOInCoreMethods()
{
    set classes = ..CoreClasses()
    for i = 1:1:classes.Count() {
        set name = classes.GetAt(i)
        set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.MethodDefinition WHERE parent = ?", name)
        while rs.%Next() {
            set method = ##class(%Dictionary.MethodDefinition).%OpenId(name_"||"_rs.Name)
            set code = $zconvert(method.Implementation.Read(1000000), "L")
            for j = 1:1:$length(..#FORBIDDEN, ",") {
                set token = $piece(..#FORBIDDEN, ",", j)
                do $$$AssertNotTrue(code [ token, name_":"_rs.Name_" has no '"_token_"'")
            }
        }
    }
}

/// Classes of package SignalNoir.Core (not subpackages of other packages).
ClassMethod CoreClasses() As %ListOfDataTypes
{
    set list = ##class(%ListOfDataTypes).%New()
    set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.ClassDefinition WHERE Name %STARTSWITH 'SignalNoir.Core.'")
    while rs.%Next() { do list.Insert(rs.Name) }
    quit list
}

}
