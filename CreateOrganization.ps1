Write-Host "CreateOrganization.ps1 - V1.0.0"
Write-Host "This script creates an Organization and Organizational Units for Dev, Review and Prod."
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
$LzDevOUName = $LzOrgCode + "DevOU"
Write-Host "        - ${LzDevOUName}"
$LzRevOUName = $LzOrgCode + "RevOU"
Write-Host "        - ${LzRevOUName}"
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

# Get LzRootId - note: Currently, there should only ever be one root.
# Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/list-roots.html
$LzRoots = aws organizations list-roots --profile $LzMgmtProfile | ConvertFrom-Json
$LzRootId = $LzRoots.Roots[0].Id 

Write-Host "Creating Organizational Units:"
# Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/create-organizational-unit.html

# Create Organization Unit for Dev
$LzDevOU = aws organizations create-organizational-unit --parent-id $LzRootId --name $LzDevOUName  --profile $LzMgmtProfile | ConvertFrom-Json
$null = $LzDevOU.OrganizationalUnit.Id 
Write-Host "    - ${LzDevOUName} created"

# Create Organization Unit for Review
$LzRevOU = aws organizations create-organizational-unit --parent-id $LzRootId --name $LzRevOUName  --profile $LzMgmtProfile | ConvertFrom-Json
$null = $LzRevOU.OrganizationalUnit.Id 
Write-Host "    - ${LzRevOUName} created"

# Create Organization Unit for Prod
$LzProdOU = aws organizations create-organizational-unit --parent-id $LzRootId --name $LzProdOUName  --profile $LzMgmtProfile | ConvertFrom-Json
$null = $LzProdOU.OrganizationalUnit.Id 
Write-Host "    - ${LzProdOUName} created"

Write-Host "Processing Complete"
