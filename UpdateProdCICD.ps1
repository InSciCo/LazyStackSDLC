Write-Host "UpdateProdCICD.ps1 - V1.0.0"
Write-Host "This script updates the CodeBuild Projects in the Prod account."
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

$LzProdAcctName = "${LzOrgCode}Prod"
$LzProdAcctNameInput = Read-Host "Enter the Prod Account Name (default: ${LzProdAcctName})"
if($LzProdAcctNameInput -ne "") {
    $LzProdAcctName = $LzProdAcctNameInput
}
$LzProdAccessRoleProfile = $LzProdAcctName + "AccessRole"

$LzGitHubRepo = "https://github.com/myorg/myrepo.git"
$LzGitHubRepoInput = Read-Host "Enter your GitHub Repo URL (example: ${LzGitHubRepo})"
if($LzGitHubRepoInput -ne "") {
    $LzGitHubRepo = $LzGitHubRepoInput
}

$LzCodeBuildProdCICDStackName="prodcicd"
$LzCodeBuildProdCICDStackNameInput = Read-Host "Enter your ProdCICD CodeBuild project name (default: ${LzCodeBuildProdCICDStackName})"
if($LzCodeBuildProdCICDStackNameInput -ne "") {
    $LzCodeBuildProdCICDStackName = $LzCodeBuildProdCICDStackNameInput
}

Write-Host "Please Review and confirm the following:"
Write-Host "    OrgCode: $LzOrgCode"
Write-Host "    AWS CLI Management Account Profile: $LzMgmtProfile"
Write-Host "    AWS Region: ${LzRegion}"
Write-Host "    Prod Account name: ${LzProdAcctName}"
Write-Host "    GitHub Repo URL: ${LzGitHubRepo}"
Write-Host "    ProdCICD CodeBuild project name: ${LzCodeBuildProdCICDStackName}"

$LzContinue = (Read-Host "Continue y/n") 
if($LzContinue -ne "y") {
    Write-Host "Exiting"
    Exit
}
Write-Host ""
Write-Host "Processing Starting"

# Prod Account
Write-Host "Deploying ProdCICD AWS CodeBuild project to ${LzProdAcctName} account."
sam deploy --stack-name $LzCodeBuildProdCICDStackName -t ProdCICD.yaml --capabilities CAPABILITY_NAMED_IAM  --parameter-overrides GitHubRepoParam=$LzGitHubRepo --profile $LzProdAccessRoleProfile --region $LzRegion
