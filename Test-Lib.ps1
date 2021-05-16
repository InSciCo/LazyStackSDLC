
Import-Module (Join-Path -Path (Split-Path $script:MyInvocation.MyCommand.Path) -ChildPath LazyStackLib) -Force
if((Get-LibVersion) -ne "v1.0.0") {
    Write-Host "Error: Imported LazyStackSMF lib has wrong version!"
    exit
}
Write-Host "Test-AwsProfileExists" (Test-AwsProfileExists -profilename "BzMgmt")
Write-Host "Test-AwsProfileExists" (Test-AwsProfileExists -profilename "nada")


Write-Host "done"

