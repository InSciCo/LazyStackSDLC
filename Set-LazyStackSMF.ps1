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
Sources:
  GitHub:
    OrgName: ""
    Repos:
      PetStore: ""
      LazyStackSMF: ""
    AcctName: ""
    Type: GitHub
AWS:
  MgmtProfile: T4Mgmt
  DefaultRegion: us-east-1
  OrgUnits:
    TestOU: T4TestOU
    DevOU: T4DevOU
    ProdOU: T4ProdOU
Systems:
  Tut:
    T4Test:
      Email: ""
      OrgUnit: T4TestOU
      IAMUser: T4TutTestIAM
      Pipelines:
        Test_PR_Create:
          PipelineTemplate: $Pipelines.Test_PR_Create
        Test_PR_Merge:
          PipelineTemplate: $Pipelines.Test_PR_Merge
    T4Prod:
      Email: ""
      OrgUnit: T4TProdOU
      IAMUser: T4TutProdIAM
      Pipelines:
        Prod_PR_Merge:
          PipelineTemplate: $Pipelines.Prod_PR_Merge
PipelineTemplates:
  Test_PR_Merge:
    Region: $AWS.DefaultRegion
    TemplatePath: ../LazyStackSMF/Test_CodeBuild_PR_Merge.yaml
    Description: Delete PR Stack on Pull Request Merge
    UtilRepo: $Sources.GitHub.Repos.LazystackSMF
    RepoParam: $Sources.GitHub.Repos.PetStore
  Prod_PR_Merge:
    RepoParam: $Sources.GitHub.Repos.PetStore
    Region: $AWS.DefaultRegion
    UtilRepo: $Sources.GitHub.Repos.LazystackSMF
    TemplatePath: ../LazyStackSMF/Prod_CodeBuild_PR_Merge.yaml
    StackName: us-east-1-petstore
    Description: Update Production Stack on Pull Request Merge
  Test_PR_Create:
    Region: $AWS.DefaultRegion
    TemplatePath: ../LazyStackSMF/Test_CodeBuild_PR_Create.yaml
    Description: Create PR Stack on Pull Request Creation
    UtilRepo: $Sources.GitHub.Repos.LazystackSMF
    RepoParam: $Sources.GitHub.Repos.PetStore
