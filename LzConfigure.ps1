# LzConfigure.ps1 v1.0.0
# We import lib in script directory with -Force each time to ensure lib version matches script version
# Performance is not an issue with these infrequently executed scripts
$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path 
Import-Module (Join-Path -Path $scriptPath -ChildPath LazyStackLib) -Force
Import-Module (Join-Path -Path $scriptPath -ChildPath LazyStackUI) -Force

$found = $false
Get-InstalledModule | foreach-Object{
    if($_.Name -eq "powershell-yaml"){
        $found = $true
    }
}
if(!$found){
    Write-Host "Powershell-Yaml is a required dependency. Please ensure you have updated to Powershell 7.1.3 & install the requried module with the command: `n  Install-Module powershell-yaml"
    Exit
}else{
    Write-Host "Powershell-Yaml Found: ${found}"
}

$indent = 1
Write-LzHost $indent  "LzConfigure.ps1 V1.0.0"
Write-LzHost $indent  "Use this script to setup and manage your LazyStackSMF Organization"

$settingsFile = "smf.yaml"

$smf = Get-SMF $settingsFile # this routine may prompt user for OrgCode and MgmtProfile
Set-SMF $smf #save the file
$orgCode = @($smf.Keys)[0]
Write-LzHost $indent "OrgCode:" $orgCode
$LzMgmtProfile = $smf.$orgCode.AWS.MgmtProfile
Write-LzHost $indent "AWS Management Account:" $LzMgmtProfile

#$smf | ConvertTo-Yaml 

Write-LzHost $indent "Checking AWS Configuration"
#AWS Organization - create if it doesn't exist
#Get-AwsOrgRootId return "" if org doesn't exist - reads from AWS Profiles
$awsOrgRootId = Get-AwsOrgRootId -mgmtAcctProfile $LzMgmtProfile

$indent += 2
if($awsOrgRootId -eq "") {
    Write-LzHost $indent  "- No AWS Organization Found for the" $LzMgmtProfile "account."
    Write-LzHost $indent  "- We need to create one to continue installation."
    $create = Read-YesNo -prompt "Create AWS Organization?" -indent $indent

    if(!$create) {
        Write-LzHost $indent  "- OK. We won't create an AWS Organization now. Rerun this script when you are ready to create an AWS organization."
        exit
    }

    $null = aws organizations create-organization --profile $LzMgmtProfile

    $awsOrgRootId = Get-awsOrgRootId -mgmtAcctProfile $LzMgmtProfile

    if($awsOrgRootId -eq "") {
        Write-LzHost $indent  "Error: Could not create AWS Organization. Check permissions of the" $LzMgmtProfile "account and try again."
        exit
    }
    Write-LzHost $indent  "- AWS Organization Created for the"$LzMgmtProfile "account."
} else {
    Write-LzHost $indent  "- Found AWS Organziation for the" $LzMgmtProfile "account." 
}


