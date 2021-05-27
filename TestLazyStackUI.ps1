#Test LaxyStackUI Functions
Import-Module (Join-Path -Path (Split-Path $script:MyInvocation.MyCommand.Path) -ChildPath LazyStackUI) -Force

if($true) {
    #Test HashTable Properties access
    $hash = [ordered]@{
        Yada = "yada"
        Bada = "bada"
    }
    Write-Host ""
    Write-Host 'Read-Property $hash Yada'
    Read-Property $hash Yada
    Write-Host ""
    Write-Host 'Read-PropertyName $hash "Press Enter"  "Yada" $true'
    Read-PropertyName $hash "Press Enter"  "Yada" $true
    Write-Host ""
    Write-Host 'Read-PropertyName $hash "Press Enter" "Nada" $false '
    Read-PropertyName $hash "Press Enter" "Nada" $false 
    Write-Host ""
    Write-Host 'Get-SettingsPropertiesExists $hash Yada'
    if(!(Get-PropertyExists $hash Yada)) {
        Write-Host "Error"
        exit
    } 
    Write-Host ""
    Write-Host 'Write-Properties $hash'
    Write-Properties $hash
    Write-Host ""
    Write-Host 'Write-PropertyNames $hash'
    Write-PropertyNames $hash
    Write-Host ""
    Write-Host '$items, $menuSelections,$curSelectionItem = Write-PropertySelectionMenu $hash'
    $items, $menuSelections,$curSelectionItem = Write-PropertySelectionMenu $hash
    if($items -ne 2 -Or $menuSelections.Count -ne 2 -Or $curSelectionItem -ne 0) {
        Write-Host "call failed"
        exit
    }
    $hash2 = [ordered]@{
        Yada = "yada"
        Bada = "bada"
    }
    Write-Host ""
    Write-Host 'Remove-SettingsProperty $hash2 Yada'
    Remove-Property $hash2 Yada
    if($hash2.Count -ne 1) {
        Write-Host "call failed"
        exit
    }

}

if($true) {
    #Test PSCustomObject Properties access
    $psObj = [PSCustomObject]@{
        Yada = "yada"
        Bada = "bada"
    }
    Write-Host ""
    Write-Host 'Read-Property $psObj Yada'
    Read-Property $psObj Yada
    Write-Host ""
    Write-Host 'Read-PropertyName $psObj "Press Enter"  "Yada" $true'
    Read-PropertyName $psObj "Press Enter"  "Yada" $true
    Write-Host ""
    Write-Host 'Read-PropertyName $psOBj "Press Enter" "Nada" $false '
    Read-PropertyName $psOBj "Press Enter" "Nada" $false 
    Write-Host ""
    Write-Host 'Get-SettingsPropertiesExists $psObj Yada'
    if(!(Get-PropertyExists $psObj Yada)) {
        Write-Host "Error"
        exit
    }
    Write-Host ""
    Write-Host 'Write-Properties $psObj'
    Write-Properties $psObj
    Write-Host ""
    Write-Host 'Write-PropertyNames $psObj'
    Write-PropertyNames $psObj
    Write-Host ""
    Write-Host 'Write-PropertySelectionMenu $psObj'
    $items, $menuSelections, $curSelectionItem = Write-PropertySelectionMenu $psObj
    if($items -ne 2 -Or $menuSelections.Count -ne 2 -Or $curSelectionItem -ne 0) {
        Write-Host "call failed"
        exit
    }    

    $psObj2 = [PSCustomObject]@{
        Yada = "yada"
        Bada = "bada"
    }    
    Write-Host ""
    Write-Host 'Remove-SettingsProperty $psObj2 Yada'
    Remove-Property $psObj2 Yada
    $count
    if($psObj2.PSObject.Members.Match("*",'NoteProperty').Count -ne 1) {
        Write-Host "call failed"
        exit
    }
}



