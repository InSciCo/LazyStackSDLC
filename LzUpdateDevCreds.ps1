Write-Host "LzUpdateDevCreds.ps1 - V1.0.0"
Write-Host "This script creates/updates the IAMUserCreds customer managed policy for a developer account."

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

$IamUserCredsPolicyFile = "IAMUserCredsPolicy.json"
if(!(Test-Path $IamUserCredsPolicyFile)) {
    $IamUserCredsPolicyFile = "../LazyStackSMF/IAMUserCredsPolicy.json"
}

Write-LzHost $indent "Please Review and confirm the following to create or update the policy:"
Write-LzHost $indent "    OrgCode: ${LzOrgCode}"
Write-LzHost $indent "    Management Account Profile: ${LzMgmtProfile}"
Write-LzHost $indent "    Policy Document File location: ${IamUserCredsPolicyFile}"

$LzContinue = (Read-Host "Continue y/n") 
if($LzContinue -ne "y") {
    Write-LzHost $indent "Exiting"
    Exit
}
Write-LzHost $indent ""
Write-LzHost $indent "Processing Starting"

 $LzAccessRoleProfile = $LzAcctName + "AccessRole"

# IAMUserCredsPolicy
$LzGroupPolicyArn = Get-AwsPolicyArn -awsProfile $LzAccessRoleProfile -policyName IAMUserCredsPolicy
if($null -eq $LzGroupPolicyArn) {
    Write-LzHost $indent "    - Adding policy IAMUserCredsPolicy"
    $null = New-AwsPolicy -awsProfile $LzAccessRoleProfile -policyName IAMUserCredsPolicy -policyFileName $IamUserCredsPolicyFile
} else {
    Write-LzHost $indent "    - Updating policy IAMUserCredsPolicy"
    $null = New-AwsPolicyVersion -awsProfile $LzAccessRoleProfile -policyArn $LzGroupPolicyArn -policyFileName $IamUserCredsPolicyFile
}
Write-LzHost $indent "If you receive an error stating you have exceeded the allowable versions limit on the policy document,"
Write-LzHost $indent "please use the AWS Console to remove older versions and then rerun this script."
Write-LzHost $indent "Processing Complete"