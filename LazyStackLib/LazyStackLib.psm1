#LazyStackLib.psm1

function Get-LibVersion {
    "v1.0.0"
}
function Read-YesNo {
    Param ([string]$prompt, [boolean]$default=$true, [int]$indent)
    $indentstr = " " * $indent
    if ($default) { 
        $defmsg = " (Y/n)" 
    } else {
        $defmsg = " (y/N)"
    }
    do {
        $value = Read-Host "${indentstr}${prompt}${defmsg}"
        switch ($value) {
            "y" { return ,$true}
            "n" { return ,$false}
            "" {return, $default}
        }
    } until ($false)
}
function Read-Int {
    Param ([string]$prompt,[int]$default, [int]$min, [int]$max, [int]$indent)
    $indentstr = " " * $indent
    if($default -ge $min -And $default -le $max)  {
        $defmsg = "(default: ${default})"
    }

    do {
        $value = Read-Host ($indentstr + $prompt + $defmsg)
        if($value -eq ""){
            $intvalue = $default 
        }else{
            $intvalue = [int]$value
        }
        $isvalid = ($intvalue -ge $min -And $intvalue -le $max)
        if(!$isvalid) {
            Write-Host "${indentstr}Value must be between ${min} and ${max}. Please try again."
        }
    } until ($isvalid)
   
    return ,$intvalue
}
function Read-MenuSelection{
    param([string]$prompt="Select",[int]$min=1,[int]$max,[int]$indent=0,[string]$options="adq")
    $indentstr = " " * $indent
    if($max -gt 0) {
        $options += "#"
    }
    $options = $options.ToLower()
    $opArray = $options.ToCharArray()
    $firstOption = $true
    $op = ""
    foreach($option in $opArray){
        if(!$firstOption) {$op += ", "}
        Switch($option) {
            'a' { $op += "A)dd"}
            'd' { $op += "D)elete" }
            'q' { $op += "Q)uit" }            
            '#' { $op += "#" }
            default {
                Write-Host "Error: Read-MenuSelect passed bad -options specification |${options}|"
            }
        }
        $firstOption =$false
    }
    if($op.Length -gt 0) {$op = " [" + $op + "]"}

    do{
        try {
            $selection = Read-Host ($indentstr + $prompt + $op)
            if($opArray -contains 'q' -And $selection -eq "q"){ return  -1 }
            if($opArray -contains 'a' -And $selection -eq "a") { return -2 }
            if($opArray -contains 'd' -And $selection -eq "d" -And $max -gt 0) { return -3 }
            if($max -ge $min) {
                $selection = [int]$selection
                if($selection -lt $min -Or $selection -gt $max) {
                    Write-Host ($indentstr + "Selection value must be between ${min} and ${max}")
                } else {
                    return $selection
                }
            }
            throw
        } catch {
            Write-Host "Invalid entry, try again."
        }
    } until ($false)
}
function Read-Email {
    Param ([string]$prompt,[string]$default, [int]$indent)
    $indentstr = " " * $indent
    Write-Host "${indentstr}Note: An email address can only be associated with one AWS Account."
    do {
        $email = Read-Host $prompt
        if($email -eq ""){
            $email = $default
        }
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
        if("" -ne $default) {
            Set-Clipboard $value
        }
        $value = Read-Host  ($indentstr + $prompt)
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
function Read-FileName {
    Param ([string]$prompt, [string]$default, [int]$indent, [boolean]$required = $false)
    $indentstr = " " * $indent
    do {
        $strinput = Read-String -prompt $prompt -default $default -indent $indent -required $required
        if($strinput -ne "" -And $required) {
            $found = (Test-Path $strinput)
            if(!$found) {
                Write-Host "${indentstr}Sorry, that file was not found. Please try again."
            }
        } else { return ,""}
    } until ($found)
    return , $strinput
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
function Get-MsgIf {
    param ([bool]$boolval, [string]$msg)
    if($boolval) {
        return ,$msg
    } else { return ,""}
}
function Get-MsgIfNot {
    param ([bool]$boolval, [string]$msg)
    if(!$boolval) {
        return ,$msg
    } else { return ,""}
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
function Get-RepoShortName {
    param([string]$repourl)
    $urlparts=$repourl.Split('/')
    $LzRepoShortName=$urlparts[$urlparts.Count - 1]
    $LzRepoShortName=$LzRepoShortName.Split('.')
    $LzRepoShortName=$LzRepoShortName[0].ToLower()    
    return ,$LzRepoShortName
}
function Test-AwsProfileExists {
    param ([string]$profilename)
    $list = aws configure list-profiles
    $list -contains $profilename
}
function Get-IsRegionAvailable {
    param ([string]$mgmtAcctProfile, [string]$regionName)
    $regions = aws ec2 describe-regions --all-regions --profile $mgmtAcctProfile | ConvertFrom-Json
    $region = $regions.Regions | Where-Object RegionName -EQ $regionName
    return , $null -ne $region
}
function Read-AwsRegion {
    param ([string]$mgmtAcctProfile, [string]$prompt="Enter AWS Region", [string]$default, [int]$indent)
    $indentstr = " " * $indent1
    if("" -ne $default) { $defstr = "(${default})"} else {$defstr = ""}
    do {
        $regionname = Read-Host "${indentstr}${prompt}${defstr}"
        $found = Get-IsRegionAvailable -mgmtAcctProfile $mgmtAcctProfile -regionName $regionname
        if(!$found) {
            Write-Host "${indentstr}Sorry, that region is not available. Please try again."
        }
    } until ($found)
    return ,$regionName
}
function Read-AwsProfileName {
    param ([string]$prompt, [string]$default, [int]$indent=0)
    $indentstr = " " * $indent
    do {
        $inputvalue = (Read-String `
            -prompt $prompt `
            -default $default `
            -indent $indent) 
        $found = Test-AwsProfileExists -profilename $inputvalue
        if(!$found) {
            Write-Host "${indentstr}AWS AWS CLI Managment Account Profile ${inputvalue} Not Found!"        
            Write-Host "${indentstr}Please try again."
        }
    } until ($found)    
    return ,$inputvalue
}
 function Get-AwsOrgRootId{
    param([string]$mgmtAcctProfile)
    # Get LzRootId - note: Currently, there should only ever be one root.
    # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/list-roots.html
    [string]$output = aws organizations list-roots --profile $mgmtAcctProfile 2>&1
    $output = $output.Replace(" ", "")
    # Catch error by examining return
    if($output.Substring(2,5) -ne "Roots") {
        return , ""
    }
    $LzRoots = $output | ConvertFrom-Json 
    $LzRootId = $LzRoots.Roots[0].Id
    return ,$LzRootId
 }
function Get-SettingsPropertyCount {
    param($object, [string]$property)
    if($null -eq $object -Or $object.GetType().Name -ne "PSCustomObject" ) { 
        return 0
    }
    return ($object | Get-Member -MemberType NoteProperty).Count
}
function Add-SettingsProperty {
    param([PSObject]$object, [string]$property, $default=$null)

    if($null -eq $object) { 
        Write-Host "Error: null object passed to Add-SettingsProperty"
        exit
    }
    switch($object.GetType().Name) {
        "HashTable" {
             Write-Host "Error: HashTable found in call to Add-SettingsProperty. Use PSCustomObject instead."
             exit
        }
        "PSCustomObject" {
            if($object.PSObject.Members.Match($property, 'NoteProperty').Count -eq 0 ) {
                $object = $object | Add-Member -NotePropertyName $property -NotePropertyValue $default
            } else {
                if($null -ne $default) {
                    if($null -ne $object.$property) {
                        $object.$property = $default
                    }
                }
            }
        }
        default {
            Write-Host "Error: Invalid Object Type passed in Add-SettingsProperty: " $object.GetType()
            exit
        }
    }
}
function Get-SettingsPropertyExists {
    param([PSObject]$object, [string]$property)
    if($null -eq $object) { 
        Write-Host "Error: null object passed to Add-SettingsProperty"
        exit
    }

    switch($object.GetType().Name) {
        "HashTable" {
            Write-Host "Error: HashTable found in call to Add-SettingsProperty. Use PSCustomObject instead."
            exit
            #return [bool](($object.GetEnumerator() | Where-Object Name -eq $property).Count -gt 0) 
        }
        "PSCustomObject" {
            $propList = ($object | Get-Member -Name $property)
            return [bool]($propList.Count -gt 0)
        }
        default {
            Write-Host "Error: Invalid Object Type passed in Get-PropertyExists: " $object.GetType()
            exit
        }
    }
}
function Remove-SettingsProperty {
    param([PSObject]$object, [string]$property)
    if($null -eq $object) { 
        Write-Host "Error: null object passed to Remove-SettingsProperty"
        exit
    }

    switch($object.GetType().Name) {
        "HashTable" {
            Write-Host "Error: HashTable found in call to Remove-SettingsProperty. Use PSCustomObject instead."
            exit
        }
        "PSCustomObject" {
            if(($object | Get-Member -Name $property) -eq 0) {
                return
            }
            
            $object.PSObject.Members.Remove($property)
        }
        default {
            Write-Host "Error: Invalid Object Type passed in Get-PropertyExists: " $object.GetType()
            exit
        }
    }    
}
function Get-LzSettings {
    param ([string]$filename="Settings.yaml")

    if(Test-Path $filename) {
        # Read Settings.json to create Settings object
        # note: ConvertFrom-Yaml returns a HashTable
        # note: ConvertFrom-Json returns a PSCustomObject
        # We need a consistent format so covert twice to always have a PSCustomObject
        $org = Get-Content $filename | ConvertFrom-Yaml | ConvertTo-Json -Depth 100 | ConvertFrom-Json 
        return ,$org
    } else {
        Write-Host "   Creating new settings file:"
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


        $org = [PSCustomObject]@{
            OrgCode=$OrgCode
            AWS = [PSCustomObject]@{
               MgmtProfile=$awsMgmtProfile
               DefaultRegion="us-east-1"
               OrgUnits= [PSCustomObject]@{
                   DevOU=$OrgCode+"DevOU"
                   TestOU=$OrgCode+"TestOU"
                   ProdOU=$OrgCode+"ProdOU"
               }
            }
            Sources = [PSCustomObject]@{
                GitHub = [PSCustomObject]@{
                    Type = "GitHub"
                    AcctName = ""
                    OrgName = ""
                    Repos = [PSCustomObject]@{
                        PetStore = ""
                        LazyStackSMF = ""
                    }
                }
            }
            PipelineTemplates = [PSCustomObject]@{
                Test_PR_Create = [PSCustomObject]@{
                    Description = "Create PR Stack on Pull Request Creation"
                    TemplatePath = "../LazyStackSMF/Test_CodeBuild_PR_Create.yaml"
                    RepoParam = '$Sources.GitHub.Repos.PetStore'
                    UtilRepo = '$Sources.GitHub.Repos.LazystackSMF'
                    Region = '$AWS.DefaultRegion'
                }
                Test_PR_Merge = [PSCustomObject]@{
                    Description = "Delete PR Stack on Pull Request Merge"
                    TemplatePath = "../LazyStackSMF/Test_CodeBuild_PR_Merge.yaml"
                    RepoParam = '$Sources.GitHub.Repos.PetStore'
                    UtilRepo = '$Sources.GitHub.Repos.LazystackSMF'
                    Region = '$AWS.DefaultRegion'
                }
                Prod_PR_Merge = [PSCustomObject]@{
                    Description = "Update Production Stack on Pull Request Merge"
                    TemplatePath = "../LazyStackSMF/Prod_CodeBuild_PR_Merge.yaml"
                    RepoParam = '$Sources.GitHub.Repos.PetStore'
                    UtilRepo = '$Sources.GitHub.Repos.LazystackSMF'
                    Region = '$AWS.DefaultRegion'
                    StackName = 'us-east-1-petstore'
                }
            }
            Systems = [PSCustomObject]@{
                Tut = [PSCustomObject]@{}
            }
        }

    $testAccount = [PSCustomObject]@{
        OrgUnit = $OrgCode + "TestOU"
        Email = ""
        IAMUser = $OrgCode + "TutTestIAM"
        Pipelines = [PSCustomObject]@{
            Test_PR_Create = [PSCustomObject]@{
                PipelineTemplate = '$Pipelines.Test_PR_Create'
            }
            Test_PR_Merge = [PSCustomObject]@{
                PipelineTemplate = '$Pipelines.Test_PR_Merge'
            }
        }
    }
    $acctName = $OrgCode + "Test"
    Add-SettingsProperty $org.Systems.Tut $acctName $testAccount

    $prodAccount = [PSCustomObject]@{
        OrgUnit = $OrgCode + "TProdOU"
        Email = ""
        IAMUser = $OrgCode + "TutProdIAM"
        Pipelines = [PSCustomObject]@{
            Prod_PR_Merge = [PSCustomOBject]@{
                PipelineTemplate = '$Pipelines.Prod_PR_Merge'
            }
        }
    }

    $acctName = $OrgCode + "Prod"
    Add-SettingsProperty $org.Systems.Tut $acctname $prodAccount 

    return ,$org
}
function Set-LzSettings {
    param ([PSCustomObject]$settings, [string]$filename="Settings.yaml")
    if($null -eq $settings ) {
        #fatal error, terminate calling script
        Write-Host "Error: Set-Settings settings parameter can not be null"
        exit
    }
    # the following convert through JSON is necessary because ConvertTo-Yaml doesn't pick up 
    # objecgt members added with Add-Member
    Set-Content -Path $filename -Value ($settings | ConvertTo-Json -Depth 100 | ConvertFrom-Json | ConvertTo-Yaml) 
}
function Write-LzSettings {
    param ([PSCustomObject]$settings)
    Write-Host  ($settings | ConvertTo-Json -Depth 100 | ConvertFrom-Json | ConvertTo-Yaml) 
}
function Set-MissingMsg {
    param ([string]$value, [string]$msg="(required - please provide)")
    if($value -eq "") {
        return $msg
    } else {
        return $value
    }
}
function Write-PropertyNames {
    param($object, [string]$prefix="- ", [int]$indent=4, [int]$item=0)
    
    $indentstr = " " * $indent
    if($null -eq $object -Or $object.GetType().Name -ne "PSCustomObject" ) { 
        return 
    }
    
    $object | Get-Member -MemberType NoteProperty | ForEach-Object {
        $item = $item + 1
        $name = $_.Name
        switch($prefix) {
            "linenumber" {
                Write-Host (($indentstr) + [string]$item + ")" + $name)
            }
            default {
                Write-Host (($indentstr) + $prefix + $name)
            }
        }
    }
}
function Write-Properties {
    param($object, [string]$prefix="- ", [int]$indent=4, [int]$item=0)
    
    $indentstr = " " * $indent
    if($null -eq $object -Or $object.GetType().Name -ne "PSCustomObject" ) { 
        return 
    }
    
    $object | Get-Member -MemberType NoteProperty | ForEach-Object {
        $item = $item + 1
        $name = $_.Name
        $value = $_.Value
        switch($prefix) {
            "linenumber" {
                Write-Host (($indentstr) + [string]$item + ")" + $name + ": " + $value)
            }
            default {
                Write-Host (($indentstr) + $prefix + $name + ": " + $value)
            }
        }
    }
}
function Write-PropertySelectionMenu {
    param ($object, `
    [string]$addPrompt="Add", `
    [string]$selectItemPrompt="",`
    [string]$ifNoneMsg="(none defined yet)", `
    [int]$item=0, `
    [int]$indent)
    
    if($null -eq $object -Or $object.GetType().Name -ne "PSCustomObject" ) { return 0}
    $indentstr = " " * $indent
    $hasItems = (Get-SettingsPropertyCount $object) -gt 0
    if($hasItems) {
        $menuSelections = @{}
        $object | Get-Member -MemberType NoteProperty | ForEach-Object {
            $item = $item + 1 
            $val = $_.Name
            
            Write-Host ($indentstr + "${item})" + ${selectItemPrompt} + $val)
            $menuSelections.Add($item,$val)
        }
    } else {
        Write-Host "${indentstr}(No Items)"
    }
    return $item, $menuSelections
} 

function Read-PropertyName {
    param ([PSCustomObject]$parentObject,[string]$prompt="Name", [string]$propertyName="", [bool]$exists=$false, [int]$indent=0)

    $indentstr = " " * $indent 
    $default = $propertyName
    $defmsg = Get-DefMessage -default $default
    do {
        $propertyName = Read-String `
            -prompt "${prompt}${defmsg}" `
            -indent $indent `
            -default $propertyName
        $found = $parentObject.PSObject.Members.Match($propertyName,'NoteProperty').Count -eq 1
        $ok = ($found -And $exists) 
        if(!$ok) {
            if($exists) { 
                Write-Host "${indentstr}Sorry, that name does not exist. Please try again."
            } else {
                Write-Host "${indentstr}Sorry, That name already exists. Please try again."
            }
        }
    } until ($ok)
    return ,$propertyName
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
    $found = Test-Path "GitAdminToken.pat"
    if(!$found)  {
        Write-Host "Missing GitAdminToken.pat file." 
        exit
    }
    [string]$output = (Get-Content GitAdminToken.pat | gh auth login --with-token) 2>&1 
    if($null -ne $output) {
        $firstToken = $output.split(' ')[0]
        if($firstToken -eq "error") {
            Write-Host "gh could not authenticate with token provided."
            exit
        }
    }
    gh auth status
}

function Get-GitHubRepoURL {
    param ([string]$reponame)
    return , "https://github.com/" + $reponame + ".git"
}

function Get-GitHubRepoExists {
    param ([string]$reponame)
    [string]$output = (gh repo view $reponame)  2>&1
    $output = $output.Substring(0,5)
    # valid responses will start with "name: ", anything else is an error
    return , ($output -eq "name:")
}

function New-Repositry {
    param (
        [string]$orgName
    )
    Write-Host ""
    Write-Host "Add Stack"
    $orgName = $LzOrgSettings.GitHubOrgName
    Write-Host "    Repository creation options:k
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
            $targetOwner=$OrgName
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
                -owner $Org.GitHubOrgName `
                -exists $true `
                -indent 4

            $targetOwner, $targetReponame, $targetRepo = Read-Repo `
                -prompt "New Repository " `
                -owner $Org.GitHuborgName `
                -exists $false `
                -indent 4

            $ghParameters = "--confirm --private"
        }
        3 {
            Write-Host "This option configures the stack to use an existing repository"
            $targetOwner, $targetReponame, $targetRepo = Read-Repo `
                -prompt "Existing Repository " `
                -owner $Org.GitHubOrgName `
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

function New-LzSysAccount {
    param (
        [string]$LzMgmtProfile,
        [string]$LzOUName, 
        [string]$LzAcctName,
        [string]$LzIAMUserName,
        [string]$LzRootEmail,
        [string]$LzRegion
    )
    Write-Host "LzMgmtProfile=${LzMgmtProfile}"
    Write-Host "LzOUName=${LzOUName}"
    Write-Host "LzRootEmail=${LzRootEmail}"
    Write-Host "LzAcctName=${LzAcctName}"
    Write-Host "LzMgmtProfile=${LzMgmtProfile}"

    # Get LzRootId - note: Currently, there should only ever be one root.
    # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/list-roots.html
    $LzRoots = aws organizations list-roots --profile $LzMgmtProfile | ConvertFrom-Json
    $LzRootId = $LzRoots.Roots[0].Id 

    # Get Organizational Unit
    $LzOrgUnitsList = aws organizations list-organizational-units-for-parent --parent-id $LzRootId --profile $LzMgmtProfile | ConvertFrom-Json
    if($? -eq $false) {
        Write-Host "Error: Could not find ${LzOUName} Organizational Unit"
        exit
    }
    if($LzOrgUnitsList.OrganizationalUnits.Count -eq 0) {
        Write-Host "Error: There are no Organizational Units in root organization."
        exit 
    }

    $LzOrgUnit = $LzOrgUnitsList.OrganizationalUnits | Where-Object Name -eq $LzOUName
    if($? -eq $false)
    {
        Write-Host "Error: Could not find ${LzOUName} Organizational Unit"
        exit
    }

    $LzOrgUnitId = $LzOrgUnit.Id

    #Check if accont already exists 
    $LzAccounts = aws organizations list-accounts --profile $LzMgmtProfile | ConvertFrom-Json
    $LzAcct = ($LzAccounts.Accounts | Where-Object Name -EQ $LzAcctName)
    if($null -ne $LzAcct) {
        Write-Host "${LzAcctName} already exists. Skipping create."
        $LzAcctId = $LzAcct.Id
    }
    else {
        # Create Test Account  -- this is an async operation so we have to poll for success
        # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/create-account.html
        Write-Host "Creating System Account: ${LzAcctName}" 

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
            exit
        }

        $LzAcctId = $LzAcctStatus.CreateAccountStatus.AccountId
        Write-Host "    - ${LzAcctName} account creation successful. AccountId: ${LzAcctId}"
    }

    # Check if account is in OU
    $LzOUChildren = aws organizations list-children --parent-id $LzOrgUnitID --child-type ACCOUNT --profile $LzMgmtProfile | ConvertFrom-Json 
    $LzOUChild = $LzOUChildren.Children | Where-Object Id -EQ $LzAcctId
    if($null -ne $LzOUChild) {
        Write-Host "${LzAcctName} already in ${LzOUName} so skipping account move."
    }
    else {
        # Move new Account to OU
        # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/move-account.html
        Write-Host "    - Moving ${LzAcctName} account to ${LzOUName} organizational unit"
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
    Write-Host "Adding or Updating ${LzAccessRole} profile and associating it with the ${LzMgmtProfile} profile. "
    $null = aws configure set role_arn arn:aws:iam::${LzAcctId}:role/OrganizationAccountAccessRole --profile $LzAccessRoleProfile
    $null = aws configure set source_profile $LzMgmtProfile --profile $LzAccessRoleProfile
    $null = aws configure set region $LzRegion --profile $LzAccessRoleProfile 

    # Create Administrators Group for Test Account
    # Reference: https://docs.aws.amazon.com/cli/latest/userguide/cli-services-iam-new-user-group.html

    exit
    $awsgroups = aws iam list-groups --profile $LzAccessRoleProfile | ConvertFrom-Json
    $group = ($awsgroups.Groups | Where-Object GroupName -EQ "Administrators")
    if($null -eq $group) {
        Write-Host "Creating Administrators group in the ${LzAcctName} account."
        $null = aws iam create-group --group-name Administrators --profile $LzAccessRoleProfile
    } else {
        Write-Host "Administrators group exists in the ${LzAcctName} account."
    }

    # Add policies to Group
    $policies = aws iam list-attached-group-policies --group-name Administrators --profile $LzAccessRoleProfile
    # PowerUserAccess
    $policy = ($policies.AttachedPolicies  | Where-Object PolicyName -EQ AdministratorAccess) 
    if($null -ne $policy) {
        Write-Host "    - Policy AdministratorAccess already in Administrators group"
    } else {
        Write-Host "    - Adding policy AdministratorAccess"
        $LzGroupPolicyArn = aws iam list-policies --query 'Policies[?PolicyName==`AdministratorAccess`].{ARN:Arn}' --output text --profile $LzAccessRoleProfile 
        $null = aws iam attach-group-policy --group-name Administrators --policy-arn $LzGroupPolicyArn --profile $LzAccessRoleProfile
    }

    # Create User in Account
    $users = aws iam list-users --profile $LzAccessRoleProfile | ConvertFrom-Json
    $user = ($users.Users | Where-Object UserName -EQ $LzIAMUserName)
    if($null -ne $user) {
        Write-Host "IAM User ${LzIAMUserName} already in ${LzAcctName} account."
    } else {
        # Reference: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/iam/create-user.html
        Write-Host "Creating IAM User ${LzIAMUserName} in ${LzAcctName} account."
        $null = aws iam create-user --user-name $LzIAMUserName --profile $LzAccessRoleProfile | ConvertFrom-Json
        # Reference: https://docs.aws.amazon.com/cli/latest/userguide/cli-services-iam-new-user-group.html
        $LzPassword = "" + (Get-Random -Minimum 10000 -Maximum 99999 ) + "aA!"
        $null = aws iam create-login-profile --user-name $LzIAMUserName --password $LzPassword --password-reset-required --profile $LzAccessRoleProfile

        # Output Test Account Creds
        Write-Host "    - Writing the IAM User Creds into ${LzIAMUserName}_creds.txt"
        $nl = [Environment]::NewLine
        $LzOut = "User name,Password,Access key ID,Secret access key,Console login link${nl}"
        + $LzAcctName + "," + $LzPassword + ",,," + "https://${LzAcctId}.signin.aws.amazon.com/console"

        $LzOut > ${LzIAMUserName}_credentials.csv
    }

    # Add user to Group 
    $usergroups = aws iam list-groups-for-user --user-name $LzIAMUserName --profile $LzAccessRoleProfile | ConvertFrom-Json
    $group = ($usergroups.Groups | Where-Object GroupName -EQ Administrators)
    if($null -ne $group) {
        Write-Host "    - IAM User ${LzIAMUserName} is already in the Admnistrators group in the ${LzAcctName} account."
    } else {
        Write-Host "    - Adding the IAM User ${LzIAMUserName} to the Administrators group in the ${LzAcctName} account."
        $null = aws iam add-user-to-group --user-name $LzIAMUserName --group-name Administrators --profile $LzAccessRoleProfile
    }

    #update GitHub Personal Access Token
    $LzPat = Get-Content -Path GitCodeBuildToken.pat
    aws codebuild import-source-credentials --server-type GITHUB --auth-type PERSONAL_ACCESS_TOKEN --profile LzAccessRoleProfile --token $LzPAT

    return ,$true
}
function Publish-LzCodeBuildProject {
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
