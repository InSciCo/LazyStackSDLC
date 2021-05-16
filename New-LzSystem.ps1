#New-LzSystem.ps1 
#This script builds a fully configured System
Write-Host "This script builds a fully configured System containing:
   - System Test Account belonging to the System Organizational Unit
   - System Production Account belonging to the Production Organizational Unit
   - GitHub Repository configuration (option to use existing repo or copy a repo template)
   - AWS CodeBuild projects in System Test account to publish and delete Pull Request stacks
   - AWS CodeBuild Project in System Production account to publish production stack
Note: Press return to accept a default value. For (Y/n) Y is the default."

# Check Defaults
$LzOrgSettings = Get-LzOrgSettings
if($LzOrgSettings.OrgCode -eq "") {
    Write-Host "Error: The OrgSettings.json OrgCode is not set."
    exit
}

if($LzOrgSettings.AwsMgmtProfile -eq "") {
    Write-Host "Error: The OrgSettings.json file AwsMgmtProfile is not set."
    exit
}

$LzCreateTestAccount = (Get-YesNo -value (Read-Host "Create Test Account? Y/n")  -default $true) 
if($LzCreateTestAccount) {
    $LzTestAccountEmail = Set-Email -prompt "Email for AzTestAccount (example: me+AzTutTest@gmail.com)"
}

$LzCreateProdAccount = (Get-YesNo -value (Read-Host "Create Production Account? Y/n")  -default $true) 
if($LzCreateProdAccount) {
    $LzProdAccountEmail = Set-Email -prompt "Email for AzProdAccount (example: me+AzTutTest@gmail.com)"
}


