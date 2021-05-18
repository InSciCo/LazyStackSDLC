# New-LzSystem.ps1 v1.0.0
# This script builds a fully configured System
$LzScriptPath = Split-Path $script:MyInvocation.MyCommand.Path
Import-Module (Join-Path -Path (Split-Path $script:MyInvocation.MyCommand.Path) -ChildPath LazyStackLib) -Force
if((Get-LibVersion) -ne "v1.0.0") {
    Write-Host "Error: Imported LazyStackSMF lib has wrong version!"
    exit
}

Write-Host "This script builds a fully configured System containing:
   - System Test Account belonging to the System Organizational Unit
   - System Production Account belonging to the Production Organizational Unit
   - GitHub Repository configuration (option to use existing repo or copy a repo template)
   - AWS CodeBuild projects in System Test account to publish and delete Pull Request stacks
   - AWS CodeBuild Project in System Production account to publish production stack
Note: Press return to accept a default value."
Write-Host ""
Write-Host "Authenticating gh with GitHub"
Set-GhSession
if(!$?) {
    Write-Host "Could not authenticate. Check that your GitHub Admin Personal Access Token is current."
    exit
}
# Check Defaults
$LzOrgSettings = Get-LzOrgSettings
if($LzOrgSettings.OrgCode -eq "") {
    Write-Host "Error: The OrgSettings.json OrgCode is not set."
    exit
}
$OrgCode = $LzOrgSettings.OrgCode 

if($LzOrgSettings.AwsMgmtProfile -eq "") {
    Write-Host "Error: The OrgSettings.json file AwsMgmtProfile is not set."
    exit
}

$LzMgmtProfile = $LzOrgSettings.AwsMgmtProfile
$LzMgmtProfileKey = (aws configure get profile.${LzMgmtProfile}.aws_access_key_id)
if($LzMgmtProfileKey -eq "") {
    Write-Host "Profile ${LzMgmtProfile} not found or not configured with Access Key"
    Write-Host "Please configure profile and run SetDefaults if you have not done so already."
    exit
}
$LzDefaultRegion = aws configure get profile.${LzMgmtProfile}.region

Write-Host ""
$SysCode = Read-String "Enter SysCode (example: Tut)" -required $true
$LzSysSettings = Get-LzSysSettings -syscode $SysCode

