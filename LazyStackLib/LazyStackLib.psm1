#LazyStackLib.psm1

function Test-AwsProfileExists {
    param ([string]$profilename)
    $list = aws configure list-profiles
    $list -contains $profilename
}
function Get-IsRegionAvailable {
    param ([string]$mgmtAcctProfile, [string]$regionName)
    $regions = Invoke-Expression "aws ec2 describe-regions --all-regions --profile ${mgmtAcctProfile}" | ConvertFrom-Json
    $region = $regions.Regions | Where-Object RegionName -EQ $regionName
    return  $null -ne $region
}
function Read-AwsRegion {
    param ([string]$mgmtAcctProfile, [string]$prompt="Enter AWS Region", [string]$default, [int]$indent)
    $indentstr = " " * $indent
    if("" -ne $default) { $defstr = " (${default})"} else {$defstr = ""}
    do {
        $regionname = Read-String `
            -prompt "${prompt}${defstr}" `
            -default $default `
            -indent $indent
        $found = Get-IsRegionAvailable -mgmtAcctProfile $mgmtAcctProfile -regionName $regionname
        if(!$found) {
            Write-Host "${indentstr}Sorry, that region is not available. Please try again."
        }
    } until ($found)
    return $regionName
}
function Read-AwsProfileName {
    param ([string]$prompt, [string]$default, [int]$indent=0)
    Write-Host "default=" $default
    $indentstr = " " * $indent
    do {
        $inputvalue = (Read-String `
            -prompt $prompt `
            -default $default `
            -indent $indent) 

        $found = Test-AwsProfileExists -profilename $inputvalue
        if(!$found) {
            Write-Host "${indentstr}AWS AWS CLI Managment Account Profile ${inputvalue} Not Found!"        
            Write-Host "${indentstr}Please try again."
        }
    } until ($found)    
    return $inputvalue
}
 function Get-AwsOrgRootId{
    param([string]$mgmtAcctProfile)
    # Get LzRootId - note: Currently, there should only ever be one root.
    # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/list-roots.html
    [string]$output = aws organizations list-roots --profile $mgmtAcctProfile 2>&1
    $output = $output.Replace(" ", "")
    # Catch error by examining return
    if($output.Substring(2,5) -ne "Roots") {
        return  ""
    }
    $LzRoots = $output | ConvertFrom-Json 
    $LzRootId = $LzRoots.Roots[0].Id
    return $LzRootId
 }
