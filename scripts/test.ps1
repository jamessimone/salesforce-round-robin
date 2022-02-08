$DebugPreference = 'Continue'
$ErrorActionPreference = 'Stop'
# This is also the same script that runs on Github via the Github Action configured in .github/workflows - there, the
# DEVHUB_SFDX_URL.txt file is populated in a build step
$testInvocation = 'npx sfdx force:apex:test:run -r human -w 20 -c -d ./tests/apex'
$scratchOrgName = 'round-robin-scratch'

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
    npx sfdx force:org:delete -p -u $scratchOrgName
  } catch {
    Write-Debug "Scratch org deletion failed, continuing ..."
  }

  if ($true -eq $testFailure) {
    throw 'Test run failure!'
  }
}

function Reset-SFDX-Json() {
  Write-Debug "Resetting SFDX project JSON at project root"
  Copy-Item -Path ./scripts/sfdx-project.json -Destination ./sfdx-project.json -Force
  Remove-Item -Path ./scripts/sfdx-project.json
}

Write-Debug "Starting build script"

# Authorize Dev Hub using prior creds. There's some issue with the flags --setdefaultdevhubusername and --setdefaultusername both being passed when run remotely

npx sfdx auth:sfdxurl:store -f ./DEVHUB_SFDX_URL.txt -a round-robin
npx sfdx config:set defaultusername=round-robin defaultdevhubusername=round-robin

# For local dev, store currently auth'd org to return to
# Also store test command shared between script branches, below
$scratchOrgAllotment = ((npx sfdx force:limits:api:display --json | ConvertFrom-Json).result | Where-Object -Property name -eq "DailyScratchOrgs").remaining

Write-Debug "Total remaining scratch orgs for the day: $scratchOrgAllotment"
Write-Debug "Test command to use: $testInvocation"

$shouldDeployToSandbox = $false

if($scratchOrgAllotment -gt 0) {
  Write-Debug "Beginning scratch org creation"
  # Create Scratch Org
  $scratchOrgCreateMessage = npx sfdx force:org:create -f config/project-scratch-def.json -a $scratchOrgName -s -d 1
  # Sometimes SFDX lies (UTC date problem?) about the number of scratch orgs remaining in a given day
  # The other issue is that this doesn't throw, so we have to test the response message ourselves
  if($scratchOrgCreateMessage -eq 'The signup request failed because this organization has reached its active scratch org limit') {
    throw $1
  }
  # Deploy
  Write-Debug 'Pushing source to scratch org ...'
  npx sfdx force:source:push
  # Run tests
  Start-Tests
} else {
  $shouldDeployToSandbox = $true
}

if($shouldDeployToSandbox) {
  Write-Debug "No scratch orgs remaining, running tests on sandbox"

  try {
    # Deploy
    Write-Debug "Deploying source to sandbox ..."
    npx sfdx force:source:deploy -p rollup
    npx sfdx force:source:deploy -p extra-tests
    Start-Tests
  } catch {
    throw 'Error deploying to sandbox!'
  }
}


Write-Debug "Build + testing finished successfully"

