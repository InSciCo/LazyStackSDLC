#LazyStackLib.psm1

function Test-LzDependencies {
    Test_YamlInstalled
}

function Test-YamlInstalled {
    Get-InstalledModule | foreach-Object{
        if($_.Name -eq "powershell-yaml"){
            return
        }
    }
    Write-Host "Powershell-Yaml is a required dependency."
    Exit
}

function Test-AwsProfileExists {
    param ([string]$awsProfile)
    if($null -eq $awsProfile -Or $awsProfile -eq "") {
        throw "Test-AwsProfileExists: Parameter Error: awsProfile empty"
    }

    $list = aws configure list-profiles

    return ($list -contains $awsProfile)
}
function Get-IsRegionAvailable {
    param ([string]$awsProfile, [string]$regionName)
    if($null -eq $awsProfile -Or $awsProfile -eq "" ) {
        throw "Get-IsRegionAvailable: Parameter Error: awsProfile empty"
    }
    if($null -eq $regionName -Or $regionName -eq "" ) {
        throw "Get-IsRegionAvailable: Parameter Error: regionName empty"
    }

    $result = aws ec2 describe-regions --all-regions --profile $awsProfile 2>&1

    if($null -eq $result) {
        throw ("Get-IsRegionAvailable Error no regions found")    
    }

    if($output -like "{*") {
        $region = $result.Regions | Where-Object RegionName -EQ $regionName
        return  ($null -ne $region)        
    }  

    throw ("Get-IsRegionAvailable Error:" + $output)
}
function Read-AwsRegion {
    param ([string]$awsProfile, [string]$prompt="Enter AWS Region", [string]$default, [int]$indent)
    if($null -eq $awsProfile -Or $awsProfile -eq "" ) {
        throw "Read-AwsRegion: Parameter Error: awsProfile empty"
    }

    $indentstr = " " * $indent
    if("" -ne $default) { $defstr = " (${default})"} else {$defstr = ""}
    do {
        $regionname = Read-String `
            -prompt "${prompt}${defstr}" `
            -default $default `
            -indent $indent
        $found = Test-AwsRegionAvailable -awsProfile $awsProfile -regionName $regionname
        if(!$found) {
            Write-Host "${indentstr}Sorry, that region is not available. Please try again."
        }
    } until ($found)
    return $regionName
}
function Read-AwsProfileName {
    param ([string]$prompt, [string]$default, [int]$indent=0)
    Write-Host "default=" $default
    $indentstr = " " * $indent
    do {
        $inputvalue = (Read-String `
            -prompt $prompt `
            -default $default `
            -indent $indent) 

        $found = Test-AwsProfileExists -awsProfile $inputvalue
        if(!$found) {
            Write-Host "${indentstr}AWS AWS CLI Managment Account Profile ${inputvalue} Not Found!"        
            Write-Host "${indentstr}Please try again."
        }
    } until ($found)    
    return $inputvalue
}
function Get-AwsOrgRootId{
    param([string]$awsProfile)
    if($null -eq $awsProfile -Or $awsProfile -eq "" ) {
        throw "Get-AwsOrgRootId: Parameter Error: awsProfile empty" 
    }

    # Get LzRootId - note: Currently, there should only ever be one root.
    # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/list-roots.html
    [string]$output = aws organizations list-roots --profile $awsProfile 2>&1
    $output = $output.Replace(" ", "")
    # Catch error by examining return
    if($output.Substring(2,5) -ne "Roots") {
        return  ""
    }
    $LzRoots = $output | ConvertFrom-Json 
    $LzRootId = $LzRoots.Roots[0].Id
    return $LzRootId
}

function New-AwsOrganization {
    param([string]$awsProfile)
    if($null -eq $awsProfile -Or $awsProfile -eq "" ) {
        throw "New-AwsOrganization: Parameter Error: awsProfile empty" 
    }

    $output = aws organizations create-organization --profile $awsProfile 2>&1

    if($null -eq $result -Or $output -like "{*") {
        return 
    }  

    throw ("New-AwsOrganization Error:" + $output)
}

function Get-AwsOrgUnits {
    param([string]$awsProfile, [string]$orgRootId)
    if($null -eq $awsProfile -Or $awsProfile -eq "" ) {
        throw "Get-AwsOrgUnits: Parameter Error: awsProfile empty" 
    }
    if($null -eq $orgRootId -Or $orgRootId -eq "" ) {
        throw "Get-AwsOrgUnits: Parameter Error: orgRootId empty" 
    }

    $result = aws organizations list-organizational-units-for-parent `
        --parent-id $orgRootId `
        --profile $awsProfile 2>&1 
    
    if($null -ne $result -And $result -like "{*") {
        return $result | ConvertFrom-Json 
    }  
    throw ("Get-AwsOrgUnits Error:" + $result)
}