OrgCode: T4
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
    #   - $curAction: [Add | Edit | Delete]
    #   - $curSource: this is currently set only to "GitHub" as this is the only Source supported
    #   - $curRepo: current reposistory, example usage: $Org.Sources.$curSource.Repos.$curRepo
    #   - $curSystem: current system, example usage: $Org.Systems.$curSystem
    #   - $curAccount: current system account, example usage $Org.Systems.$curSystem.$curAccount
    #   - $curPipeline: used in two contexts, example usages
    #       - $Org.Systems.$curSystem.$curAccount.Pipelines.$curPipeline
    #       - $Org.PipelineTemplates.$curPipleline
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
            <#
            $hasPipelineTemplates = (Get-SettingsPropertyCount $Org.Pipelines) -gt 0
            Write-Host " 4) Edit" ($Org.OrgCode + ".PipelineTemplates:") (Get-MsgIfNot $hasPipelineTemplates "(no Pipeline Templates defined yet)")
            Write-PropertyNames $Org.PipelineTemplates -indent 4
            Write-Host ""
            #>
            $selection = Read-MenuSelection -min 1 -max 3 -indent 1 -options "q"
            $curAction = ""
            switch($selection ) {
               -1 { 
                   $quit = $true
                   break 
                }
                1 { $curScreen = "AWSMenu"}
                2 { $curScreen = "SourceMenu" }
                3 { $curScreen = "SystemsMenu" }
                4 { $curScreen = "PipelinesMenu" }
            }
        }

        "AWSMenu" {
            Write-Host ""
            Write-Host $Org.OrgCode AWS "- Editing Account Information"
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

        "SourceMenu" {
            Write-Host ""
            Write-Host $Org.OrgCode $curSource "- Menu"
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
                2 { $curScreen = "ReposMenu" }
            }
        }

        "Source" {
            Write-Host ""
            Write-Host $Org.OrgCode $curSource "- Editing Account Information"

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

            $curScreen = "SourceMenu"
        }

        "ReposMenu" {
            Write-Host ""
            Write-Host $Org.OrgCode $curSource "- Editing Repository References"
            $items, $menuSelections, $curItem = Write-PropertySelectionMenu $Org.Sources.$curSource.Repos -indent 4
            $items = [int]$items
            Write-Host ""
            $selection = Read-MenuSelection -max $items -indent 1
            switch ($selection) {
               -1 { # quit
                    $curScreen = "SourceMenu"
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

                    $curAction="Edit"
                    $curScreen = "Repo"
                }
                -3 { # Delete
                    $curAction = "Delete"
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
                    $curAction = "Edit"
                    $curRepo = $menuSelections[$selection]
                    $curScreen = "Repo"
                }
            }
        }

        "Repo" {
            Write-Host ""
            Write-Host $Org.OrgCode $curSource "- Edit Repository ${curRepo}"

            if($curAction -ne "Edit") {
                Write-Host "Error: Unknown action ${action} passed to Repo screen"
                $curScreen = "ReposMenu"
                continue
            }

            $ok, $newRepo = New-Repository -orgName $Org.Sources.$curSource.OrgName
            if($ok) {
                $orgName.Sources.$curSource.Repos.$curRepo = $newRepo
            }

            $curAction = ""
            $curRepo = ""
            $curScreen = "ReposMenu"
        }

        "PipelinesMenu" {
            Write-Host ""
            Write-Host  $Org.OrgCode "- Pipelines Menu"
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

                    $curAction ="Edit"
                    $curScreen = "Template"
                }
                -3 { #delete
                    $curAction = "Delete"
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
                    $curAction = "Edit"
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
                    $edit = Read-YesNo "Edit the Pipeline"
                    if($edit) {
                        $curAction = "Edit"
                        $curScreen = "Template"
                    } else {
                        $curAction = ""
                        $curScreen = "PipelinesMenu"
                    }
                }
            }
        }

        "Template" {
            Write-Host ""
            Write-Host  $Org.OrgCode "- Editing Pipeline Template" $curTemplate

            if($curAction -ne "Edit") {
                Write-Host "Error: Unknown action ${action} passed to Repo screen"
                $curScreen = "PipelinesMenu"
                continue
            }

            $pipelinesObj = $Org.Systems.$curSystem.Accounts.$curAccount.Pipelines

            #TemplatePath = "../LazyStackSMF/Test_CodeBuild_PR_Create.yaml"
            $default = $pipelinesObj.$curTemplate.templatePath
            $defmsg = Get-DefMessage -current $default
            $templatePath = Read-FileName `
                -prompt "CodeBuild Template File${defmsg}" `
                -default $default `
                -indent 4 `
                -required $true
            Add-SettingsProperty $pipelinesObj.$curTemplate TemplatePath
            $pipelinesObj.$curTemplate.TemplatePath = $templatePath

            #Description = "Create PR Stack on Pull Request Creation"
            $default = $pipelinesObj.$curTemplate.Description
            $defmsg = Get-DefMessage -current $default
            $description = Read-String `
                -prompt "Description${defmsg}" `
                -default $default `
                -indent 4 
            Add-SettingsProperty $pipelinesObj.$curTemplate Description
            $pipelinesObj.$curTemplate.Description = $description

            Add-SettingsProperty $pipelinesObj.$curTemplate RegionParam 
            $pipelinesObj.$curTemplate.RegionParam = $regionParam

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
                    if(Get-SettingsPropertyExists $pipelinesObj.$curTemplate $name) {
                        Write-Host "Pipeline value for" $name "parameter"
                        $default = $pipelinesObj.$curTemplate.$name
                        $defmsg = Get-DefMessage -default $default
                        $default = Read-String `
                            -prompt "${name}${defmsg}" `
                            -default $default
                            $pipelinesObj.$curTemplate.$name = $default
                    } else {
                        $create = Read-YesNo ("Add pipeline value for " + $name + " parameter")
                        if($create) {
                            $default = [string]$paramDefault
                            $defmsg = Get-DefMessage -default $default
                            $default = Read-String `
                                -prompt "${name}${defmsg}" `
                                -default $default
                            $pipelinesObj.$curTemplate.$name = $default
                            Add-SettingsProperty $pipelinesObj.$curTemplate $name $default
                        }
                    }
                }
            }

            $curAction = ""
            $curTemplate = ""
            $curScreen = "PipelinesMenu"
        }

        "SystemsMenu" {
            Write-Host ""
            Write-Host " " $Org.OrgCode "- Systems Menu"
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
                    $curAction = "Edit"
                    $curScreen = "System"
                }
                default {
                    $curSystem = $menuSelections[$selection]
                    Write-System $Org.Systems $curSystem

                    $edit = Read-YesNo "Edit the System"
                    if($edit) {
                        $curAction = "edit"
                        $curScreen = "System"
                    } else {
                        $curAction = ""
                        $curScreen = "SystemsMenu"
                    }
                }
            }            
        }

        "System" {
            Write-Host ""
            Write-Host $Org.OrgCode "- Edit System" $curSystem
            $curSystemObj = $Org.Systems.$curSystem 
            $defmsg = Get-DefMessage $curSystemObj.Description 
            $curSystemObj.Description = Read-String `
                -prompt "Description${defmsg}" `
                -default $curSystemObj.Description
                -indent 2

            

            Read-String "system edit proxy"
        }

        default {
            Write-Host " Unknown screen requested" $curScreen 
            Read-Host " Press enter to go to MainMenu"
            $curScreen = "MainMenu"
        }
    }
  
} until($quit)

Set-LzSettings $Org $settingsFile



