# New-LzAwsOrg.ps1 v1.0.0
# We import lib in script directory with -Force each time to ensure lib version matches script version
# Performance is not an issue with these infrequently executed scripts
Import-Module (Join-Path -Path (Split-Path $script:MyInvocation.MyCommand.Path) -ChildPath LazyStackLib) -Force
if((Get-LibVersion) -ne "v1.0.0") {
    Write-Host "Error: Imported LazyStackSMF lib has wrong version!"
    exit
}

Write-Host "This script creates OrgDevOU, OrgTestOU and OrgProdOU
It also writes the initial OrgSettings.json file.
Note: Press return to accept a default value."

$LzOrgSettings = Get-LzOrgSettings

#OrgCode
$defmsg = Get-DefMessage -current $LzOrgSettings.OrgCode -example "Az"
$LzOrgSettings.OrgCode = (Read-OrgCode `
    -prompt "Enter OrgCode${defmsg}" `
    -default $LzOrgSettings.OrgCode)

#AwsMgmtProfile
do {
    $default = Get-DefaultString `
        -current $LzOrgSettings.AwsMgmtProfile `
        -default ($LzOrgSettings.OrgCode + "Mgmt")
    $defmsg = Get-DefMessage `
        -current $LzOrgSettings.AwsMgmtProfile `
        -default $default 
    $lastvalue = $LzOrgSettings.AwsMgmtProfile = (Read-String `
        -prompt "Enter Aws CLI Management Account Profile${defmsg}" `
        -default $default) 
    $found = Test-AwsProfileExists -profilename $lastvalue
    if(!$found) {
        Write-Host "AWS AWS CLI Managment Account Profile ${lastvalue} Not Found!"        
        Write-Host "Please try again."
    }
} until ($found)

#Confirm Inputs
Write-Host "Please Review and Confirm the following:"
$value = $LzOrgSettings.OrgCode
Write-Host "    OrgCode: ${value}"

$value = $LzOrgSettings.AwsMgmtProfile
Write-Host "    AWS CLI Management Account Profile: ${value}"

$LzDevOUName = $LzOrgSettings.OrgCode + "DevOU"
Write-Host "    Create ${LzDevOUName} Organizational unit if it doesn't already exist"

$LzTestOUName = $LzOrgSettings.OrgCode + "TestOU"
Write-Host "    Create ${LzTestOUName} Organizational unit if it doesn't already exist"

$LzProdOUName = $LzOrgSettings.OrgCode + "ProdOU"
Write-Host "    Create ${LzProdOUName} Organizational unit if it doesn't already exist"

$continue = Read-YesNo -prompt "Continue?" -default $true
if(!$continue) { 
    Write-Host "Quitting without processing!"
    exit 
}

#Processing
# Create organization
# Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/create-organization.html
Write-Host "Creating Organization."
$null = aws organizations create-organization --profile $LzOrgSettings.AwsMgmtProfile
if($? -eq $false){
    Write-Host "Exception can be ignored, your Organization already exists!"
}

# Get LzRootId - note: Currently, there should only ever be one root.
# Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/list-roots.html
$LzRoots = aws organizations list-roots --profile $LzOrgSettings.AwsMgmtProfile | ConvertFrom-Json
$LzRootId = $LzRoots.Roots[0].Id 

Write-Host "Creating Organizational Units:"
# Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/create-organizational-unit.html

$OuList = aws organizations list-organizational-units-for-parent --parent-id $LzRootId --profile $LzOrgSettings.AwsMgmtProfile | ConvertFrom-Json
# Create Organization Unit for Dev
$LzDevOU = $OuList.OrganizationalUnits | Where-Object Name -eq $LzDevOUName
if($LzDevOu.Count -eq 0){
    $LzDevOU = aws organizations create-organizational-unit --parent-id $LzRootId --name $LzDevOUName  --profile $LzOrgSettings.AwsMgmtProfile | ConvertFrom-Json
    if($null -eq $LzDevOU.OrganizationalUnit.Id)
    {
        Write-Host "    - ${LzDevOUName} create failed"
    }else{
        Write-Host "    - ${LzDevOUName} created"
    }
}else{
    Write-Host "    - ${LzDevOUName} already exits"
}

$LzTestOU = $OuList.OrganizationalUnits | Where-Object Name -eq $LzTestOUName
if($LzTestOu.Count -eq 0){
    $LzTestOU = aws organizations create-organizational-unit --parent-id $LzRootId --name $LzTestOUName  --profile $LzOrgSettings.AwsMgmtProfile | ConvertFrom-Json
    if($null -eq $LzTestOU.OrganizationalUnit.Id)
    {
        Write-Host "    - ${LzTestOUName} create failed"
    }else{
        Write-Host "    - ${LzTestOUName} created"
    }
}else{
    Write-Host "    - ${LzTestOUName} already exits"
}

$LzProdOU = $OuList.OrganizationalUnits | Where-Object Name -eq $LzProdOUName 
if($LzProdOu.Count -eq 0){
    $LzProdOU = aws organizations create-organizational-unit --parent-id $LzRootId --name $LzProdOUName  --profile $LzOrgSettings.AwsMgmtProfile | ConvertFrom-Json
    if($null -eq $LzProdOU.OrganizationalUnit.Id)
    {
        Write-Host "    - ${LzProdOUName} create failed"
    }else{
        Write-Host "    - ${LzProdOUName} created"
    }
}else{
    Write-Host "    - ${LzProdOUName} already exits"
}

Write-Host "Updating OrgSettings.json file."
Set-LzOrgSettings -settings $LzOrgSettings

Write-Host "Processing complete."