Write-LzHost $indent  "- AWS OrgUnits"
$indent += 2
#AWS Organizational Units - create ones that don't exist 
#read existing OUs
$ouList = aws organizations list-organizational-units-for-parent `
    --parent-id $awsOrgRootId `
    --profile $LzMgmtProfile `
        | ConvertFrom-Json


$ouIds = @{}
foreach($orgUnitName in $smf.$orgCode.AWS.OrgUnits) {
    $ou = $ouList.OrganizationalUnits | Where-Object Name -eq $orgUnitName
    if($null -eq $ou) {
        Write-LzHost $indent  "- Creating OrgUnit" $orgUnitName
        $ou = aws organizations create-organizational-unit `
        --parent-id $awsOrgRootId `
        --name $orgUnitName  `
        --profile $LzMgmtProfile `
        | ConvertFrom-Json
        
        $ouIds.Add($orgUnitName,$ou.Id)

        if($null -eq $ou) {
            Write-LzHost $indent  "Error: Could not create OU. Check permissions of the" $LzMgmtProfile "account and try again."
            exit
        }
    } else {
        Write-LzHost $indent  "- Found AWS OrgUnit" $orgUnitName
        $ouIds.Add($orgUnitName, $ou.ID)
    }
}
$indent -= 2

Write-LzHost $indent  " "
Write-LzHost $indent  "- Systems"

#Get list of accounts in organziation
$LzAccounts = aws organizations list-accounts --profile $LzMgmtProfile | ConvertFrom-Json
$indent += 2
foreach($sysCode in $smf.$orgCode.Systems.Keys) {
    Write-LzHost $indent  "- System:" $sysCode ("("+ $smf.$orgCode.Systems.$sysCode.Description +")")
    $system = $smf.$orgCode.Systems[$sysCode]

    $indent += 2
    Write-LzHost $indent  "- Accounts"
    $indent += 2
    foreach($acctName in $system.Accounts.Keys) {
        $awsAcct = $system.Accounts[$acctName]
        $acctType = $awsAcct.Type 
        $LzAcctName = $OrgCode + $sysCode + $acctName
        $LzRegion = $awsAcct.DefaultRegion
        if($null -eq $LzRegion -Or $LzRegion -eq "") {
            $LzRegion = $smf.AWS.DefaultRegion
            if($null -eq $LzRegion -Or $LzRegion -eq "") {
                $LzRegion = "us-east-1"
            }
        }
        Write-LzHost $indent  "- Account:" $LzAcctName
        $indent += 2
        #check if System Account already exists
        $LzAcct = ($LzAccounts.Accounts | Where-Object Name -EQ $LzAcctName)
        
        if($null -ne $LzAcct) {
            Write-LzHost $indent  "- Found AWS Account ${LzAcctName}"
            $LzAcctId = $LzAcct.Id
        }
        else { #create System Account
            # Check email for new account exists
            $email = $smf.$orgCode.Systems.$sysCode.Email
            if($null -eq $email -Or $email -eq "") {
                $email = Read-Email "Enter unique email for ${acctType} System Account" -indent $indent
            }

            # Create Test Account  -- this is an async operation so we have to poll for success
            # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/create-account.html
            Write-LzHost $indent  "- Creating System Account: ${LzAcctName}" 

            $LzAcct = aws organizations create-account --email $email --account-name $LzAcctName --profile $LzMgmtProfile | ConvertFrom-Json
            $LzAcctId = $LzAcct.CreateAccountStatus.Id

            # poll for success
            # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/describe-create-account-status.html
            $LzAcctCreationCheck = 1
            do { 
                Write-LzHost $indent  "- Checking for successful account creation. TryCount=${LzAcctCreationCheck}"
                Start-Sleep -Seconds 5
                $LzAcctStatus = aws organizations describe-create-account-status --create-account-request-id $LzAcctId --profile $LzMgmtProfile | ConvertFrom-Json
                $LzAcctCreationCheck = $LzAcctCreationCheck + 1
            }
            while ($LzAcctStatus.CreateAccountStatus.State -eq "IN_PROGRESS")

            if($LzAcctStatus.CreateAccountStatus.State -ne "SUCCEEDED") {
                Write-LzHost $indent  $LzAcctStatus.CreateAccountStatus.FailureReason
                exit
            }

            $LzAcctId = $LzAcctStatus.CreateAccountStatus.AccountId
            Write-LzHost $indent  "- ${LzAcctName} account creation successful. AccountId: ${LzAcctId}"

        }


        # Check if account is in OU
        $LzOrgUnitID = $ouIds[($acctType+"OU")]
        $LzOUChildren = aws organizations list-children --parent-id $LzOrgUnitID --child-type ACCOUNT --profile $LzMgmtProfile | ConvertFrom-Json 
        $LzOUChild = $LzOUChildren.Children | Where-Object Id -EQ $LzAcctId
        if($null -ne $LzOUChild) {
            Write-LzHost $indent  "- Account is in ${acctType} Organizational Unit."
        }
        else {
            # Move new Account to OU
            # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/move-account.html
            Write-LzHost $indent  "- Moving ${LzAcctName} account to ${acctType} Organizational Unit"
            $null = aws organizations move-account --account-id $LzAcctId --source-parent-id $awsOrgRootId --destination-parent-id $LzOrgUnitId --profile $LzMgmtProfile
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
        #note: This updates in place
        Write-LzHost $indent  "- Adding or Updating ${LzAccessRoleProfile} profile and associating it with the ${LzMgmtProfile} profile. "
        $null = aws configure set role_arn arn:aws:iam::${LzAcctId}:role/OrganizationAccountAccessRole --profile $LzAccessRoleProfile
        $null = aws configure set source_profile $LzMgmtProfile --profile $LzAccessRoleProfile
        $null = aws configure set region $LzRegion --profile $LzAccessRoleProfile 

        # Create Administrators Group for Test Account
        # Reference: https://docs.aws.amazon.com/cli/latest/userguide/cli-services-iam-new-user-group.html
        
        $awsgroups = aws iam list-groups --profile $LzAccessRoleProfile | ConvertFrom-Json
        $group = ($awsgroups.Groups | Where-Object GroupName -EQ "Administrators")
        if($null -eq $group) {
            Write-LzHost $indent  "- Creating Administrators group in the ${LzAcctName} account."
            $null = aws iam create-group --group-name Administrators --profile $LzAccessRoleProfile
        } else {
            Write-LzHost $indent  "- Found Administrators group in ${LzAcctName} account."
        }

        # Add policies to Group
        $policies = aws iam list-attached-group-policies --group-name Administrators --profile $LzAccessRoleProfile
        # PowerUserAccess
        $policy = ($policies.AttachedPolicies  | Where-Object PolicyName -EQ AdministratorAccess) 
        if($null -ne $policy) {
            Write-LzHost $indent  "- Found AdministratorAccess Policy in Administrators group"
        } else {
            Write-LzHost $indent  "- Adding AdministratorAccess Policy to Administrators group"
            $LzGroupPolicyArn = aws iam list-policies --query 'Policies[?PolicyName==`AdministratorAccess`].{ARN:Arn}' --output text --profile $LzAccessRoleProfile 
            $null = aws iam attach-group-policy --group-name Administrators --policy-arn $LzGroupPolicyArn --profile $LzAccessRoleProfile
        }

        # Create User in Account
        $LzIAMUserName = $LzAcctName
        $users = aws iam list-users --profile $LzAccessRoleProfile | ConvertFrom-Json
        $user = ($users.Users | Where-Object UserName -EQ $LzIAMUserName)
        if($null -ne $user) {
            Write-LzHost $indent  "- Found IAM User ${LzIAMUserName} in ${LzAcctName} account."
        } else {
            # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/iam/create-user.html
            Write-LzHost $indent  "- Creating IAM User ${LzIAMUserName} in ${LzAcctName} account."
            $null = aws iam create-user --user-name $LzIAMUserName --profile $LzAccessRoleProfile | ConvertFrom-Json
            # Reference: https://docs.aws.amazon.com/cli/latest/userguide/cli-services-iam-new-user-group.html
            $LzPassword = "" + (Get-Random -Minimum 10000 -Maximum 99999 ) + "aA!"
            $null = aws iam create-login-profile --user-name $LzIAMUserName --password $LzPassword --password-reset-required --profile $LzAccessRoleProfile

            # Output Test Account Creds
            Write-LzHost $indent  "- Writing the IAM User Credentialss into ${LzIAMUserName}_credentials.txt"
            $nl = [Environment]::NewLine
            $LzOut = "User name,Password,Access key ID,Secret access key,Console login link${nl}" `
            + $LzAcctName + "," + $LzPassword + ",,," + "https://${LzAcctId}.signin.aws.amazon.com/console"

            $LzOut > ${LzIAMUserName}_credentials.csv
        }

        # Add user to Group 
        $usergroups = aws iam list-groups-for-user --user-name $LzIAMUserName --profile $LzAccessRoleProfile | ConvertFrom-Json
        $group = ($usergroups.Groups | Where-Object GroupName -EQ Administrators)
        if($null -ne $group) {
            Write-LzHost $indent  "- Found IAM User ${LzIAMUserName} in the ${LzAcctName} Account Administrators group."
        } else {
            Write-LzHost $indent  "- Adding IAM User ${LzIAMUserName} to the ${LzAcctName} Account Administrators group."
            $null = aws iam add-user-to-group --user-name $LzIAMUserName --group-name Administrators --profile $LzAccessRoleProfile
        }

        #update GitHub Personal Access Token
        Write-LzHost $indent  "- Updating AWS CodeBuild GitHub Credentials"
        $fileprocessed = $false
        do {
            if(Test-Path "GitCodeBuildToken.pat") {
                $LzPat = Get-Content -Path GitCodeBuildToken.pat
                $null = aws codebuild import-source-credentials --server-type GITHUB --auth-type PERSONAL_ACCESS_TOKEN --profile $LzAccessRoleProfile --token $LzPAT
                $fileprocessed = $true
            } else {
                Write-LzHost $indent  "--------- Could not find GitCodeBuildToken.pat file! Please see install documentation"
                Write-LzHost $indent  "--------- on creating this file and then continue with this script. You may also stop"
                Write-LzHost $indent  "--------- running this script now and rerun it later after creating the .pat file."
                $ok= Read-YesNo "Continue?" -indent 8
                if(!$ok) {
                    exit
                }
            }
        } until ($fileprocessed)


        Write-LzHost $indent  ""
        $indent -= 2
    }
    $indent -= 4
}
$indent -= 4

