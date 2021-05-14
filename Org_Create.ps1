Write-Host "Org_Create.ps1 - V1.0.0"
Write-Host "This script creates OrgDevOU, OrgTestOU and OrgProdOU"
Write-Host "Note: Press return to accept a default value."

do {
    if(Test-Path -Path "currentorg.txt") {
        $LzSettingsFolder = Get-Content -Path "currentorg.txt"
    } 

    $LzSettingsFolderInput = Read-Host "Organization Settings Folder (default: ${LzSettingsFolder})"
    if($LzSettingsFolderInput -ne "") {
    $LzSettingsFolder = $LzSettingsFolderInput
    }
    $LzFolderFound = Test-Path -Path $LzSettingsFolder
    if($LzFolderFound -eq $false) {
        Write-Host "Folder not found, please run SetDefaults if you have not done so already."
        exit
    }

} until ($LzFolderFound)

# Read Settings.json to create Settings object
$LzSettingsFilePath = Join-Path -Path $LzSettingsFolder -Childpath "Settings.json"
$LzSettings = Get-Content -Path $LzSettingsFilePath | ConvertFrom-Json

$LzOrgCode = $LzSettings.OrgCode
if("" -eq $LzOrgCode) 
{
    Write-Host "OrgCode is not configured in Settings file. Please run SetDefaults."
    exit
}

$LzMgmtProfile = $LzSettings.AwsMgmtAccount
if("" -eq $LzMgmtProfile) {
    Write-Host "AWS Managment Account is not configured in Settings file. Please run SetDefaults."
    exit
}

# Double check that managment account profile is configured

$LzMgmtProfileKey = (aws configure get profile.${LzMgmtProfile}.aws_access_key_id)
if($LzMgmtProfileKey -eq "") {
    Write-Host "Profile ${LzMgmtProfile} not found or not configured with Access Key"
    Write-Host "Please run the SetDefaults if you have not done so already."
    exit
}

Write-Host "Please Review and confirm the following:"
Write-Host "    OrgCode: ${LzOrgCode}"
Write-Host "    AWS Organizatinal Units to be created:"
$LzDevOUName = $LzOrgCode + "DevOU"
Write-Host "        - ${LzDevOUName}"
$LzTestOUName = $LzOrgCode + "TestOU"
Write-Host "        - ${LzTestOUName}"
$LzProdOUName = $LzOrgCode + "ProdOU"
Write-Host "        - ${LzProdOUName}"

$LzContinue = (Read-Host "Continue y/n")
if($LzContinue -ne "y") {
    Write-Host "Exiting"
    Exit
}
Write-Host ""
Write-Host "Processing Starting"


# Create organization
# Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/create-organization.html
Write-Host "Creating Organization."
$null = aws organizations create-organization --profile $LzMgmtProfile
if($? -eq $false){
    Write-Host "Exception can be ignored, your Organization already exists!"
}

# Get LzRootId - note: Currently, there should only ever be one root.
# Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/list-roots.html
$LzRoots = aws organizations list-roots --profile $LzMgmtProfile | ConvertFrom-Json
$LzRootId = $LzRoots.Roots[0].Id 

Write-Host "Creating Organizational Units:"
# Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/create-organizational-unit.html

$OuList = aws organizations list-organizational-units-for-parent --parent-id $LzRootId --profile $LzMgmtProfile | ConvertFrom-Json
# Create Organization Unit for Dev
$LzDevOU = $OuList.OrganizationalUnits | Where-Object Name -eq $LzDevOUName
if($LzDevOu.Count -eq 0){
    $LzDevOU = aws organizations create-organizational-unit --parent-id $LzRootId --name $LzDevOUName  --profile $LzMgmtProfile | ConvertFrom-Json
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
    $LzTestOU = aws organizations create-organizational-unit --parent-id $LzRootId --name $LzTestOUName  --profile $LzMgmtProfile | ConvertFrom-Json
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
    $LzProdOU = aws organizations create-organizational-unit --parent-id $LzRootId --name $LzProdOUName  --profile $LzMgmtProfile | ConvertFrom-Json
    if($null -eq $LzProdOU.OrganizationalUnit.Id)
    {
        Write-Host "    - ${LzProdOUName} create failed"
    }else{
        Write-Host "    - ${LzProdOUName} created"
    }
}else{
    Write-Host "    - ${LzProdOUName} already exits"
}

Write-Host "Processing Complete"
