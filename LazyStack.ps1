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


function New-DocSpec {
    # This object defines the structure of the settings.yaml file and what type of 
    # entries are allowed for each property. Any PSCustomObject with a PropertySpec 
    # allows zero or more Properties satisfying that PropertySpec to be added to the 
    # PSCustomObject.
    # Named Properties have an @() Rvalue like @("","Read-Email") The first entry is
    # the name of the function to call to initialize the property the first time while 
    # the second value is the name of the function to call when asking the user for 
    # imput. 
    return [PSCustomObject]@{
        OrgCode = @("Set-String","Read-OrgCode")
        AWS = [PSCustomObject]@{
            MgmtProfile = @("Set-String","Read-String")
            DefaultRegion = @("Set-String","Read-String")
            OrgUnits = [PSCustomObject]@{
                PropertySpec = @("Set-OrgUnit","Read-OrgUnit")
            }
        }
        Sources = [PSCustomObject]@{
            PropertySpec = [PSCustomObject]@{ 
                OrgName = @("Set-String","Read-String")
                Type = @("Set-SourceType","Read-SourceType")
                AcctName = @("Set-String","Read-SourceAcctName")
                Repos = [PSCustomObject]@{
                    Repo = [PSCustomOBject]@{
                        PropertySpec = @("Set-String","Read-SourceRepo")
                    }
                }
            }
        }
        Systems = [PSCustomObject]@{
            PropertySpec = [PSCustomObject]@{ 
                Description = @("Set-String","Read-String")
                Accounts = [PSCustomObject]@{
                    PropertySpec = [PSCustomObject]@{
                        Description = @("Set-String","Read-String")
                        IAMUser = @("Set-String","Read-String")
                        Email = @("Set-String","Read-Email")
                        OrgUnit = @("Set-String","Read-OrgUnitRef")
                        Type = @("Set-String","Read-AccountType")
                        Pipelines = [PSCustomObject]@{
                            PropertySpec = [PSCustomObject]@{
                                Description = @("Set-String","Read-String")
                                TemplatePath = @("Set-String","Read-FilePath")
                                Region = @("Set-FromDefaultAwsRegion","Read-AwsRegionName")
                                TemplateParams = [PSCustomObject]@{
                                    PropertySpec = @("Get-TemplateParam","Read-TemplateParam")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

function Set-String {
    return ""
}

function Add-Property {
    param([PSObject]$object, [string]$property, $val)
    $object = $object | Add-Member -NotePropertyName $property -NotePropertyValue $default
}
function Read-Tree {
    param([PSObject]$docObj, [PSObject]$specNode)
    $specNode | Get-Member -MemberType NoteProperty | ForEach-Object {
        $nodeName = $_.Name
        $nodeVal = $docSpec.$nodeName
        $nodeType = $nodeVal.GetType().Name
        
        # We have three possible TreeNode types: LeafProperty, DynamicObject, FixedObject
        if($nodeType -eq "Object[]") {
            $nodeSpec = "LeafProperty"
        } elseif ($nodeType -eq "PSCustomOBject") {
            if($nodeVal.PSObject.Members.Match('PropertySpec','NoteProperty').Count -ne 0) {
                $nodeSpec = "DynamicObject"
            } else {
                $nodeSpec = "FixedObject"
            }
        }
        
        #Write-Host "NodeName=" $nodeName "NodeVal=" $nodeVal "NodeType=" $nodeType "NodeSpec=" $nodeSpec
   
        #Make sure the Settings tree has the specified properties 
        $found = $docObj.PSObject.Members.Match($nodeName, 'NoteProperty').Count -gt 0 
        if(!$found) {
            switch($nodeSpec) {
                "LeafProperty" {
                    $val = Invoke-Expression $nodeVal[0] # call initalizer ex: Set-String
                }
                "DynamicObject" {
                    $val = [PSCustomObject]@{}
                }
                "FixedObject" {
                    $val = [PSCustomObject]@{}
                }
            }
            #The following does not work. You need to call this in a function! 
            #$docObj = $docObj | Add-Member -MemberType NoteProperty -Name $nodeName -Value $val
            Add-Property $docObj $nodeName $val
        } 

    }
    #$docObj = $docObj | Add-Member -NotePropertyName Yada -NotePropertyValue "yada"
    Write-Host "docObj=" $docObj
    $docObj | ConvertTo-Yaml

}


#issues 
# - exporting objects in json format reorders properties
# - 

#default values
$settingsFile = "Settings.yaml"
$curScreen = "Nav"
$curSource = "GitHub" #only supporting GitHub for now - data structure supports adding additional sources
$quit = $false


# Begin Interactive Management UI
do { 
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
            $curScreen = "Nav"  
            $curNode = $Org          
        }


        "Nav"  { #navigate the yaml file using keystrokes
            # up arrow move to previous property
            # down arrow move to next property - moves up in tree when it hits the last property in current object
            # enter - edit value if primative type, drill down into object
            # backspace - moves up in tree 

            #Write-Host $treePath[$treeLevel].PSObject.Members("*", 'NoteProperty').Count
            $DocSpec = New-DocSpec
            $Doc = [PSCustomObject]@{ OrgCode="T4"}
            Read-Tree $Doc $DocSpec

            exit

        }
    }
} until($quit)





