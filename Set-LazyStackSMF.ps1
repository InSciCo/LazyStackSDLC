# Set-LazyStackSMF.ps1 v1.0.0
# We import lib in script directory with -Force each time to ensure lib version matches script version
# Performance is not an issue with these infrequently executed scripts
Import-Module (Join-Path -Path (Split-Path $script:MyInvocation.MyCommand.Path) -ChildPath LazyStackLib) -Force

if((Get-LibVersion) -ne "v1.0.0") {
    Write-Host "Error: Imported LazyStackSMF lib has wrong version!"
    exit
}

Write-Host " LazyStackSMF V1.0.0"
Write-Host " Use this script to setup and manage your LazyStackSMF Organization"

# Settings.yaml file structure
<# Example

#>

#default values
$settingsFile = "Settings.yaml"
$curScreen = "Loading"
$curSource = "GitHub" #only supporting GitHub for now - data structure supports adding additional sources
$quit = $false

# Begin Interactive Management UI
do { 
    # This is a very simple state machine. We move among "screens" using the $curScreen value. Some state
    # is passed in addtional variables:
    #   - $curSource: this is currently set only to "GitHub" as this is the only Source supported
    #   - $curRepo: current reposistory, example usage: $Org.Sources.$curSource.Repos.$curRepo
    #   - $curSystem: current system, example usage: $Org.Systems.$curSystem
    #   - $curAccount: current system account, example usage $Org.Systems.$curSystem.$curAccount
    #   - $curPipeline: current system account pipeline, example usage $Org.Systems.$curSystem.$curAccount.Pipelines.$curPipeline
    # Bascially, every "screen" represents an object node in the settings.yaml document.
    switch($curScreen) 
    {
        "Loading" {
            Write-Host " - Loading" $settingsFile
            $Org = Get-LzSettings $settingsFile # this routine may prompt user for OrgCode and MgmtProfile

            Write-Host " - Checking if AWS Organization exists"
            #AWS Organization - create if it doesn't exist
            #Get-AwsOrgRootId return "" if org doesn't exist - reads from AWS Profiles
            $AwsOrgRootId = Get-AwsOrgRootId -mgmtAcctProfile $Org.AWS.MgmtProfile
            
            if($AwsOrgRootId -eq "") {
                Write-Host "   - No AWS Organziation Found for the" $Org.AWS.MgmtProfile "account."
                Write-Host "   - We need to create one to continue installation."
                $create = Read-YesNo -prompt "Create AWS Organization?"
            
                if(!$create) {
                    Write-Host "   - OK. We won't create an AWS Organization now. Rerun this script when you are ready to create an AWS organization."
                    exit
                }
            
                $null = aws organizations create-organization --profile $Org.AWS.MgmtProfile
            
                $AwsOrgRootId = Get-AwsOrgRootId -mgmtAcctProfile $Org.AWS.MgmtProfile
            
                if($AwsOrgRootId -eq "") {
                    Write-Host " Error: Could not create AWS Organization. Check permissions of the" $Org.AWS.MgmtProfile "account and try again."
                    exit
                }
                Write-Host "   - AWS Organization Created"
            }
            
            Write-Host " - Checking if AWS OrgUnits exist"
            #AWS Organizational Units - create ones that don't exist 
            #read existing OUs
            $OuList = aws organizations list-organizational-units-for-parent `
                --parent-id $AwsOrgRootId `
                --profile $Org.AWS.MgmtProfile`
                | ConvertFrom-Json
            
            foreach($orgUnit in ($Org.AWS.OrgUnits.PSObject.Members.Match("*","NoteProperty"))) {
                #Write-Host "OrgUnit" $orgUnit.Value
                continue
                $ou = $OuList.OrganizationalUnits | Where-Object Name -eq $orgUnit.Value 
                if($null -eq $ou) {
                    Write-Host "   - Creating Organizational Unit " $orgUnit.Value
                    $ou = aws organizations create-organizational-unit `
                    --parent-id $AwsOrgRootId `
                    --name $ouProp.Value  `
                    --profile $Org.AWS.MgmtProfile `
                    | ConvertFrom-Json
            
                    if($null -eq $ou) {
                        Write-Host " Error: Could not create OU. Check permissions of the" $Org.AWS.MgmtProfile "account and try again."
                        exit
                    }
                }
            }
            Write-Host " - Loading Complete"
            $curScreen = "MainMenu"            
        }

        "MainMenu"  {
            Write-Host ""
            Write-Host "LazyStack Main Menu - Editing Organization:" $Org.OrgCode 
            Write-Host " 1) Edit AWS Information"
            Write-Host "     MgmtProfile:" $Org.AWS.MgmtProfile
            Write-Host "     DefaultRegion:" $Org.AWS.DefaultRegion
            Write-Host ""
            Write-Host " 2) Edit" ($Org.OrgCode + ".Sources.GitHub ")
            Write-Host "     AcctName:" (Set-MissingMsg $Org.Sources.$curSource.AcctName )
            Write-Host "     OrgName:" (Set-MissingMsg $Org.Sources.$curSource.OrgName)
            Write-Host "     Repository References:" (Get-MsgIf ((SettingsPropertyCount $Org.Sources.$curSource.Repos) -eq 0) "no Repositories defined yet")
            Write-Properties $Org.Sources.GitHub.Repos -indent 8
            Write-Host ""
            $hasSystems = (Get-SettingsPropertyCount $Org.Systems) -gt 0
            Write-Host " 3) Edit" ($Org.OrgCode + ".Systems:") (Get-MsgIfNot $hasSystems "(no systems defined yet)")
            Write-PropertyNames $Org.Systems -indent 4
            Write-Host ""
            $selection = Read-MenuSelection -min 1 -max 3 -indent 1 -options "q"
            switch($selection ) {
               -1 { 
                   $quit = $true
                   break 
                }
                1 { $curScreen = "AWS"}
                2 { $curScreen = "Sources" }
                3 { $curScreen = "Systems" }
            }
        }

        "AWS" {
            Write-Host ""
            Write-Host $Org.OrgCode AWS "- Account Information"
            if($Org.AWS.MgmtProfile -eq "") {
                $Org.AWS.MgmtProfile = $Org.OrgCode + "Mgmt"
            }
            $defmsg = Get-DefMessage -default $Org.AWS.MgmtProfile
            $Org.AWS.MgmtProfile = Read-AwsProfileName `
                -prompt "Enter AWS CLI Managment Account${defmsg}" `
                -default $Org.AWS.MgmtProfile `
                -indent 4 `
                -required $true 
            
            if($Org.AWS.DefaultRegion -eq "") {
                $Org.AWS.DefaultRegion = "us-east-1"
            }

            $Org.AWS.DefaultRegion = Read-AWSRegion `
                -mgmtAcctProfile $Org.AWS.MgmtProfile `
                -default $Org.AWS.DefaultRegion `
                -indent 4 `
                -required $true
            
            Set-LzSettings $Org 
            $curScreen="MainMenu"
        }

        "Sources" {
            Write-Host ""
            Write-Host $Org.OrgCode Sources GitHub
            Write-Host " 1) Edit Account Information"
            Write-Host "      Management Account Name:" $Org.Sources.$curSource.AcctName 
            Write-Host "      Organziation Name:" $Org.Sources.$curSource.OrgName
            Write-Host ""
            Write-Host " 2) Edit Repository References"
            Write-PropertyNames $Org.Sources.$curSource.Repos -indent 8
            Write-Host ""
            $selection = Read-MenuSelection -min 1 -max 2 -options "q" -indent 1
            switch($selection) {
               -1 { $curScreen = "MainMenu" }
                1 { $curScreen = "Source" }
                2 { $curScreen = "Repos" }
            }
        }

        "Source" {
            Write-Host ""
            Write-Host $Org.OrgCode Sources $curSource

            $defmsg = Get-DefMessage -current $Org.Sources.$curSource.AcctName
            $Org.Sources.$curSource.AcctName = Read-String `
                -prompt "${curSource} Admin Acct Name${defmsg}" `
                -default $Org.$curSource.AcctName `
                -indent 4 `
                -required $true

            $defmsg = Get-DefMessage -current $Org.Sources.$curSource.OrgName
            $Org.Sources.$curSource.OrgName = Read-String `
                -prompt "GitHub Organization Name${defmsg}" `
                -default $Org.$curSource.OrgName `
                -indent 4 `
                -required $true

            $curScreen = "Sources"
        }

        "Repos" {
            Write-Host ""
            Write-Host $Org.OrgCode Sources $curSource Repos
            $items, $menuSelections, $curItem = Write-PropertySelectionMenu $Org.Sources.$curSource.Repos -indent 4
            $items = [int]$items
            Write-Host ""
            $selection = Read-MenuSelection -max $items -indent 1
            switch ($selection) {
               -1 { # quit
                    $curScreen = "Sources"
                }
                -2 { # Add
                    # Add new repo reference
                    $curRepo = Read-PropertyName `
                        -object $Org.Sources.$curSource.Repos `
                        -prompt "Enter name for repository reference" `
                        -exists $false `
                        -indent 4

                    Add-SettingsProperty `
                        -object $Org.Sources.$curSource.Repos `
                        -property $curRepo `
                        -default ""

                    $curScreen = "Repo"
                }
                -3 { # Delete
                    $delItem = Read-MenuSelection -max $items -indent 4 -prompt "Which item to delete" -options "q"
                    switch ($delItem) {
                        -1 {
                            continue
                        }
                        default {
                            $curRepo = $menuSelections[$delItem]
                            $ok = Read-YesNo -prompt "Are you sure you want to delete repository reference ${curRepo}" -indent 4
                            if($ok) {
                                Remove-SettingsProperty $Org.Sources.$curSource.Repos $curRepo
                                Set-LzSettings $Org $settingsFile
                            }
                        }
                    }
                }
                default {
                    # Update repo reference
                    $curRepo = $menuSelections[$selection]
                    $curScreen = "Repo"
                }
            }
        }

        "Repo" {
            Write-Host ""
            Write-Host $Org.OrgCode Sources $curSource Repos $curRepo

            $ok, $newRepo = New-Repository -orgName $Org.Sources.$curSource.OrgName
            if($ok) {
                $orgName.Sources.$curSource.Repos.$curRepo = $newRepo
            }

            $curScreen = "Repos"
        }

        "Systems" {
            Write-Host ""
            Write-Host $Org.OrgCode Systems 
            $items, $menuSelections, $curItem = Write-PropertySelectionMenu $Org.Systems
            Write-Host ""
            $selection = Read-MenuSelection -min 1 -max $items -indent 1
            switch ($selection) {
               -1 { #quit
                    $curScreen = "MainMenu"
                }
               -2 { # Add new System

                    Write-Host " Adding New System"
                    $curSystem = Read-PropertyName `
                        -object $Org.Systems `
                        -prompt "Enter name for System" `
                        -exists $false `
                        -indent 4
        
                    Add-SettingsProperty `
                        -object $Org.Systems `
                        -property $curSystem `
                        -default ""                
                    $curScreen = "Accounts"
                }
                default {
                    $curSystem = $menuSelections[$selection]
                    Write-System $Org.Systems $curSystem
                    if(Read-YesNo "Edit the System") { 
                        $curScreen = "System" 
                    }  else { 
                        $curScreen = "Systems" 
                    }
                }
            }            
        }

        "System" {
            Write-Host ""
            Write-Host $Org.OrgCode Systems $curSystem
            $curSystemObj = $Org.Systems.$curSystem 
            Read-Property $curSystemObj Description 2
            if(Read-YesNo "Edit System Accounts") {
                $curScreen = "Accounts" 
            } else {
                $curScreen = "Systems"
            }
        }

        "Accounts" {
            Write-Host ""
            Write-Host $Org.OrgCode Systems $curSystem Accounts
            Write-Host ""
            $items, $menuSelections, $curItem = Write-PropertySelectionMenu $curSystemObj.Accounts
            Write-Host ""
            $selection = Read-MenuSelection -min 1 -max $items -indent 2 -options "ads"
            switch($selection) {
               -1 { #skip
                    $curScreen = "Systems" 
                }
                -2 { #add 
                    Write-Host " Adding New Account"

                    $accountType = Read-AccountType -indent 4

                    $curAccount = Read-PropertyName `
                        -object $Org.Accounts `
                        -prompt "Enter name for Account" `
                        -exists $false `
                        -default ($curSystem + $accountType) `
                        -indent 4

                    $description = ""
                    Read-Value $description Description 4

                    $email = Read-Email -indent 4
                    
                    Add-SettingsProperty `
                        -object $Org.Accounts `
                        -property $curAccount `
                        -default (New-Account $Org.OrgCode $curSystem $accountType $description $email)

                    $curScreen = "Account"  

                }
                -3 { #delete 
                    Write-Host "Not yet implemented"
                    $ok = Read-YesNo "Continue"
                    $curScreen = "Accounts"
                }
                default {
                    $curAccount = $menuSelections[$selection]
                    $curScreen = "Account"
                }
            }
        }

        "Account" {
            Write-Host ""
            Write-Host $Org.OrgCode Systems $curSystem Accoiunts $curAccount 
            $curAccountObj = $Org.Systems.$curSystem.Accounts.$curAccount 
            Write-Account $Org.Systems.$curSystem.Accounts $curAccount -indent 4
            $edit = Read-YesNo "Edit Account"
            if($edit) {
                Read-Value $curAccountObj.Description Description -indent 4

                $defmsg = Get-DefMessage $curAccountObj.Email
                $curAccountObj.Email = Read-Email "Email${defmsg}" $curAccountObj.Email -indent 4

                Read-Value $curAccountObj.IAMUser IAMUser -indent 4 

                $curScreen = "Pipelines" 

            } else {
                $curScreen = "Accounts"
            }
        }

        "Pipelines" {
            Write-Host ""
            Write-Host  $Org.OrgCode Systems $curSystem Accounts $curAccount Pipelines
            $pipelinesObj = $Org.Systems.$curSystem.Accounts.$curAccount.Pipelines
            $items, $menuSelections, $curItem = Write-PropertySelectionMenu $pipelinesObj `
                -indent 4
            Write-Host ""
            $selection = Read-MenuSelection -min 1 -max $items -indent 1
            switch ($selection) {
               -1 { #quit
                    $curScreen = "MainMenu"
                }
                -2 { # Add new template 
                    $curTemplate = Read-PropertyName `
                    -object $pipelinesObj `
                    -prompt "Enter name for pipeline template" `
                    -exists $false `
                    -indent 4

                Add-SettingsProperty `
                    -object $pipelinesObj `
                    -property $curTemplate `
                    -default ([PSCustomObject]@{})
                    $curScreen = "Template"
                }
                -3 { #delete
                    $delItem = Read-MenuSelection -max $items -indent 4 -prompt "Which item to delete" -options "q"
                    switch ($delItem) {
                        -1 {
                            continue
                        }
                        default {
                            $curTemplate = $menuSelections[$delItem]
                            $ok = Read-YesNo -prompt "Are you sure you want to delete pipeline template ${curTemplate}" -indent 4
                            if($ok) {
                                Remove-SettingsProperty $pipelinesObj $curTemplate
                                Set-LzSettings $Org $settingsFile
                            }
                        }
                    }
                }
                default {
                    $curTemplate = $menuSelections[$selection]

                    #Show current Template Properties if template assigned
                    Write-Host ""
                    if($curTemplate -ne "") {
                        Write-Host $curTemplate "Template"
                        $templatePath = $pipelinesObj.$curTemplate.TemplatePath
                        $found = (Test-Path $template)
                        Write-Host "    TemplatePath:" $templatePath 
                        if(!$found) {Write-Host "      (Warning, template file not found)"}
                        Write-Host "    Description:" $pipelinesObj.$curTemplate.Description
                        Write-Host "    Region:" $pipelinesObj.$curTemplate.Region
                        $fixedArgs = @("TemplatePath","Description", "Region")
                        if(Test-Path $templatePath ) {
                            $parameters = Get-TemplateParameters $templatePath
                            $parameters | Get-Member -MemberType NoteProperty | ForEach-Object {
                                $name = $_.Name 
                                if($fixedArgs -contains $name) {continue}

                                # Check if the template parameter is in the Pipeline object; it may have been added after initial assignment.
                                if(Get-SettingsPropertyExists $pipelinesObj.$curTemplate $name) {
                                    Write-Host "   " ($name + ":") $pipelinesObj.$curTemplate.$name
                                } else {
                                    Write-Host "   " ($name + ": new parameter") 
                                }
                            }
                        }
                    }
                    if(Read-YesNo "Edit the Pipeline") {
                        $curScreen = "Pipeline"
                    } else {
                        $curScreen = "Pipelines"
                    }
                }
            }
        }

        "Pipeline" {
            Write-Host ""
            Write-Host  $Org.OrgCode Systems $curSystem Accounts $curAccount Pipeline $curPipeline 

            $pipelinesObj = $Org.Systems.$curSystem.Accounts.$curAccount.Pipelines
            $curPipelineObj = $pipelinesObj.$curPipeline

            #TemplatePath = "../LazyStackSMF/Test_CodeBuild_PR_Create.yaml"
            $default = $curPipelineObj.templatePath
            $defmsg = Get-DefMessage -current $default
            $templatePath = Read-FileName `
                -prompt "CodeBuild Template File${defmsg}" `
                -default $default `
                -indent 4 `
                -required $true
            Add-SettingsProperty $curPipelineObj TemplatePath
            $curPipelineObj.TemplatePath = $templatePath

            #Description = "Create PR Stack on Pull Request Creation"
            $default = $curPipelineObj.Description
            $defmsg = Get-DefMessage -current $default
            $description = Read-String `
                -prompt "Description${defmsg}" `
                -default $default `
                -indent 4 
            Add-SettingsProperty $curPipelineObj Description
            $curPipelineObj.Description = $description

            Add-SettingsProperty $curPipelineObj RegionParam 
            $curPipelineObj.RegionParam = $regionParam

            #Read and prompt for Parameters found in template 
            Write-Host "Template Parameters:"
            $fixedArgs = @("TemplatePath","Description", "Region")
            if(Test-Path $templatePath ) {
                $parameters = Get-TemplateParameters $templatePath
                $parameters | Get-Member -MemberType NoteProperty | ForEach-Object {
                    $name = $_.Name 
                    $paramDefault = $_.Value.Default #this property might not be present
                    if($fixedArgs -contains $name) {continue} #skip fixed parameters if they appear as template parameters

                    # Show Template Parameter definition
                    Write-Host "Template Parameter" $name
                    $_ | ConvertTo-Yaml
                    # Type
                    # Description 
                    # Default
                    
                    # Check if the template parameter is in the Pipeline object
                    if(Get-SettingsPropertyExists $curPipelineObj $name) {
                        Write-Host "Pipeline value for" $name "parameter"
                        $default = $curPipelineObj.$name
                        $defmsg = Get-DefMessage -default $default
                        $default = Read-String `
                            -prompt "${name}${defmsg}" `
                            -default $default
                            $curPipelineObj.$name = $default
                    } else {
                        $create = Read-YesNo ("Add pipeline value for " + $name + " parameter")
                        if($create) {
                            $default = [string]$paramDefault
                            $defmsg = Get-DefMessage -default $default
                            $default = Read-String `
                                -prompt "${name}${defmsg}" `
                                -default $default
                            $curPipelineObj.$name = $default
                            Add-SettingsProperty $curPipelineObj $name $default
                        }
                    }
                }
            }

            $curScreen = "Pipelines"
        }

        default {
            Write-Host " Unknown screen requested" $curScreen 
            Read-Host " Press enter to go to MainMenu"
            $curScreen = "MainMenu"
        }
    }
  
} until($quit)

Set-LzSettings $Org $settingsFile



