#LazyStackLib.psm1

function Get-LibVersion {
    return "v1.0.0"
}
function Read-YesNo {
    Param ([string]$prompt, [boolean]$default=$true, [int]$indent)
    $indentstr = " " * $indent
    do {
        if ($default) { 
            $defmsg = " (Y/n)" 
        } else {
            $defmsg = " (y/N)"
        }
        $value = Read-Host ($indentstr + $prompt + $defmsg)
        switch ($value) {
            "y" { return ,$true}
            "n" { return ,$false}
            "" {return, $default}
        }
    } until ($false)
}

function Read-Email {
    Param ([string]$prompt, [int]$indent)
    $indentstr = " " * $indent
    Write-Host "${indentstr}Note: An email address can only be associated with one AWS Account."
    do {
        $email = Read-Host $prompt
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

function Test-AwsProfileExists {
    param ([string]$profilename)
    $list = aws configure list-profiles
    $list -contains $profilename
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
    Return $LzOrgSettings
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


function New-LzSysAccount {
    param (
        [PSCustomObject]$LzMgmtProfile,
        [string]$LzOUName, 
        [string]$LzAcctName,
        [string]$LzIAMUserName,
        [string]$LzLzRootEmail
    )

    # Get LzRootId - note: Currently, there should only ever be one root.
    # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/list-roots.html
    $LzRoots = aws organizations list-roots --profile $LzMgmtProfile | ConvertFrom-Json
    $LzRootId = $LzRoots.Roots[0].Id 

    # Get Organizational Unit
    $LzOrgUnitsList = aws organizations list-organizational-units-for-parent --parent-id $LzRootId --profile $LzMgmtProfile | ConvertFrom-Json
    if($? -eq $false) {
        Write-Host "Could not find ${LzOUName} Organizational Unit"
        return ,$false
    }
    if($LzOrgUnitsList.OrganizationalUnits.Count -eq 0) {
        Write-Host "There are no Organizational Units in root organization."
        return ,$false    
    }

    $LzOrgUnit = $LzOrgUnitsList.OrganizationalUnits | Where-Object Name -eq $LzOUName
    if($? -eq $false)
    {
        Write-Host "Could not find ${LzOUName} Organizational Unit"
        return ,$false
    }

    $LzOrgUnitId = $LzOrgUnit.Id

    # Create Test Account  -- this is an async operation so we have to poll for success
    # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/create-account.html
    Write-Host "Creating Test Account: ${LzAcctName}"
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
        return ,$false
    }

    $LzAcctId = $LzAcctStatus.CreateAccountStatus.AccountId
    Write-Host "    - ${LzAcctName} account creation successful. AccountId: ${LzAcctId}"


    # Move new Account to OU
    # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/move-account.html
    Write-Host "    - Moving ${LzAcctName} account to ${LzOUName} organizational unit"
    $null = aws organizations move-account --account-id $LzAcctId --source-parent-id $LzRootId --destination-parent-id $LzOrgUnitId --profile $LzMgmtProfile

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
    Write-Host "Adding ${LzAccessRole} profile and associating it with the ${LzMgmtProfile} profile. "
    $null = aws configure set role_arn arn:aws:iam::${LzAcctId}:role/OrganizationAccountAccessRole --profile $LzAccessRoleProfile
    $null = aws configure set source_profile $LzMgmtProfile --profile $LzAccessRoleProfile
    $null = aws configure set region $LzRegion --profile $LzAccessRoleProfile 

    # Create Administrators Group for Test Account
    # Reference: https://docs.aws.amazon.com/cli/latest/userguide/cli-services-iam-new-user-group.html
    Write-Host "Creating Administrators group in the ${LzAcctName} account."
    $null = aws iam create-group --group-name Administrators --profile $LzAccessRoleProfile

    # Add policies to Group
        # PowerUserAccess
    Write-Host "    - Adding policy AdministratorAccess"
    $LzGroupPolicyArn = aws iam list-policies --query 'Policies[?PolicyName==`AdministratorAccess`].{ARN:Arn}' --output text --profile $LzAccessRoleProfile 
    $null = aws iam attach-group-policy --group-name Administrators --policy-arn $LzGroupPolicyArn --profile $LzAccessRoleProfile

    # Create User in Account
    # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/iam/create-user.html
    Write-Host "Creating IAM User ${LzIAMUserName} in ${LzAcctName} account."
    $null = aws iam create-user --user-name $LzIAMUserName --profile $LzAccessRoleProfile | ConvertFrom-Json
    # Reference: https://docs.aws.amazon.com/cli/latest/userguide/cli-services-iam-new-user-group.html
    $LzPassword = "" + (Get-Random -Minimum 10000 -Maximum 99999 ) + "aA!"
    $null = aws iam create-login-profile --user-name $LzIAMUserName --password $LzPassword --password-reset-required --profile $LzAccessRoleProfile

    # Add user to Group 
    Write-Host "    - Adding the IAM User ${LzIAMUserName} to the Administrators group in the ${LzAcctName} account."
    $null = aws iam add-user-to-group --user-name $LzIAMUserName --group-name Administrators --profile $LzAccessRoleProfile

    # Output Test Account Creds
    Write-Host "    - Writing the IAM User Creds into ${LzIAMUserName}_creds.txt"
    $nl = [Environment]::NewLine
    $LzOut = "Account Name: ${LzAcctName}${nl}"  `
    + "Account Console: https://${LzAcctId}.signin.aws.amazon.com/console${nl}" `
    + "IAM User: ${LzIAMUserName}${nl}" `
    + "Temporary Password: ${LzPassword}${nl}" `
    + "Please login, you will be required to reset your password." `
    + "Please login as soon as possible." 

    $LzOut > ${LzIAMUserName}_creds.txt

    #update GitHub Personal Access Token
    $LzPat = Get-Content -Path GitCodeBuildToken.pat
    aws codebuild import-source-credentials --server-type GITHUB --auth-type PERSONAL_ACCESS_TOKEN --profile LzAccessRoleProfile --token $LzPAT

    return ,$true
}

function Publish-LzCodeBuildProject {
    param (
        [PSCustomObject]$Settings,
        [string]$LzRegion,
        [string]$LzAwsProfile,
        [string]$LzGitHubRepo,
        [string]$LzLazyStackSMF,
        [stirng]$LzRepoName,
        [string]$LzCodeBuildStackName,
        [string]$LzCodeBuildTemplate
    )

    #Check Params


    #Procesing
    Write-Host "Deploying ${LzCodeBuildStackName} AWS CodeBuild project to system account."
    sam deploy --stack-name $LzCodeBuildStackName -t $LzCodeBuildTemplate --capabilities CAPABILITY_NAMED_IAM --parameter-overrides GitHubRepoParam=$LzGitHubRepo GitHubLzSmfUtilRepoParam=$LzLazyStackSMF --profile $LzAwsProfile --region $LzRegion


}
