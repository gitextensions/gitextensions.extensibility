param([string] $Version = $env:APPVEYOR_BUILD_VERSION)

Push-Location $PSScriptRoot;
try 
{
    nuget pack ..\src\GitExtensions.Extensibility\GitExtensions.Extensibility.nuspec -OutputDirectory .. -Version $Version
}
catch 
{
    Write-Host $_.Exception -ForegroundColor Red;
    exit -1;
}
finally 
{
    Pop-Location;
}