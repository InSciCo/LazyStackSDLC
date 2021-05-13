Write-Host "SetDefaults.ps1 - V1.0.0"
Write-Host "This script creates/updates a organization default settings folder."
Write-Host "The default naming of the folder is OrgSettings where you replace Org with your OrgCode."
$LzOrgCode = (Read-Host "Enter your OrgCode")

do {
    $LzSettingsFolder = $LzOrgCode + "Settings"
    $LzSettingsFolderInput = Read-Host "Organization Settings Folder (default: ${LzSettingsFolder})"
    if($LzSettingsFolderInput -ne "") {
    $LzSettingsFolder = $LzSettingsFolderInput
    }
    $LzFolderFound = Test-Path -Path $LzSettingsFolder
    if($LzFolderFound -eq $false) {
        $LzCreateFolder = Read-Host "Folder not found, would you like to create ${LzSettingsFolder}. y/n (default y)"
        if($LzCreateFolder -eq "y") {
            $null = New-Item -ItemType "directory" -Path $LzSettingsFolder 
            $LzFolderFound = $true
        }
    }

} until ($LzFolderFound)

# Read or create Settings.json object
$LzSettingsFilePath = Join-Path -Path $LzSettingsFolder -ChildPath "Settings.json"
$LzSettingsFound = Test-Path -Path $LzSettingsFilePath
if($LzSettingsFound) {
    # Read Settings.json to create Settings object
    $LzSettings = Get-Content -Path $LzSettingsFilePath | ConvertFrom-Json
} else {
    # Create default Settings object
    $LzSettings = [PSCustomObject]@{
        GitHubAcct="tst"
        PersonalAccessToken=""
        OrgCode=$LzOrgCode
        AwsMgmtAccount=""
        LazyStackSmfUtilRepo=""
    }
}

# Get Defaults from User
# GitHub Account
$default = $LzSettings.GitHubAcct
$LzGitHubAcctInput = Read-Host "GitHub Account Name (default: ${default})"
if("" -ne $LzGitHubAcctInput) {
    $LzSettings.GitHubAcct = $LzGitHubAcctInput
}

# GitHub Personal Access Token
$default = $LzSettings.PersonalAccessToken
$LzPATInput = Read-Host "GitHub Personal Access Token (default: ${default})"
if("" -ne $LzPATInput) {Write-Host " ${LzSettings.}"
    $LzSettings.PersonalAccessToken = $LzPATInput
}

# AwsMgmtAccount 
do {
    if("" -eq $LzSettings.AwsMgmtAccount) {
        $LzSettings.AwsMgmtAccount = $LzSettings.OrgCode + "Mgmt"
    }
    $default = $LzSettings.AwsMgmtAccount
    $LzAwsMgmtAccountInput = Read-Host "AWS Management Account (default: ${default})"
    if("" -ne $LzAwsMgmtAccountInput) {
        $LzSettings.AwsMgmtAccount = $LzAwsMgmtAccountInput
    }

    $LzMgmtProfile = 

    $LzMgmtProfileKey = (aws configure get profile.${LzMgmtProfile}.aws_access_key_id)
    if($LzMgmtProfileKey -eq "") {
        Write-Host "Profile ${LzMgmtProfile} not found or not configured with Access Key"
        $LzMgmtProfileExists = $false
    }
    else  {
        $LzMgmtProfileExists = $true
        # Grab region in managment profile as default for new IAM User
        $null = aws configure get profile.${LzMgmtProfile}.region
    }   


} until ($LzMgmtProfileExists)


if($LzSettings.LazyStackSmfUtilRepo -eq "") {
    $LzGitHubAcct = $LzSettings.GitHubAcct
    $LzSettings.LazyStackSmfUtilRepo = "https://github.com/${LzGitHubAcct}/LazyStackSmfUtil.git"
}
$default = $LzSettings.LazyStackSmfUtilRepo
$LazyStackSmfUtilRepoInput = Read-Host "LazyStackSmfUtil repository URL (default: ${default})"
if("" -ne $LazyStackSmfUtilRepoInput) {
    $LzSettings.LazyStackSmfUtilRepo = $LazyStackSmfUtilRepoInput
}

Write-Host "Please review and confirm your entries"
Write-Host "OrgCode: ${LzOrgCode}"
$value = $LzSettings.GitHubAcct
Write-Host "GitHub Account: ${value}"
$value = $LzSettings.PersonalAccessToken
Write-Host "GitHub Personal Access token: ${value}"
$value = $LzSettings.AwsMgmtAccount
Write-Host "AWS Management Account: ${value}"
$value = $LzSettings.LazyStackSmfUtilRepo
Write-Host "LazyStackSmfUtil repository URL: ${value}"
$LzOk = Read-Host "Update Settings y/n"

if("y" -eq $LzOk) {
    $LzContent = $LzSettings | ConvertTo-Json 
    Write-Host "Updating ${LzSettingsFilePath} file"
    Set-Content -Path $LzSettingsFilePath -Value $LzContent
    Write-Host "Updating currentorg.txt"
    Set-Content -Path "currentorg.txt" -Value (Split-Path -Path $LzSettingsFilePath )
    Write-Host "Processing complete"
} else {
    Write-Host "Processing abandoned"
}
