Write-Host "LzUpdateDevCreds.ps1 - V1.0.0"
Write-Host "This script creates/updates the IAMUserCreds customer managed policy for a developer account."
$LzOrgCode = (Read-Host "Enter your OrgCode")

$LzRegion = ""
do {
    $LzMgmtProfile = "${LzOrgcode}Mgmt"
    $LzMgmtProfileInput = (Read-Host "Enter your AWS CLI Management Account Profile (default: ${LzOrgCode}Mgmt)")
    
    if($null -eq $LzMgmtProfileInput) {
        $LzMgmtProfile = $LzMgmtProfileInput
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

do {
    $LzDevHandle = Read-Host "Enter the Developer's Handle (ex: Joe)"
    if($LzDevHandle -eq "") {
        Write-Host "Developer's Handle can't be empty. Please enter a value."
    }
}
until ($LzDevHandle -ne "")

$LzAcctName = "${LzOrgCode}Dev${LzDevHandle}"
$LzAcctNameInput = Read-Host "Enter the Developer's Account Name (default: ${LzAcctName})"
if($LzAcctNameInput -ne "") {
    $LzAcctName = $LzAcctNameInput
}

$LzPolicyName="IAMUserCredsPolicy"

$LzPolicyNameInput = Read-Host "Enter the name of the policy (default: ${LzPolicyName}) "
if("" -ne $LzPolicyNameInput) {
    $LzPolicyName = $LzPolicyNameInput
}

$LzPolicyDocument = "IAMUserCredsPolicy.json"
$LzPolicyDocumentInput = Read-Host "Enter the name of the policy document file (default: ${LzPolicyDocument})"
if("" -ne $LzPolicyDocumentInput) {
    $LzPolicyDocument = $LzPolicyDocumentInput
}

if(Path-Test $LzPolicyDocument)


Write-Host "Please Review and confirm the following to create or update the policy:"
Write-Host "    OrgCode: ${LzOrgCode}"
Write-Host "    Management Account Profile: ${LzMgmtProfile}"
Write-Host "    Development Account to be created: ${LzAcctName}"
Write-Host "    Policy Name: ${LzPolicyName}"
Write-Host "    Policy Document File: ${LzPolicyDocument}"

$LzContinue = (Read-Host "Continue y/n") 
if($LzContinue -ne "y") {
    Write-Host "Exiting"
    Exit
}
Write-Host ""
Write-Host "Processing Starting"

# IAMUserCredsPolicy
Write-Host "    - Adding policy IAMUserCredsPolicy"
$LzGroupPolicyArn = aws iam list-policies --query 'Policies[?PolicyName==`IAMUserCredsPolicy`].{ARN:Arn}' --output text --profile $LzAccessRoleProfile
if($null -eq $LzGroupPolicyArn) {
    aws iam create-policy --policy-name $LzPolicyName --policy-document file://$LzPolicyDocument --profile $LzAccessRoleProfile
} else {
    aws iam create-policy-version --set-as-default --policy-arn $LzGroupPolicyArn --policy-document file://$LzPolicyDocument --profile $LzAccessRoleProfile
}

Write-Host "Processing Complete"
