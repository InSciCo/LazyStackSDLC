Write-Host "Org_Create.ps1 - V1.0.0"
Write-Host "This script creates OrgDevOU, OrgTestOU and OrgProdOU"
Write-Host "Note: Press return to accept a default value."
$LzOrgCode = (Read-Host "Enter your OrgCode")
do {
    $LzMgmtProfile = "${LzOrgcode}Mgmt"
    $LzMgmtProfileInput = (Read-Host "Enter your AWS CLI Management Account Profile (default: ${LzOrgCode}Mgmt)")
    
    if($LzMgmtProfileInput -eq $null) {
        $LzMgmtProfile = $LzMgmtProfileInput
    }

   $LzMgmtProfileKey = (aws configure get profile.${LzMgmtProfile}.aws_access_key_id)
    if($LzMgmtProfileKey -eq "") {
        Write-Host "Profile ${LzMgmtProfile} not found or not configured with Access Key"
        $LzMgmtProfileExists = $false
    }
    else  {
        $LzMgmtProfileExists = $true
        # Grab region in managment profile as default for new IAM User
        $null = aws configure get profile.${LzMgmtProfile}.region
    }
}
until ($LzMgmtProfileExists)

Write-Host "Please Review and confirm the following:"
Write-Host "    OrgCode: ${LzOrgCode}"

Write-Host "    Management Account Profile: ${LzMgmtProfile}"
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
if($? -eq $false){
    $LzDevOU = aws organizations create-organizational-unit --parent-id $LzRootId --name $LzDevOUName  --profile $LzMgmtProfile | ConvertFrom-Json
    if($LzDevOU.OrganizationalUnit.Id -eq $null)
    {
        Write-Host "    - ${LzDevOUName} create failed"
    }else{
        Write-Host "    - ${LzDevOUName} created"
    }
}else{
    Write-Host "    - ${LzDevOUName} already exits"
}

$LzTestOU = $OuList.OrganizationalUnits | Where-Object Name -eq $LzTestOUName
if($? -eq $false){
    $LzTestOU = aws organizations create-organizational-unit --parent-id $LzRootId --name $LzTestOUName  --profile $LzMgmtProfile | ConvertFrom-Json
    if($LzTestOU.OrganizationalUnit.Id -eq $null)
    {
        Write-Host "    - ${LzTestOUName} create failed"
    }else{
        Write-Host "    - ${LzTestOUName} created"
    }
}else{
    Write-Host "    - ${LzTestOUName} already exits"
}

$LzProdOU = $OuList.OrganizationalUnits | Where-Object Name -eq $LzProdOUName
if($? -eq $false){
    $LzProdOU = aws organizations create-organizational-unit --parent-id $LzRootId --name $LzProdOUName  --profile $LzMgmtProfile | ConvertFrom-Json
    if($LzProdOU.OrganizationalUnit.Id -eq $null)
    {
        Write-Host "    - ${LzProdOUName} create failed"
    }else{
        Write-Host "    - ${LzProdOUName} created"
    }
}else{
    Write-Host "    - ${LzProdOUName} already exits"
}

Write-Host "Processing Complete"