Write-Host ""
if("" -eq $LzSysSettings.DefaultRegion) {
    $LzSysSettings.DefaultRegion = $LzDefaultRegion
}
$LzSysSettings.DefaultRegion = Read-AwsRegion `
    -mgmtAcctProfile $LzMgmtProfile `
    -prompt "Enter Default AWS Region" `
    -default $LzSysSettings.DefaultRegion

Write-Host ""
$LzCreateTestAccount = Read-YesNo -prompt "Create System Test Account?"  -default $true
if($LzCreateTestAccount) {
    $defmsg = Get-DefMessage `
        -current $LzSysSettings.TestAccountEmail `
        -example "me+${OrgCode}${SysCode}Test@gmail.com"
    $LzSysSettings.TestAccountEmail = Read-Email `
        -prompt "Email for ${OrgCode}${SysCode}Test Account${defmsg}" `
        -default $LzSysSettings.TestAccountEmail
}

Write-Host ""
$LzCreateProdAccount = Read-YesNo -prompt "Create System Production Account?" -default $true
if($LzCreateProdAccount) {
    $defmsg = Get-DefMessage `
        -current $LzSysSettings.ProdAccountEmail `
        -example "me+${OrgCode}${SysCode}Prod@gmail.com"
    $LzSysSettings.ProdAccountEmail = Read-Email `
        -prompt "Email for ${OrgCode}${SysCode}Prod Account${defmsg}" `
        -default $LzSysSettings.ProdAccountEmail 
}

#CreateRepository Settings
Write-Host ""
$LzCreateRepository = Read-YesNo -prompt "Configure Serverless Stack Repository" -default $true
if($LzCreateRepository) {
    $LzGitHubOrgName = $LzOrgSettings.GitHubOrgName
    Write-Host "    Repository creation options:
    1. Create from repository template (ex: gh repo create ${LzGitHubOrgName}/PetStore -p InSciCo/PetStore -y -private)
    2. Fork a repository (ex: gh repo fork ${LzGitHubOrgName}/RepoName --clone=false)
    3. Reference an existing repository"
    
    $LzSysSettings.RepoOption = Read-Int `
        -prompt "Select an option" `
        -default $LzSysSettings.RepoOption `
        -min 1 -max 3 -indent 4

    #SourceRepo or TargetRepo
    if($LzCreateRepository -eq 1 -Or $LzCreateRepository -eq 2) {
        if($LzSysSettings.SourceRepo -eq "") {
            switch($LzSysSettings.RepoOption) {
                1 {$LzSysSettings.SourceRepo = "InSciCo/PetStore"}
                2 {$LzSysSettings.SourceRpo = "${LzGitHubOrgName}/RepoName"}
            }
        }

        #SourceRepo
        $defmsg = Get-DefMessage `
            -current $LzSysSettings.SourceRepo 
        $LzSysSettings.SourceRepo = Read-String `
            -prompt "GitHub source repository name${defmsg}" `
            -default $LzSysSettings.SourceRepo `
            -required $true -indent 4

        #TargetRepo
        $defmsg = Get-DefMessage `
            -current $LzSysSettings.TargetRepo `
            -example "${LzGitHubOrgName}/RepoName"
        $LzSysSettings.TargetRepo = Read-String `
            -prompt "GitHub new repository name${defmsg}" `
            -default $LzSysSettings.TargetRepo `
            -required $true -indent 4
    } else {
        #TargetRepo
        $defmsg = Get-DefMessage `
            -current $LzSysSettings.TargetRepo`
            -example "${LzGitHubOrgName}/RepoName"
        $LzSysSettings.TargetRepo = Read-String `
            -prompt "GitHub existing repository name${defmsg}" `
            -default $LzSysSettings.TargetRepo `
            -required $true -indent 4
    }
}

