Write-Host "Test_CICD_Projects_Update.ps1 - V1.0.0"
Write-Host "This script updates the CodeBuild Projects in the Test account."
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

$LzTestAcctName = "${LzOrgCode}Rev"
$LzTestAcctNameInput = Read-Host "Enter the Test Account Name (default: ${LzTestAcctName})"
if($LzTestAcctNameInput -ne "") {
    $LzTestAcctName = $LzTestAcctNameInput
}
$LzTestAccessRoleProfile = $LzTestAcctName + "AccessRole"

$LzGitHubRepo = "https://github.com/myorg/myrepo.git"
$LzGitHubRepoInput = Read-Host "Enter your GitHub Repo URL (example: ${LzGitHubRepo})"
if($LzGitHubRepoInput -ne "") {
    $LzGitHubRepo = $LzGitHubRepoInput
}

$LzCodeBuildTestCICDStackName="Testcicd"
$LzCodeBuildTestCICDStackNameInput = Read-Host "Enter your TestCICD CodeBuild project name (default: ${LzCodeBuildTestCICDStackName})"
if($LzCodeBuildTestCICDStackNameInput -ne "") {
    $LzCodeBuildTestCICDStackName = $LzCodeBuildTestCICDStackNameInput
}

$LzCodeBuildTestDeleteStackName="Testdelete"
$LzCodeBuildTestDeleteStackNameInput = Read-Host "Enter your TestDelete CodeBuild project name (default: ${LzCodeBuildTestDeleteStackName})"
if($LzCodeBuildTestDeleteStackNameInput -ne "") {
    $LzCodeBuildTestDeleteStackName = $LzCodeBuildTestDeleteStackNameInput
}

Write-Host "Please Review and confirm the following:"
Write-Host "    OrgCode: $LzOrgCode"
Write-Host "    AWS CLI Management Account Profile: $LzMgmtProfile"
Write-Host "    AWS Region: ${LzRegion}"
Write-Host "    Test Account name: ${LzTestAcctName}"
Write-Host "    GitHub Repo URL: ${LzGitHubRepo}"
Write-Host "    TestCICD CodeBuild project name: ${LzCodeBuildTestCICDStackName}"
Write-Host "    TestDelete CodeBuild project name: ${LzCodeBuildTestDeleteStackName}"

$LzContinue = (Read-Host "Continue y/n") 
if($LzContinue -ne "y") {
    Write-Host "Exiting"
    Exit
}
Write-Host ""
Write-Host "Processing Starting"

# Test Account
Write-Host "Deploying TestCICD AWS CodeBuild project to ${LzTestAcctName} account."
sam deploy --stack-name $LzCodeBuildTestCICDStackName -t RevCICD.yaml --capabilities CAPABILITY_NAMED_IAM --parameter-overrides GitHubRepoParam=$LzGitHubRepo  --profile $LzTestAccessRoleProfile --region $LzRegion

Write-Host "Deploying TestDelete AWS CodeBuild project to ${LzTestAcctName} account."
sam deploy --stack-name $LzCodeBuildTestDeleteStackName -t RevDelete.yaml --capabilities CAPABILITY_NAMED_IAM --parameter-overrides GitHubRepoParam=$LzGitHubRepo  --profile $LzTestAccessRoleProfile --region $LzRegion
