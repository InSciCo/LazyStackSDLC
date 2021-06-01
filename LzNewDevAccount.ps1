Write-LzHost $indent "LzNewDevAccount.ps1 - V1.0.0"
Write-LzHost $indent "This script adds a developer account to the Dev Organizational Unit."
Write-LzHost $indent "It also adds a Admin Access Profile so this workstation can administer the new Account."
Write-LzHost $indent "Note: Press return to accept a default value."

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

$settingsFile = "smf.yaml"
$indent = 0

if(!(Test-Path $settingsFile)) {
    Write-LzHost $indent "Error: Can't find ${settingsFile}"
    exit
}

$smf = Get-SMF $settingsFile # this routine may prompt user for OrgCode and MgmtProfile
$LzOrgCode = @($smf.Keys)[0]
Write-LzHost $indent "OrgCode:" $LzOrgCode
$LzMgmtProfile = $smf.$LzOrgCode.AWS.MgmtProfile
Write-LzHost $indent "AWS Managment Account:" $LzMgmtProfile
$LzOUName = "DevOU"

$LzMgmtProfileKey = aws configure get profile.${LzMgmtProfile}.aws_access_key_id
if($LzMgmtProfileKey -eq "") {
    Write-LzHost $indent "Profile ${LzMgmtProfile} not found or not configured with Access Key"
    exit
}
$LzRegion = aws configure get profile.${LzMgmtProfile}.region

$null = aws organizations describe-organization --profile $LzMgmtProfile
if($? -eq $false) {
    Write-LzHost $indent "${LzMgmtProfile} profile is associated with an IAM User not administering an Organization."
    Exit
}


if ($LzRegion -eq "") {
    $LzRegion = "us-east-1"
}


do {
    $LzDevHandle = Read-Host "Enter the Developer's Handle (ex: Joe)"
    if($LzDevHandle -eq "") {
        Write-LzHost $indent "Developer's Handle can't be empty. Please enter a value."
    }
}
until ($LzDevHandle -ne "")

$LzAcctName = "${LzOrgCode}Dev${LzDevHandle}"
$LzAcctNameInput = Read-Host "Enter the Developer's Account Name (default: ${LzAcctName})"
if($LzAcctNameInput -ne "") {
    $LzAcctName = $LzAcctNameInput
}

$LzIAMUserName = "${LzOrgCode}Dev${LzDevHandle}"
$LzIAMUserNameInput = Read-Host "Enter the Developer's IAM User Name (default: ${LzIAMUserName})"
if($LzIAMUserNameInput -ne "") {
    $LzIAMUserName = $LzIAMUserNameInput
}

Write-LzHost $indent "Note: An email address can only be associated with one AWS Account."
do {
    $LzRootEmail = Read-Host "Enter an Email Address for the new account's Root User"
    try {
        $null = [mailaddress]$LzRootEmail
        $LzEmailOk = $true
    }
    catch {
        $LzEmailOk = $false
        Write-LzHost $indent "Invalid Email address entered! Please try again."
    }
}
until ($LzEmailOk)

Write-LzHost $indent "Please Review and confirm the following:"
Write-LzHost $indent "    OrgCode: ${LzOrgCode}"
Write-LzHost $indent "    Management Account Profile: ${LzMgmtProfile}"
Write-LzHost $indent "    Development OU: ${LzOUName}"
Write-LzHost $indent "    Development Account to be created: ${LzAcctName}"
Write-LzHost $indent "    Development Account IAM User Name: ${LzIAMUserName}"
Write-LzHost $indent "    Email Address for Account's Root User: ${LzRootEmail}"

$LzContinue = (Read-Host "Continue y/n") 
if($LzContinue -ne "y") {
    Write-LzHost $indent "Exiting"
    Exit
}
Write-LzHost $indent ""
Write-LzHost $indent "Processing Starting"

# Get LzRootId - note: Currently, there should only ever be one root.
# Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/list-roots.html
$LzRoots = aws organizations list-roots --profile $LzMgmtProfile | ConvertFrom-Json
$LzRootId = $LzRoots.Roots[0].Id 

