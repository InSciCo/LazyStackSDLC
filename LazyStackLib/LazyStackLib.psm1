#LazyStackLib.psm1

function Get-LibVersion {
    "v1.0.0"
}
function Read-YesNo {
    Param ([string]$prompt, [boolean]$default=$true, [int]$indent)
    $indentstr = " " * $indent
    if ($default) { 
        $defmsg = " (Y/n)" 
    } else {
        $defmsg = " (y/N)"
    }
    do {
        $value = Read-Host "${indentstr}${prompt}${defmsg}"
        switch ($value) {
            "y" { return ,$true}
            "n" { return ,$false}
            "" {return, $default}
        }
    } until ($false)
}

function Read-Int {
    Param ([string]$prompt,[int]$default, [int]$min, [int]$max, [int]$indent)
    $indentstr = " " * $indent
    if($default -ge $min -And $default -le $max)  {
        $defmsg = "(default: ${default})"
    }

    do {
        $value = Read-Host ($indentstr + $prompt + $defmsg)
        if($value -eq ""){
            $intvalue = $default 
        }else{
            $intvalue = [int]$value
        }
        $isvalid = ($intvalue -ge $min -And $intvalue -le $max)
        if(!$isvalid) {
            Write-Host "${indentstr}Value must be between ${min} and ${max}. Please try again."
        }
    } until ($isvalid)
   
    return ,$intvalue
}

function Read-Email {
    Param ([string]$prompt,[string]$default, [int]$indent)
    $indentstr = " " * $indent
    Write-Host "${indentstr}Note: An email address can only be associated with one AWS Account."
    do {
        $email = Read-Host $prompt
        if($email -eq ""){
            $email = $default
        }
        try {
            $null = [mailaddress]$email
            Return, $email
        }
        catch {
            Write-Host "${indentstr}Invalid Email address entered! Please try again."
        }
    } until ($false)
}

function Read-String {
    Param ([string]$prompt, [string]$default, [int]$indent, [boolean]$required = $false)
    $indentstr = " " * $indent
    do {
        $value = Read-Host ($indentstr + $prompt)
        if($value -eq "") {
                $value = $default
        }
        if($required -And $value -eq "") {
            Write-Host "${indentstr}Value can't be empty. Please try again."
        } else { 
            return ,$value
        }
    } until ($false)
}

function Read-FileName {
    Param ([string]$prompt, [string]$default, [int]$indent, [boolean]$required = $false)
    $indentstr = " " * $indent
    do {
        $strinput = Read-String -prompt $prompt -default $default -indent $indent -required $required
        if($strinput -ne "" -And $required) {
            $found = [System.IO.File]::Exists($strinput)
            if(!$found) {
                Write-Host "${indentstr}Sorry, that file was not found. Please try again."
            }
        } else { return ,""}
    } until ($found)
    return , $strinput
}

function Read-OrgCode {
    Param ([string]$prompt, [string]$default, [int]$indent)
    $indentstr = " " * $indent
    do {
        $value = Read-Host ($indentstr + $prompt)
        if($value -eq "") {
            if($default -ne "") {
                $value = $default
            }
            if($value -eq "") {
                Write-Host "${indentstr}Value can't be empty. Please try again."
            }
        }
        if($value -ne "") {
            return ,$value
        }
    } until ($false)
}

function Get-DefaultString {
    param ([string]$current, [string]$default)
    if($current -ne "") {
        return ,$current
    }
    return ,$default
}

function Get-DefMessage {
    Param ([string]$current, [string]$default, [string]$example)
    if($current -ne "") {
        return, " (current: ${current})"
    }
    if($default -ne "") {
        return ," (default: ${default})"
    }
    if ($example -ne "") {
        return ," (example: ${example})"
    }
    return, ""
}

function Get-RepoShortName {
    param([string]$repourl)
    $urlparts=$repourl.Split('/')
    $LzRepoShortName=$urlparts[$urlparts.Count - 1]
    $LzRepoShortName=$LzRepoShortName.Split('.')
    $LzRepoShortName=$LzRepoShortName[0].ToLower()    
    return ,$LzRepoShortName
}

function Test-AwsProfileExists {
    param ([string]$profilename)
    $list = aws configure list-profiles
    $list -contains $profilename
}

function Get-IsRegionAvailable {
    param ([string]$mgmtAcctProfile, [string]$regionName)
    $regions = aws ec2 describe-regions --all-regions --profile $mgmtAcctProfile | ConvertFrom-Json
    $region = $regions.Regions | Where-Object RegionName -EQ $regionName
    return , $null -ne $region
}

function Read-AwsRegion {
    param ([string]$mgmtAcctProfile, [string]$prompt="Enter AWS Region", [string]$default, [int]$indent)
    $indentstr = " " * $indent1
    if("" -ne $default) { $defstr = "(${default})"} else {$defstr = ""}
    do {
        $regionname = Read-Host "${indentstr}${prompt}${defstr}"
        $found = Get-IsRegionAvailable -mgmtAcctProfile $mgmtAcctProfile -regionName $regionname
        if(!$found) {
            Write-Host "${indentstr}Sorry, that region is not available. Please try again."
        }
    } until ($found)
    return ,$regionName
}