function Get-TemplateParameters {
    param([string]$templatePath)
    if(Test-Path $templatePath) {
        #Read the yaml file and get the parameters
        $template = (Get-Content $templatePath | ConvertFrom-Yaml | ConvertTo-Json -Depth 100 | ConvertFrom-Json)
        $parameters = $template.Parameters 
        return $parameters
    } else {
        Write-Host "Warning: ${templatePath} was not found"
    }
}
function Get-SMF {
    param ([string]$filename="smf.yaml")

    if(Test-Path $filename) {
        # Read smf.yaml 
        # ConvertFrom-Yaml returns a HashTable
        # note: ConvertFrom-Json returns a PSCustomObject and doesn't preserve property order so we don't use it
        # We want a consistent format that preserves property order so we use a HashTable
        Write-Host " Loading existing SMF settings file."
        $org = Get-Content $filename | ConvertFrom-Yaml -ordered
        return $org
    } else {
        Write-Host " Creating new SMF settings file:"
        # Create default Settings object
        $OrgCode = Read-String `
                -prompt "Please enter OrgCode" `
                -required $true `
                -indent 4
        }        

    #AwsMgmtProfile 
    $default = $OrgCode + "Mgmt"
    $awsMgmtProfile = Read-AwsProfileName `
        -prompt "Enter AWS CLI Managment Account (default: ${default})" `
        -default $default `
        -indent 4

    $awsRegion = Read-AwsRegion $awsMgmtProfile -default "us-east-1" -indent 4

    $gitHubAcctName = Read-String `
        -prompt "    Enter your GitHub Management Acct Name"
    
    $gitHubOrgName = Read-String `
        -prompt "    Enter your GitHub Organization Name"

    $tutorialRepo = "https://github.com/${gitHubOrgName}/Petstore.git"
    $defmsg = Get-DefMessage -default $tutorialRepo
    $tutorialRepo = Read-String `
        -prompt "Tutorial Repo${defmsg}" `
        -default $tutorialRepo `
        -indent 4

    $utilRepo = "https://github.com/${gitHubOrgName}/LazyStackSMF.git"
    $defmsg = Get-DefMessage -default $utilRepo
    $utilRepo = Read-String `
        -prompt "LazyStack Util Repo${defmsg}" `
        -default $utilRepo `
        -indent 4


    $org = [ordered]@{
        $OrgCode = [ordered]@{
            AWS = [ordered]@{
            MgmtProfile=$awsMgmtProfile
            DefaultRegion=$awsRegion
                OrgUnits= @(
                    "DevOU"
                    "TestOU"
                    "ProdOU"
                )
            }
            Sources = @{
                GitHub = [ordered]@{
                    Type = "GitHub"
                    AcctName = $gitHubAcctName
                    OrgName = $gitHubOrgName
                }
            }
            Systems = [ordered]@{
                Tut = [ordered]@{
                    Description = "Tutorial System"
                    Accounts = [ordered]@{
                        Test = [ordered]@{
                            Type="Test"
                            Description="Test System Account"
                            Pipelines = [ordered]@{
                                Test_PR_Create = [ordered]@{
                                    Description = "Create PR Stack on Pull Request Creation"
                                    TemplatePath = "../LazyStackSMF/Test_CodeBuild_PR_Create.yaml"                               
                                    Region = $awsRegion
                                    TemplateParameters = [ordered]@{
                                        RepoParam = $tutorialRepo 
                                        UtilRepoParam = $utilRepo
                                    }
                                }
                                Test_PR_Merge = [ordered]@{
                                    Description = "Delete PR Stack on Pull Request Merge"
                                    TemplatePath = "../LazyStackSMF/Test_CodeBuild_PR_Merge.yaml"
                                    Region = $awsRegion
                                    TemplateParameters = [ordered]@{
                                        RepoParam = $tutorialRepo 
                                    }
                                }
                            }
                        }
                        Prod = [ordered]@{
                            Type="Prod"
                            Description="Prod System Account"
                            Pipelines = [ordered]@{
                                Prod_PR_Merge = [ordered]@{
                                    Description = "Update Production Stack on Pull Request Merge"
                                    TemplatePath = "../LazyStackSMF/Prod_CodeBuild_PR_Merge.yaml"
                                    Region = $awsRegion
                                    TemplateParameters = [ordered]@{
                                        RepoParam = $tutorialRepo 
                                        UtilRepoParam = $utilRepo
                                        ProdStackNameParam = $awsRegion + "-petstore"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    return $org
}
function Get-Indent{
    param ([int]$indent)
    $indentstr =  " "*$indent
    return $indentstr
}
function Set-SMF {
    param ($settings, [string]$filename="smf.yaml")
    if($null -eq $settings ) {
        #fatal error, terminate calling script
        Write-Host "Error: Set-Settings settings parameter can not be null"
        exit
    }
    Set-Content -Path $filename -Value ($settings | ConvertTo-Yaml) 
}
function Write-SMF {
    param ([PSCustomObject]$settings)
    Write-Host  ($settings | ConvertTo-Yaml) 
}
function Read-Repo {
    param ([string]$prompt, [string]$owner, [string]$reponame, [bool]$exists=$false, [int]$indent=0)
    $indentstr = " " * $indent
    do {
        $defmsg = Get-DefMessage -default $owner 
        $owner = Read-String `
            -prompt ($indentStr + $prompt + "Owner${defmsg}") `
            -default $owner
        $defmsg = Get-DefMessage -default $reponame
        $reponame = Read-String `
            -prompt ($indentStr + $prompt + "Name${defmsg}") `
            -default $reponame

        $repo = ($owner + "/" + $repoName)
        
        $found = Get-GitHubRepoExists $repo
        
        $ok = ($found -eq $exists) 
        if(!$ok) {
            if($exists) {
                Write-Host "${indentstr}Sorry, that reposiory does not exists. Please try again"
            } else {
                Write-Host "${indentstr}Sorry, that repository exists. Please try again."
            }
        } 
    } until ($ok)
    return  $owner, $reponame, $repo
}
function Set-GhSession {
    param( [bool]$exitOnError=$true)
    $found = Test-Path "GitAdminToken.pat"
    if(!$found)  {
        Write-Host "Missing GitAdminToken.pat file." 
        exit
    }
    [string]$output = (Get-Content GitAdminToken.pat | gh auth login --with-token 2>&1)
    if($null -ne $output) {
        $firstToken = $output.split(' ')[0]
        if($firstToken -eq "error") {
            if($exitOnError) {
                Write-Host "gh could not authenticate with token provided."
                exit
            } else {
                return $false
            }
        }
    }
    # gh auth status
    return $true
}
function Get-GitHubRepoURL {
    param ([string]$reponame)
    return  "https://github.com/" + $reponame + ".git"
}
function Get-GitHubRepoExists {
    param ([string]$reponame)
    [string]$output = (gh repo view $reponame)  2>&1
    $output = $output.Substring(0,5)
    # valid responses will start with "name: ", anything else is an error
    return  ($output -eq "name:")
}
function New-Repository {
    param (
        [string]$orgName
    )
    Write-Host "    Repository creation options:
    1. Create Tutorial Stack (ex: gh repo create ${orgName}/PetStore -p InSciCo/PetStore -y -private)
    2. Create from repository template (ex: gh repo create ${orgName}/newrepo -p ${orgName}/templaterepo -y -private)
    3. Reference an existing repository"
    $repoOption = Read-MenuSelection -min 1 -max 3 -indent 4 -options "q"
    if($repoOption -eq -1) {
        return $false, ""
    }

    # Login to GitHub
    Set-GhSession

    switch($repoOption) {

        1 {
            $sourceRepo = "InSciCo/PetStore"
            $targetOwner=$orgName
            $defmsg = Get-DefMessage -default "PetStore"
            $targetOwner, $targetReponame, $targetRepo = Read-Repo `
                -prompt "New Repository" `
                -owner $orgName `
                -reponame "PetStore" `
                -indent 4 


            Write-Host "    This option creates a LazyStack PetStore tutorial repository in your GitHub Organization"
            Write-Host "    Source Repository:" $sourceRepo 
            Write-Host "    New Repository:" $targetRepo
            $ghParameters = "--confirm --private"
        }
        2 {
            Write-Host "    This option creates a new repository from a template repository"
            $owner, $reponame, $sourceRepo = Read-Repo `
                -prompt "Source Template Repository " `
                -owner $orgName `
                -exists $true `
                -indent 4

            $targetOwner, $targetReponame, $targetRepo = Read-Repo `
                -prompt "New Repository " `
                -owner $orgName `
                -exists $false `
                -indent 4

            $ghParameters = "--confirm --private"
        }
        3 {
            Write-Host "This option configures the stack to use an existing repository"
            $targetOwner, $targetReponame, $targetRepo = Read-Repo `
                -prompt "Existing Repository " `
                -owner $orgName `
                -exists $true `
                -indent 4
        }
    }

    if($repoOption -ne 3) {
        $defmsg = Get-DefMessage -default $ghParameters
        $ghParameters = Read-String `
            -prompt "gh command parameters${defmsg}" `
            -default $ghParameters `
            -indent 4                 

        switch($repoOption) {
            1 {
                #Write-Host "PRINT: gh repo create $targetRepo -Pipeline $SourceRepo  $ghParameters"
                $output = Invoke-Expression "gh repo create $targetRepo --Pipeline $SourceRepo $ghParameters"
                #remove clone created in sub folder

                if(Test-Path $targetReponame) {
                    Write-Host "    Removing temporary clone from settings folder"
                    Remove-Item $TargetReponame -Recurse -Force
                }
            }
            2 {
                #Write-Host "PRINT: gh repo create $targetRepo --Pipeline $SourceRepo  $ghParameters"
                $output = Invoke-Expression "gh repo create $targetRepo --Pipeline $SourceRepo $ghParameters"
                #remove clone created in sub folder
                if(Test-Path $targetReponame) {
                    Write-Host "    Removing temporary clone from settings folder"
                    Remove-Item $targetReponame -Recurse -Force
                }                        
            }
        }
        if(!(Get-GitHubRepoExists -reponame $targetRepo)) {
            Write-Host "    Error: The new repository was not created successfully on GitHub"
            return $false, ""
        }            
    }
    
    return $true, $targetRepo   
}



function New-AwsSysAccount {
    param (
        [string]$LzMgmtProfile,
        [string]$LzRootId,
        [string]$LzOrgUnitId, 
        [string]$LzAcctName, 
        [string]$LzIAMUserName,
        [string]$LzRootEmail,
        [string]$LzRegion,
        [int]$indent
    )
    $indentstr = " " * $indent

    #Check if accont already exists 


    # Create Test Account  -- this is an async operation so we have to poll for success
    # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/create-account.html
    Write-Host "Creating System Account: ${LzAcctName}" 

    $LzAcct = aws organizations create-account --email $LzRootEmail --account-name $LzAcctName --profile $LzMgmtProfile | ConvertFrom-Json
    $LzAcctId = $LzAcct.CreateAccountStatus.Id

    # poll for success
    # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/describe-create-account-status.html
    $LzAcctCreationCheck = 1
    do {
        Write-Host "    - Checking for successful account creation. TryCount=${LzAcctCreationCheck}"
        Start-Sleep -Seconds 5
        $LzAcctStatus = aws organizations describe-create-account-status --create-account-request-id $LzAcctId --profile $LzMgmtProfile | ConvertFrom-Json
        $LzAcctCreationCheck = $LzAcctCreationCheck + 1
    }
    while ($LzAcctStatus.CreateAccountStatus.State -eq "IN_PROGRESS")

    if($LzAcctStatus.CreateAccountStatus.State -ne "SUCCEEDED") {
        Write-Host $LzAcctStatus.CreateAccountStatus.FailureReason
        exit
    }

    $LzAcctId = $LzAcctStatus.CreateAccountStatus.AccountId
    Write-Host "    - ${LzAcctName} account creation successful. AccountId: ${LzAcctId}"


    # Check if account is in OU
    $LzOUChildren = aws organizations list-children --parent-id $LzOrgUnitID --child-type ACCOUNT --profile $LzMgmtProfile | ConvertFrom-Json 
    $LzOUChild = $LzOUChildren.Children | Where-Object Id -EQ $LzAcctId
    if($null -ne $LzOUChild) {
        Write-Host "${LzAcctName} already in ${LzOUName} so skipping account move."
    }
    else {
        # Move new Account to OU
        # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/move-account.html
        Write-Host "    - Moving ${LzAcctName} account to ${LzOUName} organizational unit"
        $null = aws organizations move-account --account-id $LzAcctId --source-parent-id $LzRootId --destination-parent-id $LzOrgUnitId --profile $LzMgmtProfile
    }

    <# 
    Reference: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_accounts_access.html
    When you create an account in your organization, in addition to the root user, 
    AWS Organizations automatically creates an IAM role that is by default named 
    OrganizationAccountAccessRole. 

    Reference: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-cli.html
    To use that role from the LzMgmtAdmin account we need a AWS profile with the following form:
    [profile LzDevAcessRole]
        role_arn = arn:aws:iam::123456789012:role/OrganizationAccountAccessRole
        source_profile = LzMgmtAdmin
    We use the aws configure command to set this up. 
    #>

    # Create AccessRole profile
    # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/configure/set.html
    $LzAccessRoleProfile = $LzAcctName + "AccessRole"
    Write-Host "Adding or Updating ${LzAccessRole} profile and associating it with the ${LzMgmtProfile} profile. "
    $null = aws configure set role_arn arn:aws:iam::${LzAcctId}:role/OrganizationAccountAccessRole --profile $LzAccessRoleProfile
    $null = aws configure set source_profile $LzMgmtProfile --profile $LzAccessRoleProfile
    $null = aws configure set region $LzRegion --profile $LzAccessRoleProfile 

    # Create Administrators Group for Test Account
    # Reference: https://docs.aws.amazon.com/cli/latest/userguide/cli-services-iam-new-user-group.html

    
    $awsgroups = aws iam list-groups --profile $LzAccessRoleProfile | ConvertFrom-Json
    $group = ($awsgroups.Groups | Where-Object GroupName -EQ "Administrators")
    if($null -eq $group) {
        Write-Host "Creating Administrators group in the ${LzAcctName} account."
        $null = aws iam create-group --group-name Administrators --profile $LzAccessRoleProfile
    } else {
        Write-Host "Administrators group exists in the ${LzAcctName} account."
    }

    # Add policies to Group
    $policies = aws iam list-attached-group-policies --group-name Administrators --profile $LzAccessRoleProfile
    # PowerUserAccess
    $policy = ($policies.AttachedPolicies  | Where-Object PolicyName -EQ AdministratorAccess) 
    if($null -ne $policy) {
        Write-Host "    - Policy AdministratorAccess already in Administrators group"
    } else {
        Write-Host "    - Adding policy AdministratorAccess"
        $LzGroupPolicyArn = aws iam list-policies --query 'Policies[?PolicyName==`AdministratorAccess`].{ARN:Arn}' --output text --profile $LzAccessRoleProfile 
        $null = aws iam attach-group-policy --group-name Administrators --policy-arn $LzGroupPolicyArn --profile $LzAccessRoleProfile
    }

    # Create User in Account
    $users = aws iam list-users --profile $LzAccessRoleProfile | ConvertFrom-Json
    $user = ($users.Users | Where-Object UserName -EQ $LzIAMUserName)
    if($null -ne $user) {
        Write-Host "IAM User ${LzIAMUserName} already in ${LzAcctName} account."
    } else {
        # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/iam/create-user.html
        Write-Host "Creating IAM User ${LzIAMUserName} in ${LzAcctName} account."
        $null = aws iam create-user --user-name $LzIAMUserName --profile $LzAccessRoleProfile | ConvertFrom-Json
        # Reference: https://docs.aws.amazon.com/cli/latest/userguide/cli-services-iam-new-user-group.html
        $LzPassword = "" + (Get-Random -Minimum 10000 -Maximum 99999 ) + "aA!"
        $null = aws iam create-login-profile --user-name $LzIAMUserName --password $LzPassword --password-reset-required --profile $LzAccessRoleProfile

        # Output Test Account Creds
        Write-Host "    - Writing the IAM User Creds into ${LzIAMUserName}_creds.txt"
        $nl = [Environment]::NewLine
        $LzOut = "User name,Password,Access key ID,Secret access key,Console login link${nl}"
        + $LzAcctName + "," + $LzPassword + ",,," + "https://${LzAcctId}.signin.aws.amazon.com/console"

        $LzOut > ${LzIAMUserName}_credentials.csv
    }

    # Add user to Group 
    $usergroups = aws iam list-groups-for-user --user-name $LzIAMUserName --profile $LzAccessRoleProfile | ConvertFrom-Json
    $group = ($usergroups.Groups | Where-Object GroupName -EQ Administrators)
    if($null -ne $group) {
        Write-Host "    - IAM User ${LzIAMUserName} is already in the Admnistrators group in the ${LzAcctName} account."
    } else {
        Write-Host "    - Adding the IAM User ${LzIAMUserName} to the Administrators group in the ${LzAcctName} account."
        $null = aws iam add-user-to-group --user-name $LzIAMUserName --group-name Administrators --profile $LzAccessRoleProfile
    }

    #update GitHub Personal Access Token
    $LzPat = Get-Content -Path GitCodeBuildToken.pat
    aws codebuild import-source-credentials --server-type GITHUB --auth-type PERSONAL_ACCESS_TOKEN --profile LzAccessRoleProfile --token $LzPAT

    return $true
}

function New-AwsSysAccount_old {
    param (
        [string]$LzMgmtProfile,
        [string]$LzOUName, 
        [string]$LzAcctName, 
        [string]$LzIAMUserName,
        [string]$LzRootEmail,
        [string]$LzRegion,
        [int]$indent
    )
    $indentstr = " " * $indent

    Write-Host "LzMgmtProfile=${LzMgmtProfile}"
    Write-Host "LzOUName=${LzOUName}"
    Write-Host "LzRootEmail=${LzRootEmail}"
    Write-Host "LzAcctName=${LzAcctName}"
    Write-Host "LzMgmtProfile=${LzMgmtProfile}"

    # Get LzRootId - note: Currently, there should only ever be one root.
    # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/list-roots.html
    $LzRoots = aws organizations list-roots --profile $LzMgmtProfile | ConvertFrom-Json
    $LzRootId = $LzRoots.Roots[0].Id 

    # Get Organizational Unit
    $LzOrgUnitsList = aws organizations list-organizational-units-for-parent --parent-id $LzRootId --profile $LzMgmtProfile | ConvertFrom-Json
    if($? -eq $false) {
        Write-Host "Error: Could not find ${LzOUName} Organizational Unit"
        exit
    }
    if($LzOrgUnitsList.OrganizationalUnits.Count -eq 0) {
        Write-Host "Error: There are no Organizational Units in root organization."
        exit 
    }

    $LzOrgUnit = $LzOrgUnitsList.OrganizationalUnits | Where-Object Name -eq $LzOUName
    if($? -eq $false)
    {
        Write-Host "Error: Could not find ${LzOUName} Organizational Unit"
        exit
    }

    $LzOrgUnitId = $LzOrgUnit.Id

    #Check if accont already exists 
    $LzAccounts = aws organizations list-accounts --profile $LzMgmtProfile | ConvertFrom-Json
    $LzAcct = ($LzAccounts.Accounts | Where-Object Name -EQ $LzAcctName)
    if($null -ne $LzAcct) {
        Write-Host "${LzAcctName} already exists. Skipping create."
        $LzAcctId = $LzAcct.Id
    }
    else {
        # Create Test Account  -- this is an async operation so we have to poll for success
        # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/create-account.html
        Write-Host "Creating System Account: ${LzAcctName}" 

        $LzAcct = aws organizations create-account --email $LzRootEmail --account-name $LzAcctName --profile $LzMgmtProfile | ConvertFrom-Json
        $LzAcctId = $LzAcct.CreateAccountStatus.Id

        # poll for success
        # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/describe-create-account-status.html
        $LzAcctCreationCheck = 1
        do {
            Write-Host "    - Checking for successful account creation. TryCount=${LzAcctCreationCheck}"
            Start-Sleep -Seconds 5
            $LzAcctStatus = aws organizations describe-create-account-status --create-account-request-id $LzAcctId --profile $LzMgmtProfile | ConvertFrom-Json
            $LzAcctCreationCheck = $LzAcctCreationCheck + 1
        }
        while ($LzAcctStatus.CreateAccountStatus.State -eq "IN_PROGRESS")

        if($LzAcctStatus.CreateAccountStatus.State -ne "SUCCEEDED") {
            Write-Host $LzAcctStatus.CreateAccountStatus.FailureReason
            exit
        }

        $LzAcctId = $LzAcctStatus.CreateAccountStatus.AccountId
        Write-Host "    - ${LzAcctName} account creation successful. AccountId: ${LzAcctId}"
    }

    # Check if account is in OU
    $LzOUChildren = aws organizations list-children --parent-id $LzOrgUnitID --child-type ACCOUNT --profile $LzMgmtProfile | ConvertFrom-Json 
    $LzOUChild = $LzOUChildren.Children | Where-Object Id -EQ $LzAcctId
    if($null -ne $LzOUChild) {
        Write-Host "${LzAcctName} already in ${LzOUName} so skipping account move."
    }
    else {
        # Move new Account to OU
        # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/move-account.html
        Write-Host "    - Moving ${LzAcctName} account to ${LzOUName} organizational unit"
        $null = aws organizations move-account --account-id $LzAcctId --source-parent-id $LzRootId --destination-parent-id $LzOrgUnitId --profile $LzMgmtProfile
    }

    <# 
    Reference: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_accounts_access.html
    When you create an account in your organization, in addition to the root user, 
    AWS Organizations automatically creates an IAM role that is by default named 
    OrganizationAccountAccessRole. 

    Reference: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-cli.html
    To use that role from the LzMgmtAdmin account we need a AWS profile with the following form:
    [profile LzDevAcessRole]
        role_arn = arn:aws:iam::123456789012:role/OrganizationAccountAccessRole
        source_profile = LzMgmtAdmin
    We use the aws configure command to set this up. 
    #>

    # Create AccessRole profile
    # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/configure/set.html
    $LzAccessRoleProfile = $LzAcctName + "AccessRole"
    Write-Host "Adding or Updating ${LzAccessRole} profile and associating it with the ${LzMgmtProfile} profile. "
    $null = aws configure set role_arn arn:aws:iam::${LzAcctId}:role/OrganizationAccountAccessRole --profile $LzAccessRoleProfile
    $null = aws configure set source_profile $LzMgmtProfile --profile $LzAccessRoleProfile
    $null = aws configure set region $LzRegion --profile $LzAccessRoleProfile 

    # Create Administrators Group for Test Account
    # Reference: https://docs.aws.amazon.com/cli/latest/userguide/cli-services-iam-new-user-group.html

    exit #bug?
    $awsgroups = aws iam list-groups --profile $LzAccessRoleProfile | ConvertFrom-Json
    $group = ($awsgroups.Groups | Where-Object GroupName -EQ "Administrators")
    if($null -eq $group) {
        Write-Host "Creating Administrators group in the ${LzAcctName} account."
        $null = aws iam create-group --group-name Administrators --profile $LzAccessRoleProfile
    } else {
        Write-Host "Administrators group exists in the ${LzAcctName} account."
    }

    # Add policies to Group
    $policies = aws iam list-attached-group-policies --group-name Administrators --profile $LzAccessRoleProfile
    # PowerUserAccess
    $policy = ($policies.AttachedPolicies  | Where-Object PolicyName -EQ AdministratorAccess) 
    if($null -ne $policy) {
        Write-Host "    - Policy AdministratorAccess already in Administrators group"
    } else {
        Write-Host "    - Adding policy AdministratorAccess"
        $LzGroupPolicyArn = aws iam list-policies --query 'Policies[?PolicyName==`AdministratorAccess`].{ARN:Arn}' --output text --profile $LzAccessRoleProfile 
        $null = aws iam attach-group-policy --group-name Administrators --policy-arn $LzGroupPolicyArn --profile $LzAccessRoleProfile
    }

    # Create User in Account
    $users = aws iam list-users --profile $LzAccessRoleProfile | ConvertFrom-Json
    $user = ($users.Users | Where-Object UserName -EQ $LzIAMUserName)
    if($null -ne $user) {
        Write-Host "IAM User ${LzIAMUserName} already in ${LzAcctName} account."
    } else {
        # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/iam/create-user.html
        Write-Host "Creating IAM User ${LzIAMUserName} in ${LzAcctName} account."
        $null = aws iam create-user --user-name $LzIAMUserName --profile $LzAccessRoleProfile | ConvertFrom-Json
        # Reference: https://docs.aws.amazon.com/cli/latest/userguide/cli-services-iam-new-user-group.html
        $LzPassword = "" + (Get-Random -Minimum 10000 -Maximum 99999 ) + "aA!"
        $null = aws iam create-login-profile --user-name $LzIAMUserName --password $LzPassword --password-reset-required --profile $LzAccessRoleProfile

        # Output Test Account Creds
        Write-Host "    - Writing the IAM User Creds into ${LzIAMUserName}_creds.txt"
        $nl = [Environment]::NewLine
        $LzOut = "User name,Password,Access key ID,Secret access key,Console login link${nl}"
        + $LzAcctName + "," + $LzPassword + ",,," + "https://${LzAcctId}.signin.aws.amazon.com/console"

        $LzOut > ${LzIAMUserName}_credentials.csv
    }

    # Add user to Group 
    $usergroups = aws iam list-groups-for-user --user-name $LzIAMUserName --profile $LzAccessRoleProfile | ConvertFrom-Json
    $group = ($usergroups.Groups | Where-Object GroupName -EQ Administrators)
    if($null -ne $group) {
        Write-Host "    - IAM User ${LzIAMUserName} is already in the Admnistrators group in the ${LzAcctName} account."
    } else {
        Write-Host "    - Adding the IAM User ${LzIAMUserName} to the Administrators group in the ${LzAcctName} account."
        $null = aws iam add-user-to-group --user-name $LzIAMUserName --group-name Administrators --profile $LzAccessRoleProfile
    }

    #update GitHub Personal Access Token
    $LzPat = Get-Content -Path GitCodeBuildToken.pat
    aws codebuild import-source-credentials --server-type GITHUB --auth-type PERSONAL_ACCESS_TOKEN --profile LzAccessRoleProfile --token $LzPAT

    return $true
}

function Get-ValidAwsStackName {
    param([string]$name)
    $chars = $name.toCharArray()
    $newName = New-Object char[] $chars.Length
    $i = 0

    foreach($c in $chars) {
        if( ($c -ge 'A' -And $c -le "Z")  -Or ($c -ge 'a' -And $c -le "z")  -Or ($c -ge '0' -And $c -le '9') -Or $c -eq "-" ) {
            $newName[$i] = $c
        } else  {
            $newName[$i] = '-'
        }
        $i += 1
    }
    $stackName = -Join $newName
    if($newName[0] -eq '-') {
        Write-Host "Error: Invalid StackName '${stackName}' Can't start with a '-' "
        exit
    }

    return $stackName
}

function Publish-Pipeline {
    param (
        [string]$LzCodeBuildStackName,
        [string]$LzCodeBuildTemplate,
        [string]$LzTemplateParameters,
        [string]$LzAwsProfile,
        [string]$LzRegion
    )

    #Check Params

    #Procesing
    sam deploy `
        --stack-name $LzCodeBuildStackName `
        -t $LzCodeBuildTemplate `
        --capabilities CAPABILITY_NAMED_IAM `
        --parameter-overrides $LzTemplateParameters `
        --profile $LzAwsProfile `
        --region $LzRegion
}
function Read-AccountType {
    param([string]$default, [int]$indent)
    $indentstr = " " * $indent
    $defmsg = Get-DefMessage -default $default
    Write-Host "${indentstr}1) System Test Account"
    Write-Host "${indentstr}2) System Production Account"
    $selection = Read-MenuSelection -min 1 -max 2 -prompt "Type ${defmsg}" -indent $indent -options ""
    switch($selection) {
        1 {return "Test"}
        2 {return "Prod"}
    }
}
function Write-System {
    param ([PSCustomObject]$object, [string]$curSystem, [int]$indent)
    $systemObj = $object.$curSystem 

    $indentstr = " " * $indent
    Write-Host "${indentstr}System:" $curSystem 
    Write-Host "${indentstr}  Description:" $systemObj.Description
    Write-Accounts $object.$curSystem ($indent + 2)
}
function Write-Accounts {
    param([PSCustomObject]$systemObj, [int]$indent)
    $indentstr = " " * $indent
    Write-Host "${indentstr}Accounts:"
    $systemObj.Accounts  | Get-Member -MemberType NoteProperty | ForEach-Object {
        Write-Account $systemObj.Accounts $_.Name ($indent + 2) 
    }    
}
function Write-Account {
    param([PSCustomObject]$object, [string]$curAccount, [int]$indent)
    $indentStr = " " * $indent
    $accountObj = $object.$curAccount
    Write-Host "${indentstr}Account:" $curAccount
    Write-Host "${indentstr}  OrgUnit:" $accountObj.OrgUnit 
    Write-Host "${indentstr}  Email:" $accountObj.Email 
    Write-Host "${indentstr}  IAMUser:" $accountObj.IAMUser
    Write-Pipelines $accountObj ($indent + 2)
}
function Write-Pipelines {
    param([PSCustomObject]$accountObj, [int]$indent )
    $indentstr = " " * $indent
    Write-Host "${indentstr}Pipelines:"
    $accountObj.Pipelines | Get-Member -MemberType NoteProperty | ForEach-Object {
        Write-Pipeline $accountObj.Pipelines $_.Name ($indent + 2)
    }
}
function Write-Pipeline {
    param([PSCustomObject]$object, [string]$curPipeline, [int]$indent) 
    $indentstr = " " * $indent 
    Write-Host "${indentstr}Pipeline:" $curPipeline 
    $curPipelineObj = $object.$curPipeline 
    Write-Host "${indentstr}  Template:" $curPipelineObj.TemplatePath
    Write-Host "${indentstr}  Description:" $curPipelineObj.Description
    Write-Host "${indentstr}  Region:" $curPipelineObj.Region
    Write-Host "${indentstr}  Parameters defined in template:"
    $fixedArgs = @("TemplatePath","Description", "Region")
    $templatePath = $curPipelineObj.TemplatePath
    if($null -ne $templatepath -And (Test-Path $templatePath)) {
        $parameters = Get-TemplateParameters $templatePath
        $parameters | Get-Member -MemberType NoteProperty | ForEach-Object {
            $name = $_.Name 
            if($fixedArgs -contains $name) {continue}

            # Check if the template parameter is in the Pipeline object; it may have been added after initial assignment.
            if(Get-PropertyExists $curPipelineObj $name) {
                Write-Host "${indentstr}   " ($name + ":") $curPipelineObj.$name
            } else {
                Write-Host "${indentstr}   " ($name + ": new parameter") 
            }
        }
    }
}