function Get-AwsOrgUnit {
    param([string]$awsProfile, [string]$ouName)
    if($null -eq $awsProfile -Or $awsProfile -eq "" ) {
        throw "Get-AwsOrgUnits: Parameter Error: awsProfile empty" 
    }
    if($null -eq $ouName -Or $ouName -eq "" ) {
        throw "Get-AwsOrgUnits: Parameter Error: ouName empty" 
    }

    $orgRootId =  Get-AwsOrgRootId -awsprofile $awsProfile 
    if($null -eq $orgRootId -Or $orgRootId -eq "") {
        throw "Get-AwsOrgUnit Error: No Organiaztion Found"
    }

    $result =  aws organizations list-organizational-units-for-parent --parent-id $orgRootId --profile $awsProfile 2>&1
    
    if($null -ne $result -And $result -like "{*") {
        return $result.OrganizationalUnits | Where-Object Name -eq $ouName
    }
    throw ("Get-AwsOrgUnit Error: " + $result)
}

function New-AwsOrgUnit {
    Param([string]$awsProfile, [string]$orgRootId, [string]$ouName)
    if($null -eq $awsProfile -Or $awsProfile -eq "" ) {
        throw "New-AwsOrgUnit: Parameter Error: awsProfile empty" 
    }
    if($null -eq $orgRootId -Or $orgRootId -eq "" ) {
        throw "New-AwsOrgUnit: Parameter Error: orgRootId empty" 
    }
    if($null -eq $ouName -Or $ouName -eq "" ) {
        throw "New-AwsOrgUnit: Parameter Error: ouName empty" 
    }

    $result = aws organizations create-organizational-unit `
        --parent-id $orgRootId `
        --name $ouName  `
        --profile $awsProfile  2>&1
    

    if($null -ne $result -And $result -like "{*") {
        return $result | ConvertFrom-Json 
    }  
    throw ("New-AwsOrgUnit Error:" + $result)

}

function Get-AwsAccounts {
    param([string]$awsProfile)
    if($null -eq $awsProfile -Or $awsProfile -eq "" ) {
        throw "Get-AwsAccounts: Parameter Error: awsProfile empty" 
    }

    $result = aws organizations list-accounts --profile $awsProfile 2>&1

    if($null -ne $result -And $result -like "{*") {
        return $result | ConvertFrom-Json 
    }  
    throw ("Get-AwsAccounts Error:" + $result)

}

function New-AwsAccount {
    param([string]$awsProfile, [string]$acctName, [string]$email)
    if($null -eq $awsProfile -Or $awsProfile -eq "" ) {
        throw "New-AwsAccount: Parameter Error: awsProfile empty" 
    }
    if($null -eq $acctName -Or $acctName -eq "" ) {
        throw "New-AwsAccount: Parameter Error: acctName empty" 
    }
    if($null -eq $email -Or $email -eq "" ) {
        throw "New-AwsAccount: Parameter Error: email empty" 
    }

    $result = aws organizations create-account --email $email --account-name $acctName --profile $awsProfile 2>&1

    if($null -ne $result -And $result -like "{*") {
        return $result | ConvertFrom-Json 
    }  
    throw ("New-AwsAccount Error" + $result)
}


function Get-AwsAccountStatus {
    param([string]$awsProfile, [string]$acctId)
    if($null -eq $awsProfile -Or $awsProfile -eq "" ) {
        throw "Get-AwsAccountStatus: Parameter Error: awsProfile empty" 
    }
    if($null -eq $acctId -Or $acctId -eq "" ) {
        throw "Get-AwsAccountStatus: Parameter Error: acctId empty" 
    }

    $result = aws organizations describe-create-account-status --create-account-request-id $acctId --profile $awsProfile 2>&1

    if($null -ne $result -And $result -like "{*") {
        return $result | ConvertFrom-Json 
    }  
    throw ("Get-AwsAccountStatus Error" + $result)

}

function Get-AwsOrgUnitAccounts{
    param([string]$awsProfile, [string]$ouId)
    if($null -eq $awsProfile -Or $awsProfile -eq "" ) {
        throw "Get-AwsOrgUnitAccounts: Parameter Error: awsProfile empty" 
    }
    if($null -eq $ouId -Or $ouId -eq "" ) {
        throw "Get-AwsOrgUnitAccounts: Parameter Error: ouId empty" 
    }

    $result = aws organizations list-children --parent-id $ouId --child-type ACCOUNT --profile $awsProfile 2>&1

    if($null -ne $result -And $result -like "{*") {
        return $result | ConvertFrom-Json 
    }  
    throw ("Get-AwsOrgUnitAccounts Error" + $result)

}

function Move-AwsAccount {
    param([string]$awsProfile, [string]$sourceId, [string]$destId, [string]$acctId)
    if($null -eq $awsProfile -Or $awsProfile -eq "" ) {
        throw "Move-AwsAccount: Parameter Error: awsProfile empty" 
    }
    if($null -eq $sourceId -Or $sourceId -eq "" ) {
        throw "Move-AwsAccount: Parameter Error: sourceId empty" 
    }
    if($null -eq $destId -Or $destId -eq "" ) {
        throw "Move-AwsAccount: Parameter Error: destId empty" 
    }
    if($null -eq $acctId -Or $acctId -eq "" ) {
        throw "Move-AwsAccount: Parameter Error: acctId empty" 
    }

    $result = aws organizations move-account --account-id $acctId --source-parent-id $sourceId --destination-parent-id $destId --profile $awsProfile 2>&1

    if($null -eq $result -Or $result -eq "") {
        return 
    }  
    throw ("Move-AwsAccount Error:" + $result)
}

function Set-AwsProfileRole {
    param([string]$awsProfile, [string]$accessProfile, [string]$region)
    if($null -eq $awsProfile -Or $awsProfile -eq "" ) {
        throw "Set-AwsProfileRole: Parameter Error: awsProfile empty" 
    }
    if($null -eq $accessProfile -Or $accessProfile -eq "" ) {
        throw "Set-AwsProfileRole: Parameter Error: accessProfile empty" 
    }
    if($null -eq $region -Or $region -eq "" ) {
        throw "Set-AwsProfileRole: Parameter Error: region empty" 
    }

    $null = aws configure set role_arn arn:aws:iam::${LzAcctId}:role/OrganizationAccountAccessRole --profile $awsProfile 2>&1

    $null = aws configure set source_profile $LzMgmtProfile --profile $awsProfile 2>&1

    $null = aws configure set region $LzRegion --profile $awsProfile 2>&1

}

function Get-AwsGroups {
    param([string]$awsProfile)
    if($null -eq $awsProfile -Or $awsProfile -eq "" ) {
        throw "Get-AwsGroups: Parameter Error: awsProfile empty" 
    }

    $result = aws iam list-groups --profile $awsProfile 2>&1

    if($null -ne $result -And $result -like "{*") {
        return $result | ConvertFrom-Json 
    }  
    throw ("Get-AwsGroups Error:" + $result)    
}


function New-AwsGroup {
    param([string]$awsProfile, [string]$groupName)
    if($null -eq $awsProfile -Or $awsProfile -eq "" ) {
        throw "New-AwsGroup: Parameter Error: awsProfile empty" 
    }
    if($null -eq $groupName -Or $groupName -eq "" ) {
        throw "New-AwsGroup: Parameter Error: groupName empty" 
    }

    $result =  aws iam create-group --group-name $groupName --profile $awsProfile 2>&1

    if($null -eq $result -ANd $result -like "{*") {
        return $result | ConvertFrom-Json 
    }  
    throw ("New-AwsGroup Error" + $result)    
}

function Get-AwsGroupPolicy {
    param([string]$awsProfile, [string]$groupName, [string]$policyName)
    if($null -eq $awsProfile -Or $awsProfile -eq "" ) {
        throw "Get-AwsGroupPolicy: Parameter Error: awsProfile empty" 
    }
    if($null -eq $groupName -Or $groupName -eq "" ) {
        throw "Get-AwsGroupPolicy: Parameter Error: groupName empty" 
    }
    
    if($null -eq $policyName -Or $policyName -eq "" ) {
        throw "Get-AwsGroupPolicy: Parameter Error: policyName empty" 
    }
    
    $result = aws iam list-attached-group-policies --group-name $groupName --profile $awsProfile 2>&1

    if($null -ne $result -And $result -like "{*") {
        return ($result.AttachedPolicies  | Where-Object PolicyName -EQ $policyName)
    }  
    throw ("Get-AwsGroupPolicy Error" + $result)  
}

function Get-AwsPolicyArn {
    param([string]$awsProfile, [string]$policyName)
    if($null -eq $awsProfile -Or $awsProfile -eq "" ) {
        throw "Get-AwsPolicyArn: Parameter Error: awsProfile empty" 
    }
    if($null -eq $policyName -Or $policyName -eq "" ) {
        throw "Get-AwsPolicyArn: Parameter Error: policyName empty" 
    }

    $query = "'Policies[?PolicyName==" + '`' + $policyName + '`' + "].{ARN:Arn}'"
    $result = aws iam list-policies --query $query --output text --profile $awsProfile 2>&1

    if($null -ne $result -And $result -ne "") {
        return $result 
    }  
    throw ("Get-AwsPolicyArn: Policy ${policyName} not found")     
}


function New-AwsPolicy {
    param([string]$awsProfile, [string]$policyName, [string]$policyFileName)
    if($null -eq $awsProfile -Or $awsProfile -eq "" ) {
        throw "New-AwsPolicy: Parameter Error: awsProfile empty" 
    }
    if($null -eq $policyName -Or $policyName -eq "" ) {
        throw "New-AwsPolicy: Parameter Error: policyName empty" 
    }
    if($null -eq $policyFileName -Or $policyFileName -eq "" ) {
        throw "New-AwsPolicy: Parameter Error: policyFileName empty" 
    }

    $result = aws iam create-policy --policy-name $policyName --policy-document file://$policyFileName --profile $awsprofile 2>&1

    if($null -ne $result -And $result -like "{*") {
        return $result
    }
    throw ("New-AwsPolicy Error:" + $result)
}


function New-AwsPolicyVersion {
    param([string]$awsProfile, [string]$policyArn, [string]$policyFileName)
    if($null -eq $awsProfile -Or $awsProfile -eq "" ) {
        throw "New-AwsPolicy: Parameter Error: awsProfile empty" 
    }
    if($null -eq $policyName -Or $policyName -eq "" ) {
        throw "New-AwsPolicy: Parameter Error: policyName empty" 
    }
    if($null -eq $policyFileName -Or $policyFileName -eq "" ) {
        throw "New-AwsPolicy: Parameter Error: policyFileName empty" 
    }

    $result = aws iam create-policy-version --set-as-default --policy-arn $policyArn --policy-document file://$policyFileName --profile $awsProfile 2>&1

    if($null -ne $result -And $result -like "{*") {
        return $result
    }
    throw ("New-AwsPolicyVersion Error:" + $result)
}


function Set-AwsPolicyToGroup {
    param([string]$awsProfile, [string]$groupName, [string]$policyName)
    if($null -eq $awsProfile -Or $awsProfile -eq "" ) {
        throw "Set-AwsPolicyToGroup: Parameter Error: awsProfile empty" 
    }
    if($null -eq $groupName -Or $groupName -eq "" ) {
        throw "Set-AwsPolicyToGroup: Parameter Error: groupName empty" 
    }
    if($null -eq $policyName -Or $policyName -eq "" ) {
        throw "Set-AwsPolicyToGroup: Parameter Error: policyName empty" 
    }

    $groupPolicyArn = Get-AwsPolicyArn -awsProfile $awsProfile -policyName $policyName

    $result =  aws iam attach-group-policy --group-name $groupName --policy-arn $groupPolicyArn --profile $awsProfile 2>&1

    if($null -eq $result -Or $result -eq "") {
        return
    }  
    throw ("Set-AwsPolicyToGroup Error:" + $result)      

}

function Get-AwsUser {
    param([string]$awsProfile, [string]$userName)
    if($null -eq $awsProfile -Or $awsProfile -eq "" ) {
        throw "Get-AwsUser: Parameter Error: awsProfile empty" 
    }
    if($null -eq $userName -Or $userName -eq "" ) {
        throw "Get-AwsUser: Parameter Error: userName empty" 
    }

    $result = aws iam list-users --profile $awsProfile 2>&1 

    if($null -ne $result -And $result -like "{*") {
        $users =  $result | ConvertFrom-Json 
        return ($users.Users | Where-Object UserName -EQ $userName)
    }  
    throw ("Get-AwsUser Error:" + $result) 
}

function New-AwsUserAndProfile {
    param([string]$awsProfile, [string]$userName)
    if($null -eq $awsProfile -Or $awsProfile -eq "" ) {
        throw "New-AwsUser: Parameter Error: awsProfile empty" 
    }
    if($null -eq $userName -Or $userName -eq "" ) {
        throw "New-AwsUser: Parameter Error: userName empty" 
    }

    $result = aws iam create-user --user-name $userName --profile $awsProfile 2>&1

    if($null -eq $result -Or !($result -like "{*")) {
        throw ("New-AwsUserAndProfile Error:" + $result)      
    }

    $password = "" + (Get-Random -Minimum 10000 -Maximum 99999 ) + "aA!"
    $result = aws iam create-login-profile --user-name $userName --password $password --password-reset-required --profile $awsProfile 2>&1

    if($null -ne $result -And $result -like "{*") {
        return $password 
    }
    throw ("New-AwsUserAndProfile Error:" + $result)      
    
}

function Test-AwsUserInGroup {
    param([string]$awsProfile, [string]$userName, [string]$groupName)
    if($null -eq $awsProfile -Or $awsProfile -eq "" ) {
        throw "Test-AwsUserInGroup: Parameter Error: awsProfile empty" 
    }
    if($null -eq $userName -Or $userName -eq "" ) {
        throw "Test-AwsUserInGroup: Parameter Error: userName empty" 
    }
    if($null -eq $groupName -Or $groupName -eq "" ) {
        throw "Test-AwsUserInGroup: Parameter Error: groupName empty" 
    }

    $result = aws iam list-groups-for-user --user-name $userName --profile $awsProfile 2>&1
    
    if($null -ne $result -And $result -like "{*") {
        $usergroups = $result | ConvertFrom-Json
        $group = ($usergroups.Groups | Where-Object GroupName -EQ $groupName)
        return ($null -ne $group)        
    }
    throw ("Test-AwsUserInGroup Error:" + $result)      
}


function Set-AwsUserGroup {
    param([string]$awsProfile, [string]$userName, [string]$groupName)
    if($null -eq $awsProfile -Or $awsProfile -eq "" ) {
        throw "Set-AwsUserGroup: Parameter Error: awsProfile empty" 
    }
    if($null -eq $userName -Or $userName -eq "" ) {
        throw "Set-AwsUserGroup: Parameter Error: userName empty" 
    }
    if($null -eq $groupName -Or $groupName -eq "" ) {
        throw "Set-AwsUserGroup: Parameter Error: groupName empty" 
    }

    $result = aws iam add-user-to-group --user-name $userName --group-name $groupName --profile $awsProfile 2>&1

    if($null -eq $result -Or $result -eq "") {
        return
    }  
    throw ("Set-AwsUserGroup Error:" + $result) 
}

function Set-AwsCodeBuildCredentials {
    param([string]$awsProfile, [string]$serverType, [string]$token)
    if($null -eq $awsProfile -Or $awsProfile -eq "" ) {
        throw "Set-AwsCodeBuildCredentials: Parameter Error: awsProfile empty" 
    }
    if($null -eq $serverType -Or $serverType -eq "" ) {
        throw "Set-AwsCodeBuildCredentials: Parameter Error: serverType empty" 
    }
    if($null -eq $token -Or $token -eq "" ) {
        throw "Set-AwsCodeBuildCredentials: Parameter Error: token empty" 
    }

    $result = aws codebuild import-source-credentials --server-type $serverType --auth-type PERSONAL_ACCESS_TOKEN --profile $awsProfile --token $token 2>&1

    if($null -ne $result -And $result -like "arn:*")  {
        return $result
    }

    throw ("Set-AwsCodeBuildCredentials failed")
}



function Get-TemplateParameters {
    param([string]$templatePath)
    if(Test-Path $templatePath) {
        #Read the yaml file and get the parameters
        $template = (Get-Content $templatePath | ConvertFrom-Yaml | ConvertTo-Json -Depth 100 | ConvertFrom-Json)
        $parameters = $template.Parameters 
        return $parameters
    } else {
        Write-Host "Warning: ${templatePath} was not found"
    }
}
function Get-SMF {
    param ([string]$filename="smf.yaml")

    Test-YamlInstalled

    if(Test-Path $filename) {
        # Read smf.yaml 
        # ConvertFrom-Yaml returns a HashTable
        # note: ConvertFrom-Json returns a PSCustomObject and doesn't preserve property order so we don't use it
        # We want a consistent format that preserves property order so we use a HashTable
        Write-Host " Loading existing SMF settings file."
        $org = Get-Content $filename | ConvertFrom-Yaml -ordered
        return $org
    } else {
        Write-Host " Creating new SMF settings file:"
        # Create default Settings object
        $OrgCode = Read-String `
                -prompt "Please enter OrgCode" `
                -required $true `
                -indent 4
        }        

    #AwsMgmtProfile 
    $default = $OrgCode + "Mgmt"
    $awsMgmtProfile = Read-AwsProfileName `
        -prompt "Enter AWS CLI Managment Account (default: ${default})" `
        -default $default `
        -indent 4

    $awsRegion = Read-AwsRegion $awsMgmtProfile -default "us-east-1" -indent 4

    $gitHubAcctName = Read-String `
        -prompt "    Enter your GitHub Management Acct Name"
    
    $gitHubOrgName = Read-String `
        -prompt "    Enter your GitHub Organization Name"

    $tutorialRepo = "https://github.com/${gitHubOrgName}/Petstore.git"
    $defmsg = Get-DefMessage -default $tutorialRepo
    $tutorialRepo = Read-String `
        -prompt "Tutorial Repo${defmsg}" `
        -default $tutorialRepo `
        -indent 4

    $utilRepo = "https://github.com/${gitHubOrgName}/LazyStackSmfUtil.git"
    $defmsg = Get-DefMessage -default $utilRepo
    $utilRepo = Read-String `
        -prompt "LazyStack Util Repo${defmsg}" `
        -default $utilRepo `
        -indent 4


    $org = [ordered]@{
        $OrgCode = [ordered]@{
            AWS = [ordered]@{
            awsProfile=$awsMgmtProfile
            DefaultRegion=$awsRegion
                OrgUnits= @(
                    "DevOU"
                    "TestOU"
                    "ProdOU"
                )
            }
            Sources = @{
                GitHub = [ordered]@{
                    Type = "GitHub"
                    AcctName = $gitHubAcctName
                    OrgName = $gitHubOrgName
                }
            }
            Systems = [ordered]@{
                Tut = [ordered]@{
                    Description = "Tutorial System"
                    Accounts = [ordered]@{
                        Test = [ordered]@{
                            Type="Test"
                            Description="Test System Account"
                            Pipelines = [ordered]@{
                                Test_PR_Create = [ordered]@{
                                    Description = "Create PR Stack on Pull Request Creation"
                                    TemplatePath = "../LazyStackSMF/Test_CodeBuild_PR_Create.yaml"                               
                                    Region = $awsRegion
                                    TemplateParameters = [ordered]@{
                                        RepoParam = $tutorialRepo 
                                        UtilRepoParam = $utilRepo
                                    }
                                }
                                Test_PR_Merge = [ordered]@{
                                    Description = "Delete PR Stack on Pull Request Merge"
                                    TemplatePath = "../LazyStackSMF/Test_CodeBuild_PR_Merge.yaml"
                                    Region = $awsRegion
                                    TemplateParams = [ordered]@{
                                        RepoParam = $tutorialRepo 
                                    }
                                }
                            }
                        }
                        Prod = [ordered]@{
                            Type="Prod"
                            Description="Prod System Account"
                            Pipelines = [ordered]@{
                                Prod_PR_Merge = [ordered]@{
                                    Description = "Update Production Stack on Pull Request Merge"
                                    TemplatePath = "../LazyStackSMF/Prod_CodeBuild_PR_Merge.yaml"
                                    Region = $awsRegion
                                    TemplateParams = [ordered]@{
                                        RepoParam = $tutorialRepo 
                                        UtilRepoParam = $utilRepo
                                        ProdStackNameParam = $awsRegion + "-petstore"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    return $org
}
function Get-Indent{
    param ([int]$indent)
    $indentstr =  " "*$indent
    return $indentstr
}
function Set-SMF {
    param ($settings, [string]$filename="smf.yaml")
    if($null -eq $settings ) {
        #fatal error, terminate calling script
        Write-Host "Error: Set-Settings settings parameter can not be null"
        exit
    }
    Set-Content -Path $filename -Value ($settings | ConvertTo-Yaml) 
}
function Write-SMF {
    param ([PSCustomObject]$settings)
    Write-Host  ($settings | ConvertTo-Yaml) 
}
function Read-Repo {
    param ([string]$prompt, [string]$owner, [string]$reponame, [bool]$exists=$false, [int]$indent=0)
    $indentstr = " " * $indent
    do {
        $defmsg = Get-DefMessage -default $owner 
        $owner = Read-String `
            -prompt ($indentStr + $prompt + "Owner${defmsg}") `
            -default $owner
        $defmsg = Get-DefMessage -default $reponame
        $reponame = Read-String `
            -prompt ($indentStr + $prompt + "Name${defmsg}") `
            -default $reponame

        $repo = ($owner + "/" + $repoName)
        
        $found = Get-GitHubRepoExists $repo
        
        $ok = ($found -eq $exists) 
        if(!$ok) {
            if($exists) {
                Write-Host "${indentstr}Sorry, that reposiory does not exists. Please try again"
            } else {
                Write-Host "${indentstr}Sorry, that repository exists. Please try again."
            }
        } 
    } until ($ok)
    return  $owner, $reponame, $repo
}
function Set-GhSession {
    param( [bool]$exitOnError=$true)
    $found = Test-Path "GitAdminToken.pat"
    if(!$found)  {
        Write-Host "Missing GitAdminToken.pat file." 
        exit
    }
    [string]$output = (Get-Content GitAdminToken.pat | gh auth login --with-token 2>&1)
    if($null -ne $output) {
        $firstToken = $output.split(' ')[0]
        if($firstToken -eq "error") {
            if($exitOnError) {
                Write-Host "gh could not authenticate with token provided."
                exit
            } else {
                return $false
            }
        }
    }
    # gh auth status
    return $true
}
function Get-GitHubRepoURL {
    param ([string]$reponame)
    return  "https://github.com/" + $reponame + ".git"
}
function Get-GitHubRepoExists {
    param ([string]$reponame)
    [string]$output = (gh repo view $reponame)  2>&1
    $output = $output.Substring(0,5)
    # valid responses will start with "name: ", anything else is an error
    return  ($output -eq "name:")
}
function New-Repository {
    param (
        [string]$orgName
    )
    Write-Host "    Repository creation options:
    1. Create Tutorial Stack (ex: gh repo create ${orgName}/PetStore -p InSciCo/PetStore -y -private)
    2. Create from repository template (ex: gh repo create ${orgName}/newrepo -p ${orgName}/templaterepo -y -private)
    3. Reference an existing repository"
    $repoOption = Read-MenuSelection -min 1 -max 3 -indent 4 -options "q"
    if($repoOption -eq -1) {
        return $false, ""
    }

    # Login to GitHub
    Set-GhSession

    switch($repoOption) {

        1 {
            $sourceRepo = "InSciCo/PetStore"
            $targetOwner=$orgName
            $defmsg = Get-DefMessage -default "PetStore"
            $targetOwner, $targetReponame, $targetRepo = Read-Repo `
                -prompt "New Repository" `
                -owner $orgName `
                -reponame "PetStore" `
                -indent 4 


            Write-Host "    This option creates a LazyStack PetStore tutorial repository in your GitHub Organization"
            Write-Host "    Source Repository:" $sourceRepo 
            Write-Host "    New Repository:" $targetRepo
            $ghParameters = "--confirm --private"
        }
        2 {
            Write-Host "    This option creates a new repository from a template repository"
            $owner, $reponame, $sourceRepo = Read-Repo `
                -prompt "Source Template Repository " `
                -owner $orgName `
                -exists $true `
                -indent 4

            $targetOwner, $targetReponame, $targetRepo = Read-Repo `
                -prompt "New Repository " `
                -owner $orgName `
                -exists $false `
                -indent 4

            $ghParameters = "--confirm --private"
        }
        3 {
            Write-Host "This option configures the stack to use an existing repository"
            $targetOwner, $targetReponame, $targetRepo = Read-Repo `
                -prompt "Existing Repository " `
                -owner $orgName `
                -exists $true `
                -indent 4
        }
    }

    if($repoOption -ne 3) {
        $defmsg = Get-DefMessage -default $ghParameters
        $ghParameters = Read-String `
            -prompt "gh command parameters${defmsg}" `
            -default $ghParameters `
            -indent 4                 

        switch($repoOption) {
            1 {
                #Write-Host "PRINT: gh repo create $targetRepo -Pipeline $SourceRepo  $ghParameters"
                $output = Invoke-Expression "gh repo create $targetRepo --Pipeline $SourceRepo $ghParameters"
                #remove clone created in sub folder

                if(Test-Path $targetReponame) {
                    Write-Host "    Removing temporary clone from settings folder"
                    Remove-Item $TargetReponame -Recurse -Force
                }
            }
            2 {
                #Write-Host "PRINT: gh repo create $targetRepo --Pipeline $SourceRepo  $ghParameters"
                $output = Invoke-Expression "gh repo create $targetRepo --Pipeline $SourceRepo $ghParameters"
                #remove clone created in sub folder
                if(Test-Path $targetReponame) {
                    Write-Host "    Removing temporary clone from settings folder"
                    Remove-Item $targetReponame -Recurse -Force
                }                        
            }
        }
        if(!(Get-GitHubRepoExists -reponame $targetRepo)) {
            Write-Host "    Error: The new repository was not created successfully on GitHub"
            return $false, ""
        }            
    }
    
    return $true, $targetRepo   
}



