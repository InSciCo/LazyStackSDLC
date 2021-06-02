Write-LzHost $indent "LzNewDevAccount.ps1 - V1.0.0"
Write-LzHost $indent "This script adds a developer account to the Dev Organizational Unit."
Write-LzHost $indent "It also adds a Admin Access Profile so this workstation can administer the new Account."
Write-LzHost $indent "Note: Press return to accept a default value."

$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path 
Import-Module (Join-Path -Path $scriptPath -ChildPath LazyStackLib) -Force
Import-Module (Join-Path -Path $scriptPath -ChildPath LazyStackUI) -Force
Test-LzDependencies

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
$LzRootId = Get-AwsOrgRootId -awsProfile $LzMgmtProfile 

# Get Organizational Unit

$lzOrgUnit = Get-AwsOrgUnit -awsProfile $LzMgmtProfile -ouName $LzOUName
if($null -eq $LzOrgUnit -Or $lzOrgUnit -eq "")
{
    Write-LzHost $indent "Could not find ${LzOUName} Organizational Unit"
    Exit
}

$LzOrgUnitId = $LzOrgUnit.Id

$LzAccounts = Get-AwsAccounts -awsProfile $LzMgmtProfile
$LzAcct = ($LzAccounts.Accounts | Where-Object Name -EQ $LzAcctName)

