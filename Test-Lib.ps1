
Import-Module (Join-Path -Path (Split-Path $script:MyInvocation.MyCommand.Path) -ChildPath LazyStackLib) -Force

Write-Host "Test-AwsProfileExists" (Test-AwsProfileExists -profilename "BzMgmt")
Write-Host "Test-AwsProfileExists" (Test-AwsProfileExists -profilename "nada")


Write-Host "done"