$ok = Read-YesNo -prompt "Deploy Pipelines?" -indent $indent 
if(!$ok) {
    exit
}

Write-LzHost $indent  "PipeLine Deployments"
$indent += 2

#Pipeline Deployments
foreach($sysCode in $smf.$orgCode.Systems.Keys) {
    $system = $smf.$orgCode.Systems[$sysCode]

    foreach($acctName in $system.Accounts.Keys) {
        $awsAcct = $system.Accounts[$acctName]
        $acctType = $awsAcct.Type 
        $LzAcctName = $OrgCode + $sysCode + $acctName
        $LzRegion = $awsAcct.DefaultRegion
        if($null -eq $LzRegion -Or $LzRegion -eq "") {
            $LzRegion = $smf.AWS.DefaultRegion
            if($null -eq $LzRegion -Or $LzRegion -eq "") {
                $LzRegion = "us-east-1"
            }
        }

        $pipelines = $awsAcct.Pipelines
        foreach($pipelineName in $pipelines.Keys) {
            $pipeline = $pipelines[$pipelineName]
            Write-LzHost $indent  "- Pipeline:" $pipelineName "in Account " $acctName
            #Collection template parameters
            $region = $pipeline.Region 
            if($null -eq $region -Or $region -eq "") {
                $region = $LzRegion #default from account
            }
        
            $templateParams = ""
            if($null -ne $pipeline.TemplateParams) {
                foreach($propertyName in $pipeline.TemplateParams.Keys) {
                    $templateParams += (" " + $propertyName + "=" + '"' + $pipeline.TemplateParams.$propertyName + '" ')
                }
            }
        
            $LzAccessRoleProfile = $orgCode + $sysCode + $acctName + "AccessRole"
            $stackName = Get-ValidAwsStackName($pipelineName + "-" + $pipeline.Region) # replace non-alphanumeric characters with "-"
            $stackName = $stackName.ToLower()
            if($templateParams -eq "") {
                sam deploy `
                --stack-name $stackName `
                -t $pipeline.TemplatePath `
                --capabilities CAPABILITY_NAMED_IAM `
                --profile $LzAccessRoleProfile `
                --region $region           
            } else {
                sam deploy `
                --stack-name $stackName `
                -t $pipeline.TemplatePath `
                --capabilities CAPABILITY_NAMED_IAM `
                --parameter-overrides $templateParams `
                --profile $LzAccessRoleProfile `
                --region $region           
            }

        }
    }
}