function New-AwsSysAccount {
    param (
        [string]$LzMgmtProfile,
        [string]$LzRootId,
        [string]$LzOrgUnitId, 
        [string]$LzAcctName, 
        [string]$LzIAMUserName,
        [string]$LzRootEmail,
        [string]$LzRegion,
        [int]$indent
    )
    $indentstr = " " * $indent

    #Check if accont already exists 


    # Create Test Account  -- this is an async operation so we have to poll for success
    # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/create-account.html
    Write-Host "Creating System Account: ${LzAcctName}" 
    $LzAcct = New-AwsAccount -awsProfile $LzMgmtProfile -acctName $LzAcctName -email $email
    $LzAcctId = $LzAcct.CreateAccountStatus.Id

    # poll for success
    # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/describe-create-account-status.html
    $LzAcctCreationCheck = 1
    do {
        Write-Host "    - Checking for successful account creation. TryCount=${LzAcctCreationCheck}"
        Start-Sleep -Seconds 5
        $LzAcctStatus = Get-AwsAccountStatus -awsProfile $LzMgmtProfile -acctId $LzAcctId
        $LzAcctCreationCheck = $LzAcctCreationCheck + 1
    }
    while ($LzAcctStatus.CreateAccountStatus.State -eq "IN_PROGRESS")

    if($LzAcctStatus.CreateAccountStatus.State -ne "SUCCEEDED") {
        Write-Host $LzAcctStatus.CreateAccountStatus.FailureReason
        exit
    }

    $LzAcctId = $LzAcctStatus.CreateAccountStatus.AccountId
    Write-Host "    - ${LzAcctName} account creation successful. AccountId: ${LzAcctId}"


    # Check if account is in OU
    $LzOUChildren = Get-AwsOrgUnitAccounts -awsProfile $LzMgmtProfile -ouId $LzOrgUnitId 
    $LzOUChild = $LzOUChildren.Children | Where-Object Id -EQ $LzAcctId
    if($null -ne $LzOUChild) {
        Write-Host "${LzAcctName} already in ${LzOUName} so skipping account move."
    }
    else {
        # Move new Account to OU
        # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/move-account.html
        Write-Host "    - Moving ${LzAcctName} account to ${LzOUName} organizational unit"
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
    Write-Host "Adding or Updating ${LzAccessRole} profile and associating it with the ${LzMgmtProfile} profile. "
    Set-AwsProfileRole -awsProfile $LzMgmtProfile -accessprofile $LzAccessRoleProfile -region $LzRegion

    # Create Administrators Group for Test Account
    # Reference: https://docs.aws.amazon.com/cli/latest/userguide/cli-services-iam-new-user-group.html

    $awsgroups = Get-AwsGroups -awsProfile $LzAccessRoleProfile
    $group = ($awsgroups.Groups | Where-Object GroupName -EQ "Administrators")
    if($null -eq $group) {
        Write-Host "Creating Administrators group in the ${LzAcctName} account."
        New-AwsGroup -awsProfile $LzAccessRoleProfile -groupName Administrators
    } else {
        Write-Host "Administrators group exists in the ${LzAcctName} account."
    }

    # Add policies to Group
    $policy = Get-AwsGroupPolicy -awsProfile $LzAccessRoleProfile -groupName Administrators -policyName AdministratorAccess
    if($null -ne $policy) {
        Write-Host "    - Policy AdministratorAccess already in Administrators group"
    } else {
        Write-Host "    - Adding policy AdministratorAccess"
        Set-AwsPolicyToGroup -awsProfile $LzAccessRoleProfile -groupName Administrators -policyName AdministratorAccess
    }

    # Create User in Account
    Get-AwsUser -awsProfile $LzAccessRoleProfile -userName $LzIAMUserName 
    if($null -ne $user) {
        Write-Host "IAM User ${LzIAMUserName} already in ${LzAcctName} account."
    } else {
        # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/iam/create-user.html
        Write-Host "Creating IAM User ${LzIAMUserName} in ${LzAcctName} account."
        $LzPassword = New-AwsUserAndProfile -awsProfile $LzAccessRoleProfile -userName $LzIAMUserName 

        # Output Test Account Creds
        Write-Host "    - Writing the IAM User Creds into ${LzIAMUserName}_creds.txt"
        $nl = [Environment]::NewLine
        $LzOut = "User name,Password,Access key ID,Secret access key,Console login link${nl}"
        + $LzAcctName + "," + $LzPassword + ",,," + "https://${LzAcctId}.signin.aws.amazon.com/console"

        $LzOut > ${LzIAMUserName}_credentials.csv
    }

    # Add user to Group 

    $userInGroup = Test-AwsUserInGroup -awsProfile $LzAccessRoleProfile -userName $LzIAMUserName -groupName Administrators
    if($userInGroup) {
        Write-Host "    - IAM User ${LzIAMUserName} is already in the Admnistrators group in the ${LzAcctName} account."
    } else {
        Write-Host "    - Adding the IAM User ${LzIAMUserName} to the Administrators group in the ${LzAcctName} account."
        Set-AwsUserGroup  -awsProfile = $LzAccessRoleProfile -userName $LzIAMUserName -groupName Administrators
    }

    #update GitHub Personal Access Token
    $LzPat = Get-Content -Path GitCodeBuildToken.pat
    Set-AwsCodeBuildCredentials -awsProfile $LzAccessRoleProfile -serverType GITHUB -token $LzPat
    return $true
}

function Get-ValidAwsStackName {
    param([string]$name)
    $chars = $name.toCharArray()
    $newName = New-Object char[] $chars.Length
    $i = 0

    foreach($c in $chars) {
        if( ($c -ge 'A' -And $c -le "Z")  -Or ($c -ge 'a' -And $c -le "z")  -Or ($c -ge '0' -And $c -le '9') -Or $c -eq "-" ) {
            $newName[$i] = $c
        } else  {
            $newName[$i] = '-'
        }
        $i += 1
    }
    $stackName = -Join $newName
    if($newName[0] -eq '-') {
        Write-Host "Error: Invalid StackName '${stackName}' Can't start with a '-' "
        exit
    }

    return $stackName
}

function Publish-Pipeline {
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
function Read-AccountType {
    param([string]$default, [int]$indent)
    $indentstr = " " * $indent
    $defmsg = Get-DefMessage -default $default
    Write-Host "${indentstr}1) System Test Account"
    Write-Host "${indentstr}2) System Production Account"
    $selection = Read-MenuSelection -min 1 -max 2 -prompt "Type ${defmsg}" -indent $indent -options ""
    switch($selection) {
        1 {return "Test"}
        2 {return "Prod"}
    }
}
function Write-System {
    param ([PSCustomObject]$object, [string]$curSystem, [int]$indent)
    $systemObj = $object.$curSystem 

    $indentstr = " " * $indent
    Write-Host "${indentstr}System:" $curSystem 
    Write-Host "${indentstr}  Description:" $systemObj.Description
    Write-Accounts $object.$curSystem ($indent + 2)
}
function Write-Accounts {
    param([PSCustomObject]$systemObj, [int]$indent)
    $indentstr = " " * $indent
    Write-Host "${indentstr}Accounts:"
    $systemObj.Accounts  | Get-Member -MemberType NoteProperty | ForEach-Object {
        Write-Account $systemObj.Accounts $_.Name ($indent + 2) 
    }    
}
function Write-Account {
    param([PSCustomObject]$object, [string]$curAccount, [int]$indent)
    $indentStr = " " * $indent
    $accountObj = $object.$curAccount
    Write-Host "${indentstr}Account:" $curAccount
    Write-Host "${indentstr}  OrgUnit:" $accountObj.OrgUnit 
    Write-Host "${indentstr}  Email:" $accountObj.Email 
    Write-Host "${indentstr}  IAMUser:" $accountObj.IAMUser
    Write-Pipelines $accountObj ($indent + 2)
}
function Write-Pipelines {
    param([PSCustomObject]$accountObj, [int]$indent )
    $indentstr = " " * $indent
    Write-Host "${indentstr}Pipelines:"
    $accountObj.Pipelines | Get-Member -MemberType NoteProperty | ForEach-Object {
        Write-Pipeline $accountObj.Pipelines $_.Name ($indent + 2)
    }
}
function Write-Pipeline {
    param([PSCustomObject]$object, [string]$curPipeline, [int]$indent) 
    $indentstr = " " * $indent 
    Write-Host "${indentstr}Pipeline:" $curPipeline 
    $curPipelineObj = $object.$curPipeline 
    Write-Host "${indentstr}  Template:" $curPipelineObj.TemplatePath
    Write-Host "${indentstr}  Description:" $curPipelineObj.Description
    Write-Host "${indentstr}  Region:" $curPipelineObj.Region
    Write-Host "${indentstr}  Parameters defined in template:"
    $fixedArgs = @("TemplatePath","Description", "Region")
    $templatePath = $curPipelineObj.TemplatePath
    if($null -ne $templatepath -And (Test-Path $templatePath)) {
        $parameters = Get-TemplateParameters $templatePath
        $parameters | Get-Member -MemberType NoteProperty | ForEach-Object {
            $name = $_.Name 
            if($fixedArgs -contains $name) {continue}

            # Check if the template parameter is in the Pipeline object; it may have been added after initial assignment.
            if(Get-PropertyExists $curPipelineObj $name) {
                Write-Host "${indentstr}   " ($name + ":") $curPipelineObj.$name
            } else {
                Write-Host "${indentstr}   " ($name + ": new parameter") 
            }
        }
    }
}
