# Set-LazyStackSMF.ps1 v1.0.0
# We import lib in script directory with -Force each time to ensure lib version matches script version
# Performance is not an issue with these infrequently executed scripts
Import-Module (Join-Path -Path (Split-Path $script:MyInvocation.MyCommand.Path) -ChildPath LazyStackLib) -Force
Import-Module (Join-Path -Path (Split-Path $script:MyInvocation.MyCommand.Path) -ChildPath LazyStackUI) -Force

<#
1. Create an SMF.yaml file
    - Read OrgCode (used in naming systems etc.)
    - Read MgmtAcct 
    - Define System 
        - Define Test Account 
            - Define Pipelines
        - Define Prod Account 
            - Define Pipelines 

2. Deploy AWS Organization
    - Org
    - OrgUnits

    3. Deploy AWS System
    - Get SysCode from SMF. used in naming accounts
    - Deploy AWS Test Account - $OrgCode$SysCodeTest
    - Deploy AWS Prod Account - $OrgCode$SysCodeProd

    4. Deploy AWS CodeBuild Project (Pipeline)
    - Capture repo
    - Capture codebuid template(s)
        - template parameters
#>

Write-Host " LazyStack V1.0.0"
Write-Host " Use this script to setup and manage your LazyStackSMF Organization"

function Set-String {
    return "Yada"
}

function Add-Property {
    param([PSObject]$object, [string]$property, $val)
    if($null -ne $val) {
        $valType = $val.GetType().Name
    } else {
        $valType = "null"
    }

    #Write-Host "Add-Property" $property "type" $valType
    $object = $object | Add-Member -NotePropertyName $property -NotePropertyValue $val
}


#issues 
# - exporting objects in json format reorders properties
# - 

#default values
$settingsFile = "Settings.yaml"
$curScreen = "Loading"
$curSource = "GitHub" #only supporting GitHub for now - data structure supports adding additional sources
$quit = $false

# Begin Interactive Management UI
do { 
    switch($curScreen) 
    {
        "Loading" {
            Write-Host " - Loading" $settingsFile
            $Org = Get-SMF $settingsFile # this routine may prompt user for OrgCode and MgmtProfile

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
            $curNode = $Org          
        }

    }
} until($quit)





