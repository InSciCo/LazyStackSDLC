Write-Host "UpdateRevCICD.ps1 - V1.0.0"
Write-Host "This script updates the CodeBuild Projects in the Review account."
Write-Host "Note: Press return to accept a default value."

$LzOrgCode = (Read-Host "Enter your OrgCode")

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

$LzGitHubRepo = "https://github.com/myorg/myrepo.git"
$LzGitHubRepoInput = Read-Host "Enter your GitHub Repo URL (example: ${LzGitHubRepo})"
if($LzGitHubRepoInput -ne "") {
    $LzGitHubRepo = $LzGitHubRepoInput
}

$LzCodeBuildReviewCICDStackName="reviewcicd"
$LzCodeBuildReviewCICDStackNameInput = Read-Host "Enter your ReviewCICD CodeBuild project name (default: ${LzCodeBuildReviewCICDStackName})"
if($LzCodeBuildReviewCICDStackNameInput -ne "") {
    $LzCodeBuildReviewCICDStackName = $LzCodeBuildReviewCICDStackNameInput
}

$LzCodeBuildReviewDeleteStackName="reviewdelete"
$LzCodeBuildReviewDeleteStackNameInput = Read-Host "Enter your ReviewDelete CodeBuild project name (default: ${LzCodeBuildReviewDeleteStackName})"
if($LzCodeBuildReviewDeleteStackNameInput -ne "") {
    $LzCodeBuildReviewDeleteStackName = $LzCodeBuildReviewDeleteStackNameInput
}

Write-Host "Please Review and confirm the following:"
Write-Host "    OrgCode: $LzOrgCode"
Write-Host "    AWS CLI Management Account Profile: $LzMgmtProfile"
Write-Host "    AWS Region: ${LzRegion}"
Write-Host "    Review Account name: ${LzReviewAcctName}"
Write-Host "    GitHub Repo URL: ${LzGitHubRepo}"
Write-Host "    ReviewCICD CodeBuild project name: ${LzCodeBuildReviewCICDStackName}"
Write-Host "    ReviewDelete CodeBuild project name: ${LzCodeBuildReviewDeleteStackName}"

$LzContinue = (Read-Host "Continue y/n") 
if($LzContinue -ne "y") {
    Write-Host "Exiting"
    Exit
}
Write-Host ""
Write-Host "Processing Starting"

# Review Account
Write-Host "Deploying ReviewCICD AWS CodeBuild project to ${LzReviewAcctName} account."
sam deploy --stack-name $LzCodeBuildReviewCICDStackName -t RevCICD.yaml --capabilities CAPABILITY_NAMED_IAM --parameter-overrides GitHubRepoParam=$LzGitHubRepo  --profile $LzReviewAccessRoleProfile --region $LzRegion
Write-Host "Deploying ReviewDelete AWS CodeBuild project to ${LzReviewAcctName} account."
sam deploy --stack-name $LzCodeBuildReviewDeleteStackName -t RevDelete.yaml --capabilities CAPABILITY_NAMED_IAM --parameter-overrides GitHubRepoParam=$LzGitHubRepo  --profile $LzReviewAccessRoleProfile --region $LzRegion