# Get Organizational Unit
$LzOrgUnitsList = aws organizations list-organizational-units-for-parent --parent-id $LzRootId --profile $LzMgmtProfile | ConvertFrom-Json
if($? -eq $false) {
    Write-LzHost $indent "Could not find ${LzOUName} Organizational Unit"
    Exit
}
if($LzOrgUnitsList.OrganizationalUnits.Count -eq 0) {
    Write-LzHost $indent "There are no Organizational Units in root organization."
    Exit    
}

$LzOrgUnit = $LzOrgUnitsList.OrganizationalUnits | Where-Object Name -eq $LzOUName
if($? -eq $false)
{
    Write-LzHost $indent "Could not find ${LzOUName} Organizational Unit"
    Exit
}

$LzOrgUnitId = $LzOrgUnit.Id


$LzAccounts = aws organizations list-accounts --profile $LzMgmtProfile | ConvertFrom-Json
$LzAcct = ($LzAccounts.Accounts | Where-Object Name -EQ $LzAcctName)

if($null -ne $LzAcct) {
    Write-LzHost $indent  "- Found AWS Account ${LzAcctName}"
    $LzAcctId = $LzAcct.Id
}
else {
    # Create Dev Account  -- this is an async operation so we have to poll for success
    # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/create-account.html
    Write-LzHost $indent "Creating Developer Account: ${LzAcctName}"
    $LzAcct = aws organizations create-account --email $LzRootEmail --account-name $LzAcctName --profile $LzMgmtProfile | ConvertFrom-Json
    $LzAcctId = $LzAcct.CreateAccountStatus.Id

    # poll for success
    # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/describe-create-account-status.html
    $LzAcctCreationCheck = 1
    do {
        Write-LzHost $indent "  - Checking for successful account creation. TryCount=${LzAcctCreationCheck}"
        Start-Sleep -Seconds 5
        $LzAcctStatus = aws organizations describe-create-account-status --create-account-request-id $LzAcctId --profile $LzMgmtProfile | ConvertFrom-Json
        $LzAcctCreationCheck = $LzAcctCreationCheck + 1
    }
    while ($LzAcctStatus.CreateAccountStatus.State -eq "IN_PROGRESS")

    if($LzAcctStatus.CreateAccountStatus.State -ne "SUCCEEDED") {
        Write-LzHost $indent $LzAcctStatus.CreateAccountStatus.FailureReason
        Exit
    }

    $LzAcctId = $LzAcctStatus.CreateAccountStatus.AccountId
    Write-LzHost $indent "  - ${LzAcctName} account creation successful. AccountId: ${LzAcctId}"
}


