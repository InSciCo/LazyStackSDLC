Write-Host "Prod_Account_Create.ps1 - V1.0.0"
Write-Host "This script adds a System Prod account to the Prod Organizational Unit."
Write-Host "It also adds a Admin Access Profile so this workstation can administer the new Account."
Write-Host "Note: Press return to accept a default value."

do {
    if(Test-Path -Path "currentorg.txt") {
        $LzSettingsFolder = Get-Content -Path "currentorg.txt"
    } 

    $LzSettingsFolderInput = Read-Host "Organization Settings Folder (default: ${LzSettingsFolder})"
    if($LzSettingsFolderInput -ne "") {
    $LzSettingsFolder = $LzSettingsFolderInput
    }
    $LzFolderFound = Test-Path -Path $LzSettingsFolder
    if($LzFolderFound -eq $false) {
        Write-Host "Folder not found, please run the SetDefaults if you have not done so already."
        exit
    }

} until ($LzFolderFound)

# Read Settings.json to create Settings object
$LzSettingsFilePath = Join-Path -Path $LzSettingsFolder -Childpath "Settings.json"
$LzSettings = Get-Content -Path $LzSettingsFilePath | ConvertFrom-Json

$LzOrgCode = $LzSettings.OrgCode
if("" -eq $LzOrgCode) 
{
    Write-Host "OrgCode is not configured in Settings file. Please run SetDefaults."
    exit
}

$LzMgmtProfile = $LzSettings.AwsMgmtAccount
if("" -eq $LzMgmtProfile) {
    Write-Host "AWS Managment Account is not configured in Settings file. Please run SetDefaults."
    exit
}

$LzRegion = ""

$LzMgmtProfileKey = (aws configure get profile.${LzMgmtProfile}.aws_access_key_id)
if($LzMgmtProfileKey -eq "") {
    Write-Host "Profile ${LzMgmtProfile} not found or not configured with Access Key"
    Write-Host "Please configure the profile and run SetDefaults if you have not done so already."
    exit
}
$LzRegion = aws configure get profile.${LzMgmtProfile}.region

# Make sure LzMgmtProfile is associated with an IAM User in an Account belonging to an Organization
$null = aws organizations describe-organization --profile $LzMgmtProfile
if($? -eq $false) {
    Write-Host "${LzMgmtProfile} profile is associated with an IAM User not administering an Organization."
    Exit
}

if ($LzRegion -eq "") {
    $LzRegion = "us-east-1"
}

$LzRegionInput = Read-Host "Enter Region (default ${LzRegion})"
if($LzRegionInput -ne "") {
    $LzRegion = $LzRegionInput
}

$LzOUName = "${LzOrgCode}ProdOU"
$LzOUNameInput = Read-Host "Enter the Prod OU Name (default ${LzOUName})"
if($LzOUNameInput -ne "") {
    $LzOUName = $LzOUNameInput
}

do {
    $LzSysCode = Read-Host "Enter the System Code (ex: Tut)"
    if($LzSysCode -eq "") {
        Write-Host "System Handle can't be empty. Please enter a value."
    }
}
until ($LzSysCode -ne "")

$LzAcctName = "${LzOrgCode}${LzSysCode}Prod"
$LzAcctNameInput = Read-Host "Enter the Prod System Account Name (default: ${LzAcctName})"
if($LzAcctNameInput -ne "") {
    $LzAcctName = $LzAcctNameInput
}

$LzIAMUserName = "${LzOrgCode}${LzSysCode}Prod"
$LzIAMUserNameInput = Read-Host "Enter the Prod IAM User Name (default: ${LzIAMUserName})"
if($LzIAMUserNameInput -ne "") {
    $LzIAMUserName = $LzIAMUserNameInput
}

Write-Host "Note: An email address can only be associated with one AWS Account."
do {
    $LzRootEmail = Read-Host "Enter an Email Address for the new account's Root User"
    try {
        $null = [mailaddress]$LzRootEmail
        $LzEmailOk = $true
    }
    catch {
        $LzEmailOk = $false
        Write-Host "Invalid Email address entered! Please try again."
    }
}
until ($LzEmailOk)

Write-Host "Please Review and confirm the following:"
Write-Host "    Prod OU: ${LzOUName}"
Write-Host "    System Prod Account to be created: ${LzAcctName}"
Write-Host "    Prod IAM User Name: ${LzIAMUserName}"
Write-Host "    Email Address for Account's Root User: ${LzRootEmail}"

$LzContinue = (Read-Host "Continue y/n") 
if($LzContinue -ne "y") {
    Write-Host "Exiting"
    Exit
}
Write-Host ""
Write-Host "Processing Starting"

# Get LzRootId - note: Currently, there should only ever be one root.
# Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/list-roots.html
$LzRoots = aws organizations list-roots --profile $LzMgmtProfile | ConvertFrom-Json
$LzRootId = $LzRoots.Roots[0].Id 

# Get Organizational Unit
$LzOrgUnitsList = aws organizations list-organizational-units-for-parent --parent-id $LzRootId --profile $LzMgmtProfile | ConvertFrom-Json
if($? -eq $false) {
    Write-Host "Could not find ${LzOUName} Organizational Unit"
    Exit
}
if($LzOrgUnitsList.OrganizationalUnits.Count -eq 0) {
    Write-Host "There are no Organizational Units in root organization."
    Exit    
}

$LzOrgUnit = $LzOrgUnitsList.OrganizationalUnits | Where-Object Name -eq $LzOUName
if($? -eq $false)
{
    Write-Host "Could not find ${LzOUName} Organizational Unit"
    Exit
}

$LzOrgUnitId = $LzOrgUnit.Id


# Create Prod Account  -- this is an async operation so we have to poll for success
# Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/create-account.html
Write-Host "Creating Prod Account: ${LzAcctName}"
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
    Exit
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

# Create Administrators Group for Prod Account
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

# Output Prod Account Creds
Write-Host "    - Writing the IAM User Creds into ${LzIAMUserName}_welcome.txt"
$nl = [Environment]::NewLine
$LzOut = "Account Name: ${LzAcctName}${nl}"  `
+ "Account Console: https://${LzAcctId}.signin.aws.amazon.com/console${nl}" `
+ "IAM User: ${LzIAMUserName}${nl}" `
+ "Temporary Password: ${LzPassword}${nl}" `
+ "Please login, you will be required to reset your password." `
+ "Please login as soon as possible." 

$LzSettingsFolder = Get-Content -Path "currentorg.txt"
$LzSettingsFolderPath = Join-Path -Path $LzSettingsFolder -ChildPath "${LzIAMUserName}_welcome.txt"
$LzOut > $LzSettingsFolderPath

Write-Host "Processing Complete"