if($null -ne $LzAcct) {
    Write-LzHost $indent  "- Found AWS Account ${LzAcctName}"
    $LzAcctId = $LzAcct.Id
}
else {
    # Create Dev Account  -- this is an async operation so we have to poll for success
    # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/create-account.html
    Write-LzHost $indent "Creating Developer Account: ${LzAcctName}"

    $LzAcct = New-AwsAccount -awsProfile $LzMgmtProfile -acctName $LzAcctName -email $LzRootEmail
    $LzAcctId = $LzAcct.CreateAccountStatus.Id

    # poll for success
    # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/describe-create-account-status.html
    $LzAcctCreationCheck = 1
    do {
        Write-LzHost $indent "  - Checking for successful account creation. TryCount=${LzAcctCreationCheck}"
        Start-Sleep -Seconds 5
        $LzAcctStatus = Get-AwsAccountStatus -awsProfile $LzMgmtProfile -acctId $LzAcctId 
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
$LzOUChildren = Get-AwsOrgUnitAccounts -awsProfile $LzMgmtProfile -ouId $LzOrgUnitId
$LzOUChild = $LzOUChildren.Children | Where-Object Id -EQ $LzAcctId
if($null -ne $LzOUChild) {
    Write-LzHost $indent  "- Account is in ${LzOUName} Organizational Unit."
}
else {
    # Move new Account to OU
    # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/move-account.html
    Write-LzHost $indent  "- Moving ${LzAcctName} account to ${LzOUName} Organizational Unit"
    Move-AwsAccount -awsProfile $LzMgmtProfile -sourceId $LzRootId -destId $LzOrgUnitId -acctId $LzAcctId
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
Set-AwsProfileRole -awsProfile $LzMgmtProfile -accessProfile $LzAccessRoleProfile -region $LzRegion

$IamUserCredsPolicyFile = "IAMUserCredsPolicy.json"
if(!(Test-Path $IamUserCredsPolicyFile)) {
    $IamUserCredsPolicyFile = "../LazyStackSMF/IAMUserCredsPolicy.json"
}


$LzGroupPolicyArn = Get-AwsPolicyArn -awsProfile $LzAccessRoleProfile -policyName IAMUserCredsPolicy
if($null -eq $LzGroupPolicyArn)
{
    Write-LzHost $indent "- Adding policy IAMUserCredsPolicy"
    $LzGroupPolicy = New-AwsPolicy -awsProfile $LzAccessRoleProfile -policyName IAMUserCredsPolicy -policyFileName $IamUserCredsPolicyFile
    $LzGroupPolicyArn = $LzGroupPolicy.Policy.Arn
} else {
    Write-LzHost $indent "-Found IAMuserCredsPolicy"
}


# Create Developers Group for Developers Account
# Reference: https://docs.aws.amazon.com/cli/latest/userguide/cli-services-iam-new-user-group.html
$awsgroups = Get-AwsGroups -awsProfile $LzAccessRoleProfile
$group = ($awsgroups.Groups | Where-Object GroupName -EQ "Developers")

if($null -eq $group) {
    Write-LzHost $indent  "- Creating Developers group in the ${LzAcctName} account."
    $null = New-AwsGroup -awsProfile $LzAccessRoleProfile -groupName Developers
} else {
    Write-LzHost $indent  "- Found Developers group in ${LzAcctName} account."
}


# Add policies to Group
# PowerUserAccess
$policy = Get-AwsGroupPolicy -awsProfile $LzAccessRoleProfile -groupName Developers -policyName PowerUserAccess
if($null -ne $policy) {
    Write-LzHost $indent  "- Found PowerUserAccess Policy in Developers group"
} else {
    Write-LzHost $indent  "- Adding PowerUserAccess Policy to Developers group"
    Set-AwsPolicyToGroup -awsProfile $LzAccessRoleProfile -groupName Developers -policyName PowerUserAccess
}

# IAMUserCredsPolicy
$policy = ($policies.AttachedPolicies  | Where-Object PolicyName -EQ IAMUserCredsPolicy) 
$policy = Get-AwsGroupPolicy -awsProfile $LzAccessRoleProfile -groupName Developers -policyName IAMUserCredsPolicy
if($null -ne $policy) {
    Write-LzHost $indent  "- Found IAMUserCredsPolicy Policy in Developers group"
} else {
    Write-LzHost $indent  "- Adding IAMUserCredsPolicy Policy to Developers group"
    Set-AwsPolicyToGroup -awsProfile $LzAccessRoleProfile -groupName Developers -policyName IAMUserCredsPolicy
}

# Create User in Account
$LzIAMUserName = $LzAcctName
$user = Get-AwsUser -awsProfile $LzAccessRoleProfile -userName $LzIAMUserName
if($null -ne $user) {
    Write-LzHost $indent  "- Found IAM User ${LzIAMUserName} in ${LzAcctName} account."
} else {
    # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/iam/create-user.html
    Write-LzHost $indent  "- Creating IAM User ${LzIAMUserName} in ${LzAcctName} account."
    $LzPassword = New-AwsUserAndProfile -awsProfile $LzAccessRoleProfile -userName $LzIAMUserName

    # Output Test Account Creds
    Write-LzHost $indent  "- Writing the IAM User Creds into ${LzIAMUserName}_credentials.txt"
    $nl = [Environment]::NewLine
    $LzOut = "User name,Password,Access key ID,Secret access key,Console login link${nl}" `
    + $LzAcctName + "," + $LzPassword + ",,," + "https://${LzAcctId}.signin.aws.amazon.com/console"

    $LzOut > ${LzIAMUserName}_credentials.csv
}


# Add user to Group 
$userInGroup = Test-AwsUserInGroup -awsProfile $LzAccessRoleProfile -userName $LzIAMUserName -groupName Developers
if($userInGroup) {
    Write-LzHost $indent  "- Found IAM User ${LzIAMUserName} in the ${LzAcctName} Account Developers group."
} else {
    Write-LzHost $indent  "- Adding IAM User ${LzIAMUserName} to the ${LzAcctName} Account Developers group."
    Set-AwsUserGroup -awsProfile $LzAccessRoleProfile -userName $LzIAMUserName -groupName Developers
}

Write-LzHost $indent "Processing Complete"

Write-LzHost $indent "Send the ${LzIAMUserName}_credentials.txt file to the Developer or use it yourself if you are also that developer."
Write-LzHost $indent "The file contains the URL to login to the AWS Account ${LzAcctName} and the initial password (password reset"
Write-LzHost $indent "required on first login) for the IAM User ${LzIAMUserName}."