# Check if account is in OU
$LzOUChildren = aws organizations list-children --parent-id $LzOrgUnitID --child-type ACCOUNT --profile $LzMgmtProfile | ConvertFrom-Json 
$LzOUChild = $LzOUChildren.Children | Where-Object Id -EQ $LzAcctId
if($null -ne $LzOUChild) {
    Write-LzHost $indent  "- Account is in ${LzOUName} Organizational Unit."
}
else {
    # Move new Account to OU
    # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/move-account.html
    Write-LzHost $indent  "- Moving ${LzAcctName} account to ${LzOUName} Organizational Unit"
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
Write-LzHost $indent "Adding ${LzAccessRoleProfile} profile and associating it with the ${LzMgmtProfile} profile. "
$null = aws configure set role_arn arn:aws:iam::${LzAcctId}:role/OrganizationAccountAccessRole --profile $LzAccessRoleProfile
$null = aws configure set source_profile $LzMgmtProfile --profile $LzAccessRoleProfile
$null = aws configure set region $LzRegion --profile $LzAccessRoleProfile

$IamUserCredsPolicyFile = "IAMUserCredsPolicy.json"
if(!(Test-Path $IamUserCredsPolicyFile)) {
    $IamUserCredsPolicyFile = "../LazyStackSMF/IAMUserCredsPolicy.json"
}


$LzGroupPolicyArn = aws iam list-policies --query 'Policies[?PolicyName==`IAMUserCredsPolicy`].{ARN:Arn}' --output text --profile $LzAccessRoleProfile
if($null -eq $LzGroupPolicyArn)
{
    Write-LzHost $indent "- Adding policy IAMUserCredsPolicy"
    $LzGroupPolicy = aws iam create-policy --policy-name IAMUserCredsPolicy --policy-document file://$IamUserCredsPolicyFile --profile $LzAccessRoleProfile | ConvertFrom-Json
    $LzGroupPolicyArn = $LzGroupPolicy.Policy.Arn
} else {
    Write-LzHost $indent "-Found IAMuserCredsPolicy"
}


# Create Developers Group for Developers Account
# Reference: https://docs.aws.amazon.com/cli/latest/userguide/cli-services-iam-new-user-group.html
$awsgroups = aws iam list-groups --profile $LzAccessRoleProfile | ConvertFrom-Json
$group = ($awsgroups.Groups | Where-Object GroupName -EQ "Developers")
if($null -eq $group) {
    Write-LzHost $indent  "- Creating Developers group in the ${LzAcctName} account."
    $null = aws iam create-group --group-name Developers --profile $LzAccessRoleProfile
} else {
    Write-LzHost $indent  "- Found Developers group in ${LzAcctName} account."
}


# Add policies to Group
# PowerUserAccess
$policies = aws iam list-attached-group-policies --group-name Developers --profile $LzAccessRoleProfile
# PowerUserAccess
$policy = ($policies.AttachedPolicies  | Where-Object PolicyName -EQ PowerUserAccess) 
if($null -ne $policy) {
    Write-LzHost $indent  "- Found PowerUserAccess Policy in Developers group"
} else {
    Write-LzHost $indent  "- Adding PowerUserAccess Policy to Developers group"
    $LzGroupPolicyArn = aws iam list-policies --query 'Policies[?PolicyName==`PowerUserAccess`].{ARN:Arn}' --output text --profile $LzAccessRoleProfile 
    $null = aws iam attach-group-policy --group-name Developers --policy-arn $LzGroupPolicyArn --profile $LzAccessRoleProfile
}

# IAMUserCredsPolicy
$policy = ($policies.AttachedPolicies  | Where-Object PolicyName -EQ IAMUserCredsPolicy) 
if($null -ne $policy) {
    Write-LzHost $indent  "- Found IAMUserCredsPolicy Policy in Developers group"
} else {
    Write-LzHost $indent  "- Adding IAMUserCredsPolicy Policy to Developers group"
    $LzGroupPolicyArn = aws iam list-policies --query 'Policies[?PolicyName==`IAMUserCredsPolicy`].{ARN:Arn}' --output text --profile $LzAccessRoleProfile 
    $null = aws iam attach-group-policy --group-name Developers --policy-arn $LzGroupPolicyArn --profile $LzAccessRoleProfile
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
    Write-LzHost $indent  "- Writing the IAM User Creds into ${LzIAMUserName}_credentials.txt"
    $nl = [Environment]::NewLine
    $LzOut = "User name,Password,Access key ID,Secret access key,Console login link${nl}" `
    + $LzAcctName + "," + $LzPassword + ",,," + "https://${LzAcctId}.signin.aws.amazon.com/console"

    $LzOut > ${LzIAMUserName}_credentials.csv
}


# Add user to Group 
$usergroups = aws iam list-groups-for-user --user-name $LzIAMUserName --profile $LzAccessRoleProfile | ConvertFrom-Json
$group = ($usergroups.Groups | Where-Object GroupName -EQ Developers)
if($null -ne $group) {
    Write-LzHost $indent  "- Found IAM User ${LzIAMUserName} in the ${LzAcctName} Account Developers group."
} else {
    Write-LzHost $indent  "- Adding IAM User ${LzIAMUserName} to the ${LzAcctName} Account Developers group."
    $null = aws iam add-user-to-group --user-name $LzIAMUserName --group-name Developers --profile $LzAccessRoleProfile
}


Write-LzHost $indent "Processing Complete"

Write-LzHost $indent "Send the ${LzIAMUserName}_credentials.txt file to the Developer or use it yourself if you are also that developer."
Write-LzHost $indent "The file contains the URL to login to the AWS Account ${LzAcctName} and the initial password (password reset"
Write-LzHost $indent "required on first login) for the IAM User ${LzIAMUserName}."