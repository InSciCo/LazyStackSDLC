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
    #   - $action: [Add | Edit | Delete]
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

            Write-Host " 2) Edit" ($Org.OrgCode + ".Sources.GitHub ")
            Write-Host "     AcctName:" (Set-MissingMsg $Org.Sources.$curSource.AcctName )
            Write-Host "     OrgName:" (Set-MissingMsg $Org.Sources.$curSource.OrgName)
            Write-Host "     Repositories:" (Get-MsgIf ((SettingsPropertyCount $Org.Sources.$curSource.Repos) -eq 0) "no Repositories defined yet")
            Write-Properties $Org.Sources.GitHub.Repos -indent 8

            $hasPipelineTemplates = (Get-SettingsPropertyCount $Org.Pipelines) -gt 0
            Write-Host " 3) Edit" ($Org.OrgCode + ".PipelineTemplates:") (Get-MsgIfNot $hasPipelineTemplates "(no Pipeline Templates defined yet)")
            Write-PropertyNames $Org.PipelineTemplates -indent 4

            $hasSystems = (Get-SettingsPropertyCount $Org.Systems) -gt 0
            Write-Host " 4) Edit" ($Org.OrgCode + ".Systems:") (Get-MsgIfNot $hasSystems "(no systems defined yet)")
            Write-PropertyNames $Org.Systems -indent 4

            $selection = Read-MenuSelection -min 1 -max 4 -indent 1 -options "q"
            $action = ""
            switch($selection ) {
               -1 { 
                   $quit = $true
                   break 
                }
                1 { $curScreen = "AWSMenu"}
                2 { $curScreen = "SourceMenu" }
                3 { $curScreen = "PipelinesMenu" }
                4 { $curScreen = "SystemsMenu" }
            }
        }

        "AWSMenu" {
            Write-Host ""
            Write-Host $Org.OrgCode AWS "- Editing Account Information"
            $default = $OrgCode + "Mgmt"
            $Org.AWS.MgmtProfile = Read-AwsProfileName `
                -prompt "Enter AWS CLI Managment Account (default: ${default})" `
                -default $default `
                -indent 4 `
                -required $true 
            
            $default = "us-east-1"
            $Org.AWS.DefaultRegion = Read-AWSRegion `
                -default $default `
                -indent 4 `
                -required $true
            
            Set-LzSettings $Org 
        }

        "SourceMenu" {
            Write-Host ""
            Write-Host $Org.OrgCode $curSource "- Menu"
            Write-Host " 1) Edit Account Information"
            Write-Host "      Management Account Name:" $Org.Sources.$curSource.AcctName 
            Write-Host "      Organziation Name:" $Org.Sources.$curSource.OrgName
            Write-Host " 2) Edit Repositories"
            Write-PropertyNames $Org.Sources.$curSource.Repos -indent 8

            $selection = Read-MenuSelection -min 1 -max 2 -options "q"
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
            Write-Host $Org.OrgCode $curSource "- Editing Repositories"
            $items, $menuSelections = Write-PropertySelectionMenu $Org.Sources.$curSource.Repos -indent 4
            $items = [int]$items
            $selection = Read-MenuSelection -max $items -indent 4
            switch ($selection) {
               -1 { # quit
                    $curScreen = "SourceMenu"
                }
                1 {
                    # Add new repo reference
                    Read-Host "Add new repo placeholder"
                    $curScreen = "ReposMenu"
                }
                default {
                    # Update repo reference
                    Read-Host "Update repo placeholder"
                    $curScreen = "ReposMenu"
                }
            }
        }

        "PipelinesMenu" {
            Write-Host ""
            Write-Host " " $Org.OrgCode "- Pipeline Templates Menu"
            $items, $menuSelections = Write-PropertySelectionMenu $Org.PipelineTemplates
            $selection = Read-MenuSelection -min 1 -max $items 
            switch ($selection) {
               -1 { #quite
                    $curScreen = "MainMenu"
                }
                1 { # Add new template 
                    $action = "Add"
                    $curTemplate = ""
                    $curScreen = "Template"
                }
                default {
                    $action = "Edit"
                    $curTemplate = $menuSelections[$selection]
                    $curScreen = "Template"
                }
            }
        }

        "Template" {
            Write-Host ""
            if($action -eq "Add") {
                Write-Host " " $Org.OrgCode "- Add New Template"
                Read-Hopst "Add Template Placeholder"
                $action = ""
                $curScreen = "PipelinesMenu"
            }
            elseif ($action -eq "Edit") {
                Write-Host " " $Org.OrgCode $curTemplate "- Edit Template"
                Read-Host " Edit Template placeholder"
                $action = ""
                $curScreen = "PipelinesMenu"
            } else {
                Write-Host " Error: Unknown Action"
                $curScreen = "PipelinesMenu"
            }

        }

        "SystemsMenu" {
            Write-Host ""
            Write-Host " " $Org.OrgCode "- Systems Menu"
            $items, $menuSelections = Write-PropertySelectionMenu $Org.Systems
            $selection = Read-MenuSelection -min 1 -max $items
            switch ($selection) {
               -1 { #quite
                    $curScreen = "MainMenu"
                }
                1 { # Add new System
                    $action = "Add"
                    $curSystem = ""
                    $curScreen = "System"
                }
                default {
                    $action = "Edit"
                    $curSystem = $menuSelections[$selection]
                    $curScreen = "System"
                }
            }            
        }

        "System" {
            Write-Host ""
            if($action -eq "Add") {
                Write-Host " Adding New System"
                Write-Host " Add new System placeholder"
                $curScreen="SystemsMenu"

            } elseif ($action -eq "Edit") {
                Write-Host " " $Org $curSystem "- Editing System "
                Read-Host " Edit Systems Placeholder"
                $curScreen = "SystemsMenu"
            } else {
                Read-Host "Error: Unknown Action"
                $curScreen = "SystemsMenu"
            }
        }

        default {
            Write-Host " Unknown screen requested" $curScreen 
            Read-Host " Press enter to go to MainMenu"
            $curScreen = "MainMenu"
        }
    }
  
} until($quit)

Set-LzSettings $Org $settingsFile