#ConfigureTestCICD Settings
Write-Host ""
$LzConfigureTestCICD = Read-YesNo -prompt "Configure Test Account CI/CD" -default $true
if($LzConfigureTestCICD) {
    #RepoShortName
    if($LzSysSettings.RepoShortName -eq "") {
        $LzSysSettings.RepoShortName =  Get-RepoShortName $LzSysSettings.TargetRepo        
    }
    $defmsg = Get-DefMessage `
        -current $LzSysSettings.RepoShortName `
        -example "petstore"
    $LzSysSettings.RepoShortName = Read-String `
        -prompt "Repository Shortname - used in CodeBuild project name construction${defmsg}" `
        -default $LzSysSettings.RepoShortName `
        -required $true -indent 4

    #TestPrCreateTemplate
    if($LzSysSettings.TestPrCreateTemplate -eq "") {
        $LzSysSettings.TestPrCreateTemplate = Join-Path $LzScriptPath "Test_CodeBuild_PR_Create.yaml"
    }
    $defmsg = Get-DefMessage `
        -current $LzSysSettings.TestPrCreateTemplate 
    $LzSysSettings.TestPrCreateTemplate = Read-String `
        -prompt "Pull Request Create Template${defmsg}" `
        -default $LzSysSettings.TestPrCreateTemplate `
        -required $true -indent 4

    #ProdPrMergeTemplate
    if($LzSysSettings.TestPrMergeTemplate -eq "") {
        $LzSysSettings.TestPrMergeTemplate = Join-Path $LzScriptPath "Test_CodeBuild_PR_Merge.yaml"
    }
    $defmsg = Get-DefMessage `
        -current $LzSysSettings.TestPrMergeTemplate 
    $LzSysSettings.TestPrMergeTemplate = Read-String `
        -prompt "Pull Request Merge Template${defmsg}" `
        -default $LzSysSettings.TestPrMergeTemplate `
        -required $true -indent 4
   
}

#ConfigureProdCICD Settings 
Write-Host ""
$LzConfigureProdCICD = (Read-YesNo -prompt "Configure Production Account CD" -default $true)
if($LzConfigureProdCICD) {
    #ProdPrMergeTemplate
    if($LzSysSettings.ProdPrMergeTemplate -eq "") {
        $LzSysSettings.ProdPrMergeTemplate = Join-Path $LzScriptPath "Prod_CodeBuild_PR_Merge.yaml"
    }
    $defmsg = Get-DefMessage `
        -current $LzSysSettings.ProdPrMergeTemplate
    $LzSysSettings.ProdPrMergeTemplate = Read-String `
        -prompt "Pull Request Merge Template${defmsg}" `
        -default $LzSysSettings.ProdPrMergeTemplate `
        -required $true -indent 4
   
    #ProdStackName
    if($LzSysSettings.ProdStackName -eq "") {
        $LzSysSettings.ProdStackName = $LzSysSettings.RepoShortName
    }
    $defmsg = Get-DefMessage `
        -current $LzSysSettings.ProdStackName
    $LzSysSettings.ProdStackName = Read-String `
        -prompt "Production Stack Name${defmsg}" `
        -default $LzSysSettings.ProdStackName `
        -required $true -indent 4
}

#Review Settings
Write-Host "
Please review and confirm the following:
    OrgCode: ${OrgCode}
    SysCode: ${SysCode}"
if($LzCreateTestAccount) {
    Write-Host "    Creating ${OrgCode}${SysCode}Test account with email" $LzSysSettings.TestAccountEmail
}
if($LzCreateProdAccount) {
    Write-Host "    Creating ${OrgCode}${SysCode}Prod account with email" $LzSysSettings.ProdAccountEmail
}

if($LzCreateRepository) {
    switch ($LzSysSettings.RepoOption) {
        1 { Write-Host "    Creating new repository" $LzSysSettings.TargetRepo "from" $LzSysSettings.SourceRepo }
        2 { Write-Host "    Forking new repository" $LzSysSettings.TargetRepo"from" $LzSysSettings.SourceRepo}
        3 { Write-Host "    Using existing repository" $LzSysSettings.TargetRepo }
    }
}

$testPrCreateStack = $LzSysSettings.RepoShortName + "-t-p-c"
$testPrMergeStack = $LzSysSettings.RepoShortName + "-t-p-m"
if($LzConfigureTestCICD) {
    Write-Host "    Deploying Test Account CI/CD CodeBuild Projects:"
    Write-Host "        Deploying" $testPrCreateStack "using" $LzSysSettings.TestPrCreateTemplate
    Write-Host "        Deploying" $testPrMergeStack "using" $LzSysSettings.TestPrMergeTemplate
}

$prodPrMergeStack = $LzSysSettings.RepoShortName + "-p-p-m"
if($LzConfigureProdCICD) {
    Write-Host "    Deploying Production Account CD CodeBuild Project:"
$prodPrMergeStack = $LzSysSettings.RepoShortName + "-p-p-m"
    Write-Host "        Deploying" $prodPrMergeStack "CodeBuild Project using" $LzSysSettings.TestPrMergeTemplate
    Write-Host "        Production stack name:" $LzSysSettings.ProdStackName
}
Write-Host ""
$LzContinue = Read-YesNo -prompt "Continue?" -default $true
if($LzContinue -ne "y") {
    $save = Read-YesNo -prompt "Save entered values in ${SysCode}Settings.json?" -default $true
    if($save) {
        Set-LzSysSettings -settings $LzSysSettings
    }
    Write-Host "Exiting"
    Exit
}
Write-Host "Updating ${SysCode}Settings.json file."
Set-LzSysSettings -settings $LzSysSettings

Write-Host "Processing"

#Create Repository
if($LzCreateRepository) {
    Set-GitHubRepository -targetRepo $LzSysSettings.TargetRepo -sourceRepo $LzSysSettings.SourceRepo
}

#Create System Test Account
if($LzCreateTestAccount) {
    New-LzSysAccount `
        -LzMgmtProfile $LzOrgSettings.AwsMgmtProfile `
        -LzOUName ($LzSysSettings.OrgCode + "TestOU") `
        -LzAcctName ($LzSysSettings.OrgCode + "Test") `
        -LzIAMUserName ($LzSysSettings.OrgCode + "TestIAM") `
        -LzRootEmail $LzSysSettings.TestAccountEmail `
        -LzRegion $LzSysSettings.DefaultRegion
}

#Create System Production Account
if($LzCreateProdAccount) {
    New-LzSysAccount `
        -LzMgmtProfile $LzOrgSettings.AwsMgmtProfile `
        -LzOUName ($LzSysSettings.OrgCode + "ProdOU") `
        -LzAcctName ($LzSysSettings.OrgCode + "Prod") `
        -LzIAMUserName ($LzSysSettings.OrgCode + "ProdIAM") `
        -LzRootEmail $LzSysSettings.TestAccountEmail `
        -LzRegion  $LzSysSettings.DefaultRegion
}

#Configure System Test Account CICD
if($LzConfigureTestCICD) {

    $codeBuildProjectStack = $LzSysSettings.RepoShortName + "-t-p-c"
    Write-Host "Deploying ${codeBuildProjectStack} AWS CodeBuild project to system account."

    $templateParameters = "--parameter-overrides" `
        + " GitHubRepoParam="  + (GitHubRepoURL -reponame $LzSysSettings.TargetRepo) `
        + " GitHubLzSmfUtilRepoParam=" + $OrgSettings.LazyStackSmfUtilRepo 

    Publish-LzCodeBuildProject `
        -LzCodeBuildStackName  $codeBuildProjectStack `
        -LzCodeBuildTemplate $LzSysSettings.TestPrCreateTemplate `
        -LzTemplateParameters $templateParameters `
        -LzAwsProfile $OrgSettings.AwsMgmtProfile `
        -LzRegion us-east-1
        #todo determine what we want to do with region!

    $codeBuildProjectStack = $LzSysSettings.RepoShortName + "-t-p-m"
    Write-Host "Deploying ${codeBuildProjectStack} AWS CodeBuild project to system account."

    Publish-LzCodeBuildProject `
        -LzCodeBuildStackName $codeBuildProjectStack `
        -LzCodeBuildTemplate $LzSysSettings.TestPrMergeTemplate `
        -LzTemplateParameters $templateParameters `
        -LzAwsProfile $OrgSettings.AwsMgmtProfile `
        -LzRegion us-east-1
        #todo determine what we want to do with region!
}

#Configure System Production Account CD
if($LzConfigureProdCICD) {

    $codeBuildProjectStack = $LzSysSettings.RepoShortName + "-p-p-m"
    Write-Host "Deploying ${codeBuildProjectStack} AWS CodeBuild project to system account."

    $templateParameters = "--parameter-overrides" `
        + " GitHubRepoParam=" + (GitHubRepoURL -reponame $LzSysSettings.TargetRepo) `
        + " ProdStackName=" + $LzSysSettings.ProdStackName `
        + " GitHubLzSmfUtilRepoParam= " + $OrgSettings.LazyStackSmfUtilRepo 

    Publish-LzCodeBuildProject `
        -LzCodeBuildStackName $codeBuildProjectStack `
        -LzCodeBuildTemplate $LzSysSettings.ProdPrMergeTemplate `
        -LzTemplateParameters $templateParameters `
        -LzAwsProfile $OrgSettings.AwsMgmtProfile `
        -LzRegion us-east-1
        #todo determine what we want to do with region!
}

Write-Host "Processing complete"
