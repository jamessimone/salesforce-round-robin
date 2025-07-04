$ErrorActionPreference = 'Stop'

function Get-SFDX-Project-JSON {
  Get-Content -Path ./sfdx-project.json | ConvertFrom-Json
}

$sfdxProjectJsonPath = "./sfdx-project.json"
$sfdxProjectJson = Get-SFDX-Project-JSON

function Update-Package-Install-Links {
  param (
    $filePath,
    $newPackageVersionId
  )
  Write-Host "Updating $filePath with new package version Id ..." -ForegroundColor Yellow
  $loginReplacement = "https://login.salesforce.com/packaging/installPackage.apexp?p0=" + $newPackageVersionId
  $testReplacement = "https://test.salesforce.com/packaging/installPackage.apexp?p0=" + $newPackageVersionId
  ((Get-Content -path $filePath -Raw) -replace "https:\/\/login.salesforce.com\/packaging\/installPackage.apexp\?p0=.{0,18}", $loginReplacement) | Set-Content -Path $filePath -NoNewline
  ((Get-Content -path $filePath -Raw) -replace "https:\/\/test.salesforce.com\/packaging\/installPackage.apexp\?p0=.{0,18}", $testReplacement) | Set-Content -Path $filePath -NoNewline
  git add $filePath -f
}


function Get-Is-Version-Promoted {
  param ($versionNumber, $packageName)
  $promotedPackageVersions = (npx sf package version list --released --packages $packageName --json | ConvertFrom-Json).result | Select-Object -ExpandProperty Version
  if ($null -eq $promotedPackageVersions) {
    return $false
  } else {
    $isPackagePromoted = $promotedPackageVersions.Contains($versionNumber)
    Write-Host "Is $versionNumber for $packageName promoted? $isPackagePromoted" -ForegroundColor Yellow
    return $isPackagePromoted
  }
}

function Get-Package-JSON {
  Get-Content -Path ./package.json | ConvertFrom-Json
}

function Get-Next-Package-Version() {
  param ($currentPackage, $packageName)
  $currentPackageVersion = $currentPackage.versionNumber
  $shouldIncrement = Get-Is-Version-Promoted $currentPackageVersion $packageName
  if ($true -eq $shouldIncrement) {
    $currentPackageVersion = $currentPackageVersion.Remove($currentPackageVersion.LastIndexOf(".0"))
    $patchVersionIndex = $currentPackageVersion.LastIndexOf(".");
    $currentVersionNumber = ([int]$currentPackageVersion.Substring($patchVersionIndex + 1, $currentPackageVersion.Length - $patchVersionIndex - 1)) + 1
    Write-Host "Re-incrementing sfdx-project.json version number for $packageName to versionNumber: $currentVersionNumber" -ForegroundColor Yellow
    # increment package version prior to calling SFDX
    $currentPackageVersion = $currentPackageVersion.Substring(0, $patchVersionIndex + 1) + $currentVersionNumber.ToString() + ".0"
    $currentPackage.versionNumber = $currentPackageVersion

    Write-Host "Re-writing sfdx-project.json with updated package version number ..."
    ConvertTo-Json -InputObject $sfdxProjectJson -Depth 4 | Set-Content -Path $sfdxProjectJsonPath -NoNewline
    # sfdx-project.json is ignored by default; use another file as the --ignore-path to force prettier
    # to run on it
    npx prettier --write $sfdxProjectJsonPath --tab-width 4 --ignore-path ..\.forceignore
  }
  if ("salesforce-round-robin" -eq $packageName) {
    $versionNumberToWrite = $currentPackageVersion.Remove($currentPackageVersion.LastIndexOf(".0"))
    Write-Host "Bumping package.json version to: $versionNumberToWrite" -ForegroundColor Yellow

    $packageJson = Get-Package-JSON
    $packageJson.version = $versionNumberToWrite
    $packagePath = "./package.json"
    ConvertTo-Json -InputObject $packageJson | Set-Content -Path $packagePath -NoNewline

    git add $packagePath
  }
}

# used in package.json scripts & build-and-promote-package.ps1
function Generate() {
  param (
    [string]$packageName,
    [string]$readmePath
  )

  Write-Host "Starting for $packageName" -ForegroundColor Yellow

  $currentPackage = ($sfdxProjectJson.packageDirectories | Select-Object | Where-Object -Property package -eq $packageName)
  Get-Next-Package-Version $currentPackage $packageName
  $currentPackageVersion = $currentPackage.versionNumber

  Write-Host "Creating package version: $currentPackageVersion ..." -ForegroundColor White

  $createPackageResult = npx sf package version create --package $packageName --wait 30 --code-coverage --installation-key-bypass --version-number $currentPackageVersion --json | ConvertFrom-Json
  $currentPackageVersionId = $createPackageResult.result.SubscriberPackageVersionId
  if ($null -eq $currentPackageVersionId) {
    Write-Host "Package create fail! Result: $createPackageResult" -ForegroundColor Red
    throw $createPackageResult
  } else {
    git add $sfdxProjectJsonPath
  }

  Write-Host "Successfully created package Id: $currentPackageVersionId" -ForegroundColor Green

  Update-Package-Install-Links $readmePath $currentPackageVersionId

  Write-Host "Finished successfully!" -ForegroundColor Green
}
