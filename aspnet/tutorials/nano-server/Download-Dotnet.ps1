<#
    .NOTES
        Copyright (c) Microsoft Corporation.  All rights reserved.

    .SYNOPSIS
        Downloads and unzips the .NET Shared Framework

    .PARAMETER DotnetSourcePath
        Path to a .NET Core Binary. Defaults to https://dotnetcli.blob.core.windows.net/dotnet/beta/Binaries/Latest/dotnet-win-x64.latest.zip

    .PARAMETER DestinationPath
        Path to extract the .NET Core Framework to. Defaults to C:\dotnet

    .EXAMPLE
        .\Download-Dotnet.ps1 -DotnetSourcePath "https://dotnetcli.blob.core.windows.net/dotnet/beta/Binaries/Latest/dotnet-win-x64.latest.zip" -DestinationPath "C:\dotnet"

#>
# Requires -Version 5.0

param(
    [string]
    [ValidateNotNullOrEmpty()]
    $DotnetSourcePath = "https://dotnetcli.blob.core.windows.net/dotnet/beta/Binaries/Latest/dotnet-win-x64.latest.zip",

    [string]
    [ValidateNotNullOrEmpty()]
    $DestinationPath = "C:\dotnet"
)

function
Copy-File
{
    [CmdletBinding()]
    param(
        [string]
        $SourcePath,

        [string]
        $DestinationPath
    )
    if ($SourcePath -eq $DestinationPath)
    {
        return
    }

    if (Test-Path $SourcePath)
    {
        Copy-Item -Path $SourcePath -Destination $DestinationPath
    }
    elseif (($SourcePath -as [System.URI]).AbsoluteURI -ne $null)
    {
        $handler = New-Object System.Net.Http.HttpClientHandler
        $client = New-Object System.Net.Http.HttpClient($handler)
        $client.Timeout = New-Object System.TimeSpan(0, 30, 0)
        $cancelTokenSource = [System.Threading.CancellationTokenSource]::new()
        $responseMsg = $client.GetAsync([System.Uri]::new($SourcePath), $cancelTokenSource.Token)
        $responseMsg.Wait()
        if (!$responseMsg.IsCanceled)
        {
            $response = $responseMsg.Result
            if ($response.IsSuccessStatusCode)
            {
                $downloadedFileStream = [System.IO.FileStream]::new($DestinationPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
                $copyStreamOp = $response.Content.CopyToAsync($downloadedFileStream)
                $copyStreamOp.Wait()
                $downloadedFileStream.Close()
                if ($copyStreamOp.Exception -ne $null)
                {
                    echo error
                    throw $copyStreamOp.Exception
                }
            }
        }
    }
    else
    {
        throw "Cannot copy from $SourcePath"
    }
}


function
Expand-ArchiveNano
{
    [CmdletBinding()]
    param
    (
        [string] $Path,
        [string] $DestinationPath
    )

    [System.IO.Compression.ZipFile]::ExtractToDirectory($Path, $DestinationPath)
}


function
Test-Nano()
{
    $EditionId = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'EditionID').EditionId

    return (($EditionId -eq "ServerStandardNano") -or
            ($EditionId -eq "ServerDataCenterNano") -or
            ($EditionId -eq "NanoServer") -or
            ($EditionId -eq "ServerTuva"))
}

function
Install-Dotnet()
{
    if (Test-Nano)
    {
        Expand-ArchiveNano -Path $nssmZip -DestinationPath $tempDirectory.FullName
    }
    elseif ($PSVersionTable.PSVersion.Major -ge 5)
    {
        Expand-Archive -Path $nssmZip -DestinationPath $tempDirectory.FullName
    }
}


try
{
    if (! (Test-Path $DestinationPath)) {
        $TempPath = [System.IO.Path]::GetTempFileName()
        Copy-File -SourcePath https://dotnetcli.blob.core.windows.net/dotnet/beta/Binaries/Latest/dotnet-win-x64.latest.zip -DestinationPath $TempPath
        Expand-ArchiveNano -Path $TempPath -DestinationPath $DestinationPath
        Remove-Item $TempPath
    }
    else {
        Write-Host "$DestinationPath already exists"
    }


}
catch
{
    Write-Error $_
}
