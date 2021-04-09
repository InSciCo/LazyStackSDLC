Write-Host "InstallCICD.ps1 - V1.0.0"
Write-Host "This script adds CodeBuild Projects to the Review and Prod accounts to implement CI/CD."
Write-Host "This script assumes you have created an organization with Dev, Review and Prod accounts"
Write-Host "using the other scripts provided in this project."
Write-Host "Note: Press return to accept a default value."

$LzRegion = ""
do {
    $LzMgmtProfile = Read-Host "Enter your AWS CLI Management Account Profile (default: ${LzOrgCode}Mgmt)"
    
    if($LzMgmtProfile -eq "") {
        $LzMgmtProfile = "${LzOrgCode}Mgmt"
    }

   $LzMgmtProfileKey = aws configure get profile.${LzMgmtProfile}.aws_access_key_id
    if($LzMgmtProfileKey -eq "") {
        Write-Host "Profile ${LzMgmtProfile} not found or not configured with Access Key"
        $LzMgmtProfileExists = $false
    }
    else  {
        $LzMgmtProfileExists = $true
        # Grab region in managment profile as default for new IAM User
        $LzRegion = aws configure get profile.${LzMgmtProfile}.region
    }

    # Make sure LzMgmtProfile is associated with an IAM User in an Account belonging to an Organization
    $null = aws organizations describe-organization --profile $LzMgmtProfile
    if($? -eq $false) {
        Write-Host "${LzMgmtProfile} profile is associated with an IAM User not administering an Organization."
        Exit
    }
}
until ($LzMgmtProfileExists)

if ($LzRegion -eq "") {
    $LzRegion = "us-east-1"
}

$LzRegionInput = Read-Host "Enter Region (default ${LzRegion})"
if($LzRegionInput -ne "") {
    $LzRegion = $LzRegionInput
}

$LzReviewAcctName = "${LzOrgCode}Rev"
$LzReviewAcctNameInput = Read-Host "Enter the Review Account Name (default: ${LzReviewAcctName})"
if($LzReviewAcctNameInput -ne "") {
    $LzReviewAcctName = $LzReviewAcctNameInput
}
$LzReviewAccessRoleProfile = $LzReviewAcctName + "AccessRole"

$LzProdAcctName = "${LzOrgCode}Prod"
$LzProdAcctNameInput = Read-Host "Enter the Prod Account Name (default: ${LzProdAcctName})"
if($LzProdAcctNameInput -ne "") {
    $LzProdAcctName = $LzProdAcctNameInput
}
$LzProdAccessRoleProfile = $LzProdAcctName + "AccessRole"

# Review Account
Write-Host "Deploying ReviewCICD AWS CodeBuild project to ${LzReviewAcctName} account."
sam deploy --stack-name reviewcicd -t RevCICD.yaml --capabilities CAPABILITY_NAMED_IAM --profile $LzReviewAccessRoleProfile --region $LzRegion
Write-Host "Deploying ReviewDelete AWS CodeBuild project to ${LzReviewAcctName} account."
sam deploy --stack-name reviewdelete -t RevDelete.yaml --capabilities CAPABILITY_NAMED_IAM --profile $LzReviewAccessRoleProfile --region $LzRegion

# Prod Account
Write-Host "Deploying ProdCICD AWS CodeBuild project to ${LzProdAcctName} account."
sam deploy --stack-name prodcicd -t ProdCICD.yaml --capabilities CAPABILITY_NAMED_IAM --profile $LzProdAccessRoleProfile --region $LzRegion

