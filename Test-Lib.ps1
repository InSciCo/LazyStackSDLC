
Import-Module (Join-Path -Path (Split-Path $script:MyInvocation.MyCommand.Path) -ChildPath LazyStackLib) -Force
if((Get-LibVersion) -ne "v1.0.0") {
    Write-Host "Error: Imported LazyStackSMF lib has wrong version!"
    exit
}

New-AwsSysAccount `
    -LzMgmtProfile T4Mgmt `
    -LzOUName T4TestOU `
    -LzAcctName T4TutTest `
    -LzIAMUserName T4TutTestIAM `
    -LzRootEmail tmay7657+T4TutTest@gmail.com


Write-Host "done"

