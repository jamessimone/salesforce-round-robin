$DebugPreference = 'Continue'
$ErrorActionPreference = 'Stop'
# This is also the same script that runs on Github via the Github Action configured in .github/workflows - there, the
# DEVHUB_SFDX_URL.txt file is populated in a build step
$testInvocation = 'npx sf apex run test --suite-names -s RoundRobinTestSuite --result-format human --wait 20 --code-coverage --output-dir ./tests/apex --concise'
$scratchOrgName = 'round-robin-scratch'
function Start-Deploy() {
  Write-Debug "Deploying source ..."
  npx sf project deploy start --source-dir -p core
  npx sf project deploy start --source-dir -p integration-tests
}

function Start-Tests() {
  Write-Debug "Starting test run ..."
  Invoke-Expression $testInvocation
  $testRunId = Get-Content tests/apex/test-run-id.txt
  $specificTestRunJson = Get-Content "tests/apex/test-result-$testRunId.json" | ConvertFrom-Json
  $testFailure = $false
  if ($specificTestRunJson.summary.outcome -eq "Failed") {
    $testFailure = $true
  }

  try {
    Write-Debug "Deleting scratch org ..."
    sf org delete scratch --no-prompt --target-org $scratchOrgName
  } catch {
    Write-Debug "Scratch org deletion failed, continuing ..."
  }

  if ($true -eq $testFailure) {
    throw 'Test run failure!'
  }
}

Write-Debug "Starting build script"

$scratchOrgAllotment = ((npx sf limits api display --json | ConvertFrom-Json).result | Where-Object -Property name -eq "DailyScratchOrgs").remaining

Write-Debug "Total remaining scratch orgs for the day: $scratchOrgAllotment"
Write-Debug "Test command to use: $testInvocation"

if($scratchOrgAllotment -gt 0) {
  try {
    Write-Debug "Beginning scratch org creation"
    # Create Scratch Org
    npx sf org create scratch --definition-file config/project-scratch-def.json --alias $scratchOrgName --set-default --duration-days 30
  } catch {
    # Do nothing, we'll just try to deploy to the Dev Hub instead
  }
}

Start-Deploy
Start-Tests

Write-Debug "Build + testing finished successfully"