function Get-LzOrgSettings {
    if(Test-Path OrgSettings.json) {
        # Read OrgSettings.json to create OrgSettings object
        $LzOrgSettings = Get-Content -Path OrgSettings.json | ConvertFrom-Json
    } else {
        # Create default Settings object
        $LzOrgSettings = [PSCustomObject]@{
            OrgCode=""
            AwsMgmtProfile=""
            GitHubAcctName=""
            GitHubOrgName=""
            LazyStackSmfUtilRepo=""
        }
    } 
    Return ,$LzOrgSettings
}

function Set-LzOrgSettings {
    param ([PSCustomObject]$settings)
    if($null -eq $settings ) {
        #fatal error, terminate calling script
        Write-Host "Error: Set-LzOrgSettings settings parameter can not be null"
        exit
    }
    Set-Content -Path OrgSettings.json -Value ($settings | ConvertTo-Json) 
}

function Get-LzSysSettings {
    param ([string]$syscode)
    if(Test-Path ${syscode}Settings.json) {
        # Read ${Sys}Settings.json to create SysSettings object
        $LzSysSettings = Get-Content -Path ${syscode}Settings.json | ConvertFrom-Json
    } else {
        # Create default Settings object
        $LzSysSettings = [PSCustomObject]@{
            SysCode=$syscode
            TestAccountEmail = ""
            ProdAccountEmail = ""
            RepoOption = 1
            SourceRepo = ""
            TargetRepo = ""
            RepoShortName = ""
            TestPrCreateTemplate = ""
            TestPrMergeTemplate = ""
            ProdPrMergeTemplate = ""
            ProdStackName = ""
            DefaultRegion = ""
        }
    } 
    Return $LzSysSettings
}

function Set-LzSysSettings {
    param ([PSCustomObject]$settings)
    if($null -eq $settings ) {
        #fatal error, terminate calling script
        Write-Host "Error: Set-LzOrgSettings settings parameter can not be null"
        exit
    }
    $SysCode = $settings.SysCode
    Set-Content -Path ${SysCode}Settings.json -Value ($settings | ConvertTo-Json) 
}

function Set-GhSession {
    $found = [System.IO.File]::Exists("GitAdminToken.pat")
    if(!$found)  {
        Write-Host "Missing GitAdminToken.pat file." 
        exit
    }
    [string]$output = (Get-Content GitAdminToken.pat | gh auth login --with-token) 2>&1 
    if($null -ne $output) {
        $firstToken = $output.split(' ')[0]
        if($firstToken -eq "error") {
            Write-Host "gh could not authenticate with token provided."
            exit
        }
    }
    gh auth status
}

function Get-GitHubRepoURL {
    param ([string]$reponame)
    return , "https://github.com/" + $reponame + ".git"
}

function Get-GitHubRepoExists {
    param ([string]$reponame)
    [string]$output = (gh repo view $reponame)  2>&1
    $output = $output.Substring(0,5)
    # valid responses will start with "name: ", anything else is an error
    return , ($output -eq "name:")
}
function Set-GitHubRepository {
    param ([string]$targetRepo, [string]$sourceRepo, [int]$repoOption)

    switch($repoOption) {
        
        1 # Create from repository template
        {
            if(!(Get-GitHubRepoExists -reponame $LzSysSettings.TargetRepo)) {

                if(!(Get-GitHubRepoExists -reponame $LzSysSettings.SourceRepo)) {
                    Write-Host "Error: The specified source repo does not exist on GitHub"
                    exit
                }    
                # We have a source and no target so create target        
                gh repo create $LzSysSettings.SourceRepo -p $LzSysSettings.TargetRepo -y -private --private

                if(!(Get-GitHubRepoExists -reponame $LzSysSettings.TargetRepo)) {
                    Write-Host "Error: The new repository was not created successfully on GitHub"
                    exit
                }            
            }
        }
        2 # Fork a repository
        {
            if(!(Get-GitHubRepoExists -reponame $LzSysSettings.TargetRepo)) {

                if(!(Get-GitHubRepoExists -reponame $LzSysSettings.SourceRepo)) {
                    Write-Host "Error: The specified source repo does not exist on GitHub"
                    exit
                }            
                gh repo fork $LzSysSettings.SourceRepo --clone=false 

                if(!(Get-GitHubRepoExists -reponame $LzSysSettings.TargetRepo)) {
                    Write-Host "Error: The new repository was not created successfully on GitHub"
                    exit
                }            
            }
        }
        3 # Reference an existing repository
        {
            if(!(Get-GitHubRepoExists -reponame $LzSysSettings.TargetRepo)) {
                Write-Host "Error: The specified target repo does not exist"
                exit
            }
        }
    }
   
}

function New-LzSysAccount {
    param (
        [PSCustomObject]$LzMgmtProfile,
        [string]$LzOUName, 
        [string]$LzAcctName,
        [string]$LzIAMUserName,
        [string]$LzRootEmail,
        [string]$LzRegion
    )
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

    exit
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

    return ,$true
}
function Publish-LzCodeBuildProject {
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
