Write-Host "Test_OU_Create.ps1 - V1.0.0"
Write-Host "This script creates an Organizational Units for Test stacks."
Write-Host "Note: Press return to accept a default value."
$LzOrgCode = (Read-Host "Enter your OrgCode")
do {
    $LzMgmtProfile = (Read-Host "Enter your AWS CLI Management Account Profile (default: ${LzOrgCode}Mgmt)")
    
    if($LzMgmtProfile -eq "") {
        $LzMgmtProfile = "${LzOrgCode}Mgmt"
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
$LzTestOUName = $LzOrgCode + "TestOU"
Write-Host "        - ${LzTestOUName}"

$LzContinue = (Read-Host "Continue y/n")
if($LzContinue -ne "y") {
    Write-Host "Exiting"
    Exit
}
Write-Host ""
Write-Host "Processing Starting"

# Get LzRootId - note: Currently, there should only ever be one root.
# Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/list-roots.html
$LzRoots = aws organizations list-roots --profile $LzMgmtProfile | ConvertFrom-Json
$LzRootId = $LzRoots.Roots[0].Id 

Write-Host "Creating Organizational Units:"
# Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/create-organizational-unit.html

# Create Organization Unit for Test
$LzTestOU = aws organizations create-organizational-unit --parent-id $LzRootId --name $LzTestOUName  --profile $LzMgmtProfile | ConvertFrom-Json
$null = $LzTestOU.OrganizationalUnit.Id 
Write-Host "    - ${LzTestOUName} created"

Write-Host "Processing Complete"
