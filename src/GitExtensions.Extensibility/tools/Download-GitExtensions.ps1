param(
    [Parameter(Mandatory=$true)]
    [string] $ExtractRootPath, 
    [Parameter(Mandatory=$true)]
    [string] $Version, 
    [ValidateSet('GitHub','AppVeyor', ignorecase=$False)]
    [string] $Source = "GitHub"
)

$LatestVersionName = "latest";

function Test-LocalCopy 
{
    Param(
        [Parameter(Mandatory=$true, Position=0)]
        [string] $ExtractPath,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $FileName
    )

    $FilePath = [System.IO.Path]::Combine($ExtractPath, $FileName);
    if (Test-Path $FilePath)
    {
        Write-Host "Download '$FileName' already exists.";
        return $true;
    }
    
    return $false;
}

function Find-ArchiveUrl 
{
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $Version,
        [Parameter(Mandatory=$true, Position=1)]
        [ValidateSet('GitHub','AppVeyor', ignorecase=$False)]
        [string] $Source
    )
    
    Write-Host "Searching for Git Extensions release '$Version' on '$Source'.";
    if ($Source -eq "GitHub")
    {
        return Find-ArchiveUrlFromGitHub -Version $Version;
    }
    
    if ($Source -eq "AppVeyor")
    {
        return Find-ArchiveUrlFromAppVeyor -Version $Version;
    }

    throw "Unable to find download URL for 'Git Extensions $Version'";
}

function Find-ArchiveUrlFromGitHub 
{
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $Version
    )
    
    $BaseUrl = 'https://api.github.com/repos/gitextensions/gitextensions/releases';
    $SelectedRelease = $null;
    if ($Version -eq $LatestVersionName) 
    {
        $SelectedRelease = Invoke-RestMethod -Uri "$BaseUrl/latest";
        $Version = $SelectedRelease.tag_name;
        Write-Host "Selected release '$($SelectedRelease.name)'.";
    }
    else 
    {
        $Releases = Invoke-RestMethod -Uri $BaseUrl;
        foreach ($Release in $Releases)
        {
            if ($Release.tag_name -eq $Version)
            {
                Write-Host "Selected release '$($Release.name)'.";
                $SelectedRelease = $Release;
                break;
            }
        }
    }

    if (!($null -eq $SelectedRelease))
    {
        foreach ($Asset in $SelectedRelease.assets)
        {
            if ($Asset.content_type -eq "application/zip" -and $Asset.name.Contains('Portable'))
            {
                Write-Host "Selected asset '$($Asset.name)'.";
                return $Version,$Asset.browser_download_url;
            }
        }
    }

    throw "Unable to find download URL for 'Git Extensions $Version' on GitHub";
}

function Find-ArchiveUrlFromAppVeyor 
{
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $Version
    )
    
    $UrlVersion = $Version;
    if ($UrlVersion.StartsWith("v")) 
    {
        $UrlVersion = $UrlVersion.Substring(1);
    }

    $UrlBase = "https://ci.appveyor.com/api";

    try 
    {
        if ($Version -eq $LatestVersionName)
        {
            $Url = "$UrlBase/projects/gitextensions/gitextensions/branch/master";
        }
        else 
        {
            $Url = "$UrlBase/projects/gitextensions/gitextensions/build/$UrlVersion";
        }

        $BuildInfo = Invoke-RestMethod -Uri $Url;
        $Version = "v$($BuildInfo.build.version)";
        $Job = $BuildInfo.build.jobs[0];
        if ($Job.Status -eq "success") 
        {
            $JobId = $Job.jobId;
            Write-Host "Selected build job '$JobId'.";

            $AssetsUrl = "$UrlBase/buildjobs/$JobId/artifacts";
            $Assets = Invoke-RestMethod -Method Get -Uri $AssetsUrl;
            foreach ($Asset in $Assets)
            {
                if ($Asset.type -eq "zip" -and $Asset.FileName.Contains('Portable')) 
                {
                    Write-Host "Selected asset '$($Asset.FileName)'.";
                    return $Version,($AssetsUrl + "/" + $Asset.FileName);
                }
            }
        }
    }
    catch 
    {
        if (!($_.Exception.Response.StatusCode -eq 404)) 
        { 
            throw;
        }
    }

    throw "Unable to find download URL for 'Git Extensions $Version' on AppVeyor";
}

function Get-Application 
{
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $ArchiveUrl,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $ExtractPath,
        [Parameter(Mandatory=$true, Position=2)]
        [string] $FileName
    )
    
    if (!(Test-Path $ExtractPath))
    {
        New-Item -ItemType directory -Path $ExtractPath | Out-Null;
    }

    $FilePath = [System.IO.Path]::Combine($ExtractPath, $FileName);

    Write-Host "Downloading '$ArchiveUrl'...";

    Invoke-WebRequest -Uri $ArchiveUrl -OutFile $FilePath;
    Expand-Archive $FilePath -DestinationPath $ExtractPath -Force;
    
    Write-Host "Application extracted to '$ExtractPath'.";
}

function Get-ZipFileName {
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $Version
    )
    
    return "GitExtensions-$Version.zip";
}


Push-Location $PSScriptRoot;
try 
{
    $ExtractRootPath = Resolve-Path $ExtractRootPath;
    Write-Host "Extraction root path is '$ExtractRootPath'.";

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;

    if (!($Version -eq $LatestVersionName)) 
    {
        $FileName = Get-ZipFileName -Version $Version;
        if (Test-LocalCopy -ExtractPath $ExtractRootPath -FileName $FileName)
        {
            exit 0;
        }
    }
    
    $SelectedVersion,$DownloadUrl = Find-ArchiveUrl -Version $Version -Source $Source;
    if ($Version -eq $LatestVersionName) 
    {
        $FileName = Get-ZipFileName -Version $SelectedVersion;
        if (Test-LocalCopy -ExtractPath $ExtractRootPath -FileName $FileName)
        {
            exit 0;
        }
    }

    Get-Application -ArchiveUrl $DownloadUrl -ExtractPath $ExtractRootPath -FileName $FileName;
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