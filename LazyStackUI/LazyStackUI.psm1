
#********* Add Functions *********
function Add-Property {
    param([PSObject]$object, [string]$property, $default=$null)

    if($null -eq $object) { 
        Write-Host "Error: null object passed to Get-SettingsPropertyExists"
        exit
    }
    $type =$object.GetType().Name 
    if($type -eq "OrderedDictionary") {$type = "HashTable"}
    switch($type) {
        "HashTable" {
            if(!$object.Contains($property)) {
                $object.Add($property,$default)
            } else {
                if($null -eq $object[$property]) {
                    $object[$propoerty] = $default
                }
            }
        }
        "PSCustomObject" {
            if($object.PSObject.Members.Match($property, 'NoteProperty').Count -eq 0 ) {
                $object = $object | Add-Member -NotePropertyName $property -NotePropertyValue $default
            } else {
                if($null -ne $default) {
                    if($null -eq $object.$property) {
                        $object.$property = $default
                    }
                }
            }
        }
        default {
            Write-Host "Error: Bad type $type passed"
            exit
        }
    }
}

#********** Read Functions ************
function Read-Email {
    Param ([string]$prompt="Email",[string]$default, [int]$indent)
    $indentstr = " " * $indent
    Write-Host "${indentstr}Note: An email address can only be associated with one AWS Account."
    do {
        $email = Read-Host "${indentstr}${prompt}"
        if($email -eq ""){
            $email = $default
        }
        try {
            $null = [mailaddress]$email
            return $email
        }
        catch {
            Write-Host "${indentstr}Invalid Email address entered! Please try again."
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
        } else { return ""}
    } until ($found)
    return  $strinput
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
   
    return $intvalue
}
function Read-MenuSelection{
    param(
        [string]$prompt="Select",
        [int]$min=1,
        [int]$max,
        [int]$indent=0,
        [string]$options="adqs", 
        [int]$default=0)
    $indentstr = " " * $indent
    if($max -gt 0) {
        $options += "#"
    }
    $options = $options.ToLower()
    $opArray = $options.ToCharArray()
    $op = ""
    foreach($option in $opArray){
        if($op.Length -gt 0) {$op += ", "}
        Switch($option) {
            'a' { $op += "A)dd"}
            'd' { $op += "D)elete" }
            'q' { $op += "Q)uit" }    
            'c' { $op += "C)lear" }       
            's' { $op += "S)kip" }       
            '#' { $op += "#" }
            default {
                Write-Host "Error: Read-MenuSelect passed bad -options specification |${options}|"
            }
        }
    }
    if($op.Length -gt 0) {$op = " [ " + $op + " ]"}
    if($default -gt 0) {
        $op += "(${default})"
    }

    do{
        try {
            $selection = Read-Host ($indentstr + $prompt + $op)
            if($opArray -contains 'q' -And $selection -eq "q"){ return  -1 }
            if($opArray -contains 's' -And $selection -eq "s"){ return  -1 }
            if($opArray -contains 'a' -And $selection -eq "a") { return -2 }
            if($opArray -contains 'd' -And $selection -eq "d" -And $max -gt 0) { return -3 }
            if($opArray -contains 'c' -And $selection -eq 'c') {return -4}
            if($max -ge $min) {
                if($selection -eq "") {
                    $selection = $default
                } else {
                    $selection = [int]$selection
                }
    
                if($selection -lt $min -Or $selection -gt $max) {
                    Write-Host ($indentstr + "Selection value min: ${min} and max: ${max}")
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
            return $value
        }
    } until ($false)
}
function Read-Property {
    param([object]$object, [string]$property, [int]$indent)
    if($null -eq $object) { 
        Write-Host "Error: null object passed to Read-Property"
        exit
    }
    $type =$object.GetType().Name 
    if($type -eq "OrderedDictionary") {$type = "HashTable"}
    switch($type) {

        "PSCustomObject" {
            $defmsg = Get-DefMessage $object.$property
            $object.$property = Read-String `
                -prompt "${property}${defmsg}" `
                -default $object.$property `
                -indent $indent   
        }
        "HashTable" {
            $defmsg = Get-DefMessage $object[$property]
            $object[$property] = Read-String `
                -prompt "${property}${defmsg}" `
                -default $object[$property] `
                -indent $indent               
        }
        default {
            Write-Host "Error: Bad type $type passed"
            exit
        }

    }


}
function Read-PropertyName {
    param ([PSCustomObject]$object,[string]$prompt="Name", [string]$propertyName="", [bool]$exists=$false, [int]$indent=0)
    if($null -eq $object) { 
        Write-Host "Error: null object passed to Read-PropertyName"
        exit
    }
    $type =$object.GetType().Name 
    if($type -eq "OrderedDictionary") {$type = "HashTable"}

    $indentstr = " " * $indent 
    $default = $propertyName
    $defmsg = Get-DefMessage -default $default

    switch($type)
    {
        "PSCustomObject" {
            do {
                $propertyName = Read-String `
                    -prompt "${prompt}${defmsg}" `
                    -indent $indent `
                    -default $propertyName `
                    -propName $true
        
                $found = $object.PSObject.Members.Match($propertyName,'NoteProperty').Count -eq 1
                $ok = ($found -eq $exists) 
                if(!$ok) {
                    if($found) { 
                         Write-Host "${indentstr}Sorry, that name does not exist. Please try again."
                    } else {
                        Write-Host "${indentstr}Sorry, That name already exists. Please try again."
                    }
                }
            } until ($ok)
        }
        "HashTable" {
            do {
                $propertyName = Read-String `
                    -prompt "${prompt}${defmsg}" `
                    -indent $indent `
                    -default $propertyName `
                    -propName $true
        
                $found = $object.Contains("$propertyName")
                $ok = ($found -eq $exists) 
                if(!$ok) {
                    if($found) { 
                         Write-Host "${indentstr}Sorry, that name does not exist. Please try again."
                    } else {
                        Write-Host "${indentstr}Sorry, That name already exists. Please try again."
                    }
                }
            } until ($ok)
        }
        default {
            Write-Host "Error: Bad type $type passed"
            exit
        }
    }


    return $propertyName
}
Function Read-Value {
    param([object]$object, [string]$name, [int]$indent)
    $defmsg = Get-DefMessage $object
    $object = Read-String `
        -prompt "${name}${defmsg}" `
        -default $object `
        -indent $indent       
}
function Read-String {
    Param (
        [string]$prompt, 
        [string]$default, 
        [int]$indent, 
        [boolean]$required = $false, 
        $propName=$false)
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
            if($propName -And !($value -match "^[a-zA-z][a-zA-Z0-9_]*[a-zA-Z0-9]$")) {
                Write-Host "${indentstr}Sorry. Please enter a valid Property name. "
                Write-Host "${indentstr}Propertynames must begin with an Alpha, contain only Alphanumerics and '_'"
            }
            else {
                return $value
            }
        }
    } until ($false)
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
            "y" { return $true}
            "n" { return $false}
            "" {return $default}
        }
    } until ($false)
}
function Read-Continue {
    param([int]$indent)
    $indentstr = " " * $indent
    Read-Host "${indentstr}Press enter to continue"
}

#********** Get Functions ************
function Get-DefaultString {
    param ([string]$current, [string]$default)
    if($current -ne "") {
        return $current
    }
    return $default
}
function Get-DefMessage {
    Param ([string]$current, [string]$default, [string]$example)
    if($current -ne "") {
        return " (current: ${current})"
    }
    if($default -ne "") {
        return " (default: ${default})"
    }
    if ($example -ne "") {
        return " (example: ${example})"
    }
    return ""
}
function Get-MsgIf {
    param ([bool]$boolval, [string]$msg)
    if($boolval) {
        return $msg
    } else { return ""}
}
function Get-MsgIfNot {
    param ([bool]$boolval, [string]$msg)
    if(!$boolval) {
        return $msg
    } else { return ""}
}
function Get-PropertyCount {
    param($object, [string]$property)
    if($null -eq $object) { 
        Write-Host "Error: null object passed to Get-SettingsPropertyExists"
        exit
    }
    $type =$object.GetType().Name 
    if($type -eq "OrderedDictionary") {$type = "HashTable"}
    switch($type) {
        "HashTable" {
            return $object.Count
        }
        "PSCustomObject" {
            return ($object | Get-Member -MemberType NoteProperty).Count
        }
        default {
            Write-Host "Error: Bad type $type passed"
            exit
        }
    }
    return ($object | Get-Member -MemberType NoteProperty).Count
}
function Get-RepoShortName {
    param([string]$repourl)
    $urlparts=$repourl.Split('/')
    $LzRepoShortName=$urlparts[$urlparts.Count - 1]
    $LzRepoShortName=$LzRepoShortName.Split('.')
    $LzRepoShortName=$LzRepoShortName[0].ToLower()    
    return $LzRepoShortName
}
function Get-PropertyExists {
    param([PSObject]$object, [string]$property)
    if($null -eq $object) { 
        Write-Host "Error: null object passed to Get-SettingsPropertyExists"
        exit
    }
    $type =$object.GetType().Name 
    if($type -eq "OrderedDictionary") {$type = "HashTable"}
    switch($type) {
        "HashTable" {
            return $object.Contains($property)
        }
        "PSCustomObject" {
            $propList = ($object | Get-Member -Name $property)
            return [bool]($propList.Count -gt 0)
        }
        default {
            Write-Host "Error: Bad type $type passed"
            exit
        }
    }
}
function Get-ValueOrMsg {
    param([string]$value, [string]$msg)
    if($value -eq "") {
        return $msg
    } else {return $value}
}

#******** Write functions ************
function Write-Properties {
    param($object, [string]$prefix="- ", [int]$indent=4, [int]$item=0)
    if($null -eq $object) { 
        Write-Host "Error: null object passed to Write-Properties"
        exit
    }
    $type =$object.GetType().Name 
    if($type -eq "OrderedDictionary") {$type = "HashTable"}    
    
    $indentstr = " " * $indent

    switch($type) {
        "PSCustomObject" {
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
        "HashTable" {
            foreach($key in $object.Keys) {
                $item = $item + 1
                $name = $key
                $value = $object[$key]
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
        default {
            Write-Host "Error: Bad type $type passed"
            exit
        }
    }
}
function Write-PropertyNames {
    param($object, [string]$prefix="- ", [int]$indent=4, [int]$item=0)
    if($null -eq $object) { 
        Write-Host "Error: null object passed to Write-PropertyNames"
        exit
    }
    $type =$object.GetType().Name 
    if($type -eq "OrderedDictionary") {$type = "HashTable"}        
    
    $indentstr = " " * $indent
    
    switch($type) {
        "PSCustomObject" {
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
        "HashTable" {
            foreach($key in $object.Keys) {
                $item = $item + 1
                $name = $key
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
        default {
            Write-Host "Error: Bad type $type passed"
            exit
        }
    }


}
function Write-PropertySelectionMenu {
    param ($object, `
    [string]$addPrompt="Add", `
    [string]$selectItemPrompt="",`
    [string]$ifNoneMsg="(none defined yet)", `
    [int]$item=0, `
    [int]$indent, `
    [string]$curSelection="")
    if($null -eq $object) { 
        Write-Host "Error: null object passed to Write-PropertySelectionMenu"
        exit
    }
    $type =$object.GetType().Name 
    if($type -eq "OrderedDictionary") {$type = "HashTable"}        

    $indentstr = " " * $indent
    $curSelectionItem = 0
    $foregroundcolor = (get-host).ui.rawui.ForegroundColor
    $backgroundcolor = (get-host).ui.rawui.BackgroundColor
    $menuSelections = [HashTable]@{}

    switch($type) {
        "PSCustomObject" {
            $hasItems = (Get-PropertyCount $object) -gt 0
            if($hasItems) {
                $object | Get-Member -MemberType NoteProperty | ForEach-Object {
                    $item = $item + 1 
                    $val = $_.Name
                    if($curSelection -eq $val) {
                        $curSelectionItem = $item
                        $saveColor = $foregroundcolor
                        $foregroundcolor = $backgroundcolor 
                        $backgroundcolor = $savecolor
                    }
                    Write-Host ($indentstr + "${item}) ") -NoNewLine
                    Write-Host (${selectItemPrompt} + $val) -ForegroundColor $foregroundcolor -BackgroundColor $backgroundcolor
                    $menuSelections.Add($item,$val)
                }
            } else {
                Write-Host "${indentstr}(No Items)"
            }
        }
        "HashTable" {
            $hasItems = $object.Count -gt 0
            if($hasItems) {
                foreach($key in $object.Keys) {
                    $item = $item + 1 
                    $val = $key
                    if($curSelection -eq $val) {
                        $curSelectionItem = $item
                        $saveColor = $foregroundcolor
                        $foregroundcolor = $backgroundcolor 
                        $backgroundcolor = $savecolor
                    }
                    Write-Host ($indentstr + "${item}) ") -NoNewLine
                    Write-Host (${selectItemPrompt} + $val) -ForegroundColor $foregroundcolor -BackgroundColor $backgroundcolor
                    $menuSelections.Add($item,$val)
                }
            } else {
                Write-Host "${indentstr}(No Items)"
            }
        }
        default {
            Write-Host "Error: Bad type $type passed"
            exit
        }        
    }
    return $item, $menuSelections, $curSelectionItem
} 
#*********** Remove Functions *********
function Remove-Property {
    param([PSObject]$object, [string]$property)
    if($null -eq $object) { 
        Write-Host "Error: null object passed to Remove-SettingsProperty"
        exit
    }
    $type =$object.GetType().Name 
    if($type -eq "OrderedDictionary") {$type = "HashTable"}        

    if($property -eq "") {
        return
    }

    switch($type) {
        "HashTable" {
            if($object.Contains($property)) {
                $object.Remove($property)
            }
        }
        "PSCustomObject" {
            if(($object | Get-Member -Name $property) -ne 0) {
                $object.PSObject.Members.Remove($property)
            }
        }
        default {
            Write-Host "Error: Bad type $type passed"
            exit
        }
    }    
}
#*********** Set Functions ***********
function Set-MissingMsg {
    param ([string]$value, [string]$msg="(required - please provide)")
    if($value -eq "") {
        return $msg
    } else {
        return $value
    }
}