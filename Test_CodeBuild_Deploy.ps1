Write-Host "Test_CodeBuild_Deploy.ps1 - V1.0.0"
Write-Host "This script deploys two CodeBuild project stacks to a System Test Account."
Write-Host "   - Test_CodeBuild_Create.yaml defines the first CodeBuild project stack"
Write-Host "   - Test_CodeBuild_Merge.yaml defines the second CodeBuild project stack"
Write-Host "Each project is associated with a GitHub repository containing a serverless application stack."
Write-Host ""
Write-Host "Test_CodeBuild_Create.yaml defines a CodeBuild project stack that builds, tests and publishes"
Write-Host "an application stack when a Pull Request is created or updated in the GitHub repository."
Write-Host "The published stack is called the PR stack. The stack is named based on the PR branch name."
Write-Host ""
Write-Host "Test_CodeBuild_Merge.yaml defines a CodeBuild project stack that deletes an application stack"
Write-Host "when a Pull Request is merged in the GitHub application repository."
Write-Host ""
Write-Host "Note: Press return to accept a default values."

$LzOrgCode = (Read-Host "Enter your OrgCode")

$LzRegion = ""
do {
    $LzMgmtProfile = "${LzOrgcode}Mgmt"
    $LzMgmtProfileInput = (Read-Host "Enter your AWS CLI Management Account Profile (default: ${LzOrgCode}Mgmt)")
    
    if($null -eq $LzMgmtProfileInput) {
        $LzMgmtProfile = $LzMgmtProfileInput
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

do {
    $LzSysCode = Read-Host "Enter the SysCode (ex: Pet)"
    if($LzSysCode -eq "") {
        Write-Host "System Code can't be empty. Please enter a value."
    }
}
until ($LzSysCode -ne "")

$LzTestAcctName = "${LzOrgCode}${LzSysCode}Test"
$LzTestAcctNameInput = Read-Host "Enter the System Test Account Name (default: ${LzTestAcctName})"
if($LzTestAcctNameInput -ne "") {
    $LzTestAcctName = $LzTestAcctNameInput
}

$LzTestAccessRoleProfile = $LzTestAcctName + "AccessRole"

$LzGitHubRepo = "https://github.com/myorg/myrepo.git"
$LzGitHubRepoInput = Read-Host "Enter the application stack's GitHub Repo URL (example: ${LzGitHubRepo})"
if($LzGitHubRepoInput -ne "") {
    $LzGitHubRepo = $LzGitHubRepoInput
}

#extract "myrepo" from "https://github.com/myorg/myrepo.git"
$urlparts=$LzGitHubRepo.Split('/')
$LzRepoShortName=$urlparts[$urlparts.Count - 1]
$LzRepoShortName=$LzRepoShortName.Split('.')
$LzRepoShortName=$LzRepoShortName[0]
$LzRepoShortNameInput = Read-Host "Enter your repo short name (default: ${LzRepoShortName})"
if($LzRepoShortNameInput -ne "") {
    $LzRepoShortName = $LzRepoShortNameInput
}

$LzCodeBuildPRCreateStackName= "${LzRepoShortName}_pr_create"
$LzCodeBuildPRDeleteStackName="${LzRepoShortName}_pr_merge"

Write-Host "Please review and confirm the following:"
Write-Host "    OrgCode: ${LzOrgCode}" 
Write-Host "    SysCode: ${LzSysCode}"
Write-Host "    AWS CLI Management Account Profile: ${LzMgmtProfile}"
Write-Host "    AWS Region: ${LzRegion}"
Write-Host "    System Test Account name: ${LzTestAcctName}"
Write-Host "    GitHub Repo URL: ${LzGitHubRepo}"
Write-Host "    Repo short name: ${LzRepoShortName}"
Write-Host "    CodeBuild PR Create project stack name: ${LzCodeBuildPRCreateStackName}"
Write-Host "    CodeBuild PR Merge project stack name: ${LzCodeBuildPRDeleteStackName}"

$LzContinue = (Read-Host "Continue y/n") 
if($LzContinue -ne "y") {
    Write-Host "Exiting"
    Exit
}
Write-Host ""
Write-Host "Processing Starting"

# Test Account
Write-Host "Deploying ${LzCodeBuildPRCreateStackName} AWS CodeBuild project to ${LzTestAcctName} account."
sam deploy --stack-name $LzCodeBuildTestCICDStackName -t Test_CodeBuild_Create.yaml --capabilities CAPABILITY_NAMED_IAM --parameter-overrides GitHubRepoParam=$LzGitHubRepo --profile $LzTestAccessRoleProfile --region $LzRegion

Write-Host "Deploying ${LzCodeBuildPRMergeStackName} AWS CodeBuild project to ${LzTestAcctName} account."
sam deploy --stack-name $LzCodeBuildTestDeleteStackName -t Test_CodeBuild_Merge.yaml --capabilities CAPABILITY_NAMED_IAM --parameter-overrides GitHubRepoParam=$LzGitHubRepo --profile $LzTestAccessRoleProfile --region $LzRegion

Write-Host "Processing Complete"