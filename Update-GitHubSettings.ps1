# Update-GitHubSettings.ps1 v1.0.0
# We import lib in script directory with -Force each time to ensure lib version matches script version
# Performance is not an issue with these infrequently executed scripts
Import-Module (Join-Path -Path (Split-Path $script:MyInvocation.MyCommand.Path) -ChildPath LazyStackLib) -Force
Write-Host "Update-GitHubSettings.ps1 v1.0.0
This script updates your GitHub configuration and writes to the OrgSettings.json file
It does not update any CodeBuild project that have used previous settings. If 
you have existing CodeBuild projects that will be affected by these changes, you 
should update them using.
Note: Press return to accept a default value."

$LzOrgSettings = Get-LzOrgSettings

#GitHubAcctName 
$defmsg = Get-DefMessage -current $LzOrgSettings.GitHubAcctName 
$LzOrgSettings.GitHubAcctName = (Read-String `
    -prompt "Enter GitHub Admin Account Name${defmsg}" `
    -default $LzOrgSettings.GitHubAcctName `
    -required $true)

#GitHubOrgName
$defmsg = Get-DefMessage -current $LzOrgSettings.GitHubOrgName 
$LzOrgSettings.GitHubOrgName = (Read-String `
    -prompt "Enter GitHub Organziation Name${defmsg}" `
    -default $LzOrgSettings.GitHubOrgName `
    -required $true)

Write-Host "Please Review and Confirm the following:"
$value = $LzOrgSettings.GitHubAcctName
Write-Host "    GitHub Admin Account Name: ${value}"

$value = $LzOrgSettings.GitHubOrgName
Write-Host "    GitHub Organization Name: ${value}"

Set-LzOrgSettings -settings $LzOrgSettings

