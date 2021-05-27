# Set-LazyStackSMF.ps1 v1.0.0
# We import lib in script directory with -Force each time to ensure lib version matches script version
# Performance is not an issue with these infrequently executed scripts
Import-Module (Join-Path -Path (Split-Path $script:MyInvocation.MyCommand.Path) -ChildPath LazyStackLib) -Force
Import-Module (Join-Path -Path (Split-Path $script:MyInvocation.MyCommand.Path) -ChildPath LazyStackUI) -Force


Write-Host " LazyStackSMF V1.0.0"
Write-Host " Use this script to setup and manage your LazyStackSMF Organization"


function New-DocSpec {
    return [ordered]@{
        Type="Object"
        Properties =[ordered]@{
            OrgCode = @{Type="String"}
            AWS =@{
                Type="Object"
                ItemType="AWS"
                Properties=[ordered]@{
                    MgmtProfile = @{Type="String"}
                    DefaultRegion = @{Type="String"}
                    OrgUnits = @{
                        Type="HashTable"
                        ItemTypeName="OrgUnit"
                        Key="String"
                        Value="String"
                        Read="Read-OrgUnit"
                    }
                }
            }
            Sources = @{
                Type="HashTable"
                Key="String"
                Value=@{
                    Type="Object"
                    ItemType="Source"
                    Properties=[ordered]@{
                        OrgName = @{Type="String"}
                        Type = @{Type="String"}
                        AcctName = @{Type="String";Read="Read-SourceAcctName"}
                        Repos = @{
                            Type="HashTable";
                            ItemTypeName="Repository"
                            Key="String"
                            Value="String"
                            Read="Read-SourceRepo"}
                    }
                }
            }
            Systems = @{
                Type="HashTable"
                Key="String"
                Value=@{
                    Type="Object"
                    ItemType="System"
                    Properties=[ordered]@{
                        Description = @{Type="String"}
                        Accounts= @{
                            Type="HashTable"
                            ItemType="Account"
                            Key="String"
                            Value=@{
                                Type="Object" 
                                Properties = [ordered]@{
                                    Description = @{Type="String"}
                                    IAMUser = @{Type="String"}
                                    Email = @{Type="String";Read="Read-Email"}
                                    OrgUnit = @{Type="String";Read="Read-OrgUnitRef"}
                                    Type = @{Type="String";Read="Read-AccountType"}
                                    Pipelines = @{
                                        Type="HashTable"
                                        ItemTypeName = "Pipeline"
                                        Key = "String"
                                        Value = @{
                                            Type="Object"
                                            Properties = [ordered]@{
                                                Description = @{Tupe="String"}
                                                TemplatePath = @{Type="String";Read="Read-FilePath"}
                                                Region = @{Type="String";Set="Set-FromDefaultAwsRegion";Read="Read-AwsRegionName"}
                                                TemplateParams = [PSCustomObject]@{
                                                    Type="HashTable"
                                                    ItemTypeName="Template Parameter"
                                                    Key="String"
                                                    Value="String"
                                                    Set="Get-TemplateParameter"
                                                }
                                            }
                                        }
                                    }
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

function ConvertTo-Object($hashtable) 
{
   $object = New-Object PSObject
   $hashtable.GetEnumerator() | 
      ForEach-Object { Add-Member -inputObject $object `
	  	-memberType NoteProperty -name $_.Name -value $_.Value }
   $object
}

#$DocSpec = New-DocSpec
#$Doc = [PSCustomObject]@{ OrgCode="T4"} #settings file
#Read-Tree $Doc $DocSpec "T4"
function Set-Tree {
    #recursively add elements to docObject based on specNode
    param(
        [PSObject]$docNode, #Settings document
        [HashTable]$specNode, #Specifications document node
        [string]$propertyName="root",
        [int]$indent=-4,
        $bc=@() #breadcrumb
    )
    $indent += 4
    $indentstr = " " * $indent
    $bc += $propertyName 
    #Iterate through specification nodes in specifications document, create 
    #document properties
    #Write-Host ""
    #Write-Host $indentstr "Set-Tree"
    #Write-Host $indentstr "propertyName=" $propertyName
    #Write-Host $indentstr ($bc -join '.')
    foreach($n in $specNode) {
        #Write-Host $indentstr "Type=" $n.Type 
        #Write-Host $indentstr "Properties.Count=" $n.Properties.Count
    }

    #Make sure the document object has the specified property
    switch($specNode.Type) {
        "String" { 
            #Write-Host $indentstr "Processing Type String"
            if($null -ne $specNode.Set -And $specNode.Set -ne "") {
                $val = Invoke-Expression $specNode.Set
            } else {
                #Write-Host $indentstr "Assigning empty string value"
                $val = ""
            }
            Add-Property $docNode $propertyName $val
        }
        "HashTable" { 
            #Write-Host $indentstr "Processing Type HashTable"
            $val = @{}
            Add-Property $docNode $propertyName $val
            
        }
        "Object" {
            #Write-Host $indentstr "Processing Type Object"
            $properties = $specNode.Properties
            if($null -eq $properties) {
                Write-Host $indentstr "Error: SpecNode Poroperties missing for Type Object"
                exit
            }
            if($null -eq $docNode) {
                $docNode = [PSCustomObject]@{}
            }
            if($docNode.PSObject.Members.Match($propertyName, 'NoteProperty').Count -eq 0 )
            {
                $val = [PSCustomObject]@{}
                Add-Property $docNode $propertyName $val
            }
            # Properties contains an ordered list of <propertyName, propertySpec> pairs
            # [ordered]@{} doesn't allow you to reference Name, Value directly ;) 
            # or Key, Value. At least this is true in PS 5.1 which we are supporting.
            # So we work around that with a two step reference. 
            foreach($newPropertyName in $properties.Keys) {
                #Write-Host $indentstr "propertyName" $newPropertyName
                $propertySpec = $properties[$newPropertyName]
                $found = $docNode.PSObject.Members.Match($newPropertyName, 'NoteProperty').Count -gt 0 
                if(!$found) {
                    Set-Tree $docNode.$propertyName $propertySpec $newPropertyName $indent $bc
                }
            }
        }
    }
}
function Get-Spec {
    param($rootSpec, [string]$path)

}

function Read-Tree {
    param(
        [PSObject]$docNode, #Settings document root node
        [PSObject]$specNode, #Specifications document root node
        [PSObject]$breadCrumb #current breadcrumb
        )
    if($null -eq $docNode) {
        Write-Host "Error: Read-Tree called with null docNode"
        exit
    }

    if($null -eq $breadCrumb) {
        $breadCrumb = @("doc")
    } 
    if($breadCrumb.GetType().Name -ne "Object[]") {
        $breadCrumb = @($breadCrumb)
    }

    #recursively add elements to docNodeect based on specNode
    # propNames is list of property names in order specified by specification
    # propList is a hashtable keyed by property name with a value of #{Type, Spec}
    Set-Tree $docNode $specNode 

    $propList = [ordered]@{}
    foreach($k in $specNode.Properties.Keys) { 
        $propList.Add($k, $specNode.Properties[$k])
    }
    $propNames = @($propList.Keys)

    # navigate in current doc properties 
    # navigate the yaml file using keystrokes
    # VirtualKeyCode
    # 38 up arrow move to previous property 
    # 40 down arrow move to next property - moves up in tree when it hits the last property in current object
    # 13 enter - edit value if primative type, drill down into object
    # 8 backspace - moves up in tree 

    $propNamesPos = 0
    $lastPos = -1
    $done = $false
    $virtualKeyCode = 0    
    do {

        #Construct the prompt in three pieces
        # Breadcrumb - this is the . separated list of nodes visited. Ex: T4.AWS.MgmtProfile 
        $curObjName = $propNames[$propNamesPos]
        $curObjSpec = $propList[$curObjName]
        $curObjType = $curObjSpec.Type
        $curObj = $docNode.$curObjName
        $prompt = " "
        foreach($crumb in $breadCrumb) {$prompt += "${crumb}."}
        $prompt += $curObjName

        switch($curObjType) {
            "String" {
                # Show the current value 
                $prompt += (" = " + $curObj + " ")
                Write-Host $prompt -NoNewline
            }
            "HashTable" {
                if($null -ne $curObj -And $curObj.PSObject.Members.Match("*",'NoteProperty').Count -gt 0) {
                    Write-Host ""
                    Write-Host $prompt -NoNewLine
                    $curObj | Get-Member -MemberType NoteProperty | ForEach-Object {
                        Write-Host "   " $_.Name 
                    }
                    Write-Host $prompt -NoNewline    
                } else {
                    Write-Host $prompt " (no ${curObjName}, press Enter to add one)" -NoNewLine
                }

            }
            "Object" {
                Write-Host ""
                Write-Host $prompt
                if($null -ne $curObj `
                    -And $curObj.GetType().Name -eq "PSCustomObject" `
                    -And $curObj.PSObject.Members.Match("*",'NoteProperty').Count -gt 0) {
                    foreach($k in $curObjSpec.Properties.Keys) {
                        Write-Host "    -" $k
                    }

                } 
                Write-Host " Press Enter to edit " -NoNewline
            }
        }

        $lastPos = $propNamesPos
        #Write-Host "lastPos" $lastPos "propNamesPos" $propNamesPos
        $ok = $false
        do {
    
            $virtualKeyCode = ($Host.UI.RawUI.ReadKey()).VirtualKeyCode

            #Write-Host "virtualKeyCode" $virtualKeyCode
            switch($virtualKeyCode) {
                38 { #up arrow - PREVIOUS PROPERTY
                    if($propNamesPos -gt 0) {
                        $propNamesPos -= 1
                    }
                }
                40 { #down arrow - NEXT PROPERTY
                    if($propNamesPos -lt ($propNames.length - 1)) {
                        $propNamesPos += 1
                    }
                }
                13 { #enter - EDIT PROPERTY 
                    Write-Host ""
                    switch($curObjSpec.Type ) {
                        "String" {
                            $read = $curObjSpec.Read
                            if($null -eq $read) {
                                $val = Read-Host "Enter a string value"
                                $docNode.$curObjName = $val
                            }
                            $ok = $true
                        }
                        "Object" {
                            Read-Tree $curObj $curObjSpec $breadCrumb
                            $ok = $true
                        }
                        "HashTable" {
                            
                            Read-Tree $curObj $curObjSpec $breadCrumb
                            $ok = $true
                        }
                    }

                }
                8 { #backspace - MOVE UP IN TREE
                    Write-Host ""
                    return
                }
                76 { #l - list items
                    $docNode | ConvertTo-Yaml
                }
            }

        } until ($lastPos -ne $propNamesPos -Or $ok)

        Write-Host ""

    } until ($done)

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


        "Nav"  { 
            #navigate the yaml file using keystrokes
            # up arrow move to previous property
            # down arrow move to next property - moves up in tree when it hits the last property in current object
            # enter - edit value if primative type, drill down into object
            # backspace - moves up in tree 

            #Write-Host $treePath[$treeLevel].PSObject.Members("*", 'NoteProperty').Count
            $DocSpec = New-DocSpec
            $Doc = $Org
            Set-Tree $Doc $DocSpec 
            $Doc | ConvertTo-Yaml
            
            Read-Tree $Doc.root $DocSpec "T4"

            exit

        }
    }
} until($quit)





