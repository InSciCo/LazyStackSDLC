
Write-Host "Prod_Account_Create.ps1 - V1.0.0"
Write-Host "This script adds a production account to the Prod Organizational Unit."
Write-Host "It also adds a Admin Access Profile so this workstation can administer the new Account."
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

$LzOUName = "${LzOrgCode}ProdOU"
$LzOUNameInput = Read-Host "Enter the Prod OU Name (default ${LzOUName})"
if($LzOUNameInput -ne "") {
    $LzOUName = $LzOUNameInput
}

$LzAcctName = "${LzOrgCode}Prod"
$LzAcctNameInput = Read-Host "Enter the Prod Account Name (default: ${LzAcctName})"
if($LzAcctNameInput -ne "") {
    $LzAcctName = $LzAcctNameInput
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

$LzIAMUserName = "${LzOrgCode}Prod"
$LzIAMUserNameInput = Read-Host "Enter the Prod IAM User Name (default: ${LzIAMUserName})"
if($LzIAMUserNameInput -ne "") {
    $LzIAMUserName = $LzIAMUserNameInput
}

do {
    $LzIAMUserPassword = Read-Host "Enter the Prod IAM User Password"

}
until ($LzIAMUserPassword -ne "")

Write-Host "Please Review and confirm the following:"
Write-Host "    OrgCode: ${LzOrgCode}"
Write-Host "    Management Account Profile: ${LzMgmtProfile}"
Write-Host "    Prod OU: ${LzOUName}"
Write-Host "    Prod Account to be created: ${LzAcctName}"
Write-Host "    Email Address for Account's Root User: ${LzRootEmail}"
Write-Host "    Prod Account IAM User: ${LzAcctName}"
Write-Host "    Reivew Account IAM User Password: ${LzIAMUserPassword}"

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
Write-Host "Adding ${LzAccessRole} profile and associating it with the ${LzMgmtAcct} profile. "
$null = aws configure set role_arn arn:aws:iam::${LzAcctId}:role/OrganizationAccountAccessRole --profile $LzAccessRoleProfile
$null = aws configure set source_profile $LzMgmtProfile --profile $LzAccessRoleProfile

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
$null = aws iam create-login-profile --user-name $LzIAMUserName --password $LzIAMUserPassword --no-password-reset-required --profile $LzAccessRoleProfile

# Add user to Group 
Write-Host "    - Adding the IAM User ${LzIAMUserName} to the Administrators group in the ${LzAcctName} account."
$null = aws iam add-user-to-group --user-name $LzIAMUserName --group-name Administrators --profile $LzAccessRoleProfile

# Output Reivew IAM User Creds
Write-Host "    - Writing the IAM User Creds into ${LzIAMUserName}_welcome.txt"
$nl = [Environment]::NewLine
$LzOut = "Account Name: ${LzAcctName}${nl}"  `
+ "Account Console: https://${LzAcctId}.signin.aws.amazon.com/console${nl}" `
+ "IAM User: ${LzIAMUserName}${nl}" `
+ "Password: ${LzIAMUserPassword}${nl}" 

$LzOut > ${LzIAMUserName}_welcome.txt

Write-Host "Processing Complete"

Write-Host "The file contains the URL to login to the AWS Account ${LzAcctName}, IAM User Name, and Password."