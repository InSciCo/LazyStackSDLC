Write-Host "LzDeployPipeline.ps1 V1.0.0"
Write-Host "Use this script to deploy a pipeline"

$scriptPath = Split-Path $script:MyInvocation.MyCommand.Path 
Import-Module (Join-Path -Path $scriptPath -ChildPath LazyStackLib) -Force
Import-Module (Join-Path -Path $scriptPath -ChildPath LazyStackUI) -Force
Test-LzDependencies

$indent = 1


$settingsFile = "smf.yaml"

if(!(Test-Path $settingsFile)) {
    Write-LzHost $indent "Error: Can't find ${settingsFile}"
    exit
}

$smf = Get-SMF $settingsFile # this routine may prompt user for OrgCode and MgmtProfile
$orgCode = @($smf.Keys)[0]
Write-LzHost $indent "OrgCode:" $orgCode
$LzMgmtProfile = $smf.$orgCode.AWS.MgmtProfile
Write-LzHost $indent "AWS Managment Account:" $LzMgmtProfile

$pipelinesMenu = @()
foreach($sysCode in $smf.$orgCode.Systems.Keys) {
    $system = $smf.$orgCode.Systems[$sysCode] 
    foreach($acctName in $system.Accounts.Keys) {
        $awsAcct = $system.Accounts[$acctName]
        $accountFullName = $orgCode + $sysCode + $acctName
        $pipelines = $awsAcct.Pipelines
        foreach($pipelineName in $pipelines.Keys) {
            $pipeline = $pipelines[$pipelineName]
            $pipelineMenuEntry = @{SysCode=$sysCode; AccountName=$acctName; AccountFullName = $accountFullName;  PipelineName=$pipelineName}
            $pipelinesMenu += $pipelineMenuEntry
        }
    }
}
if($pipelinesMenu.Count -eq 0) {
    Write-LzHost $indent "No Pipelines found"
    exit
}

Write-LzHost $indent "Pipelines"
for($i=0; $i -lt $pipelinesMenu.Count; $i++) {
    $item = $pipelinesMenu[$i]
    Write-LzHost $indent ($i + 1) $item.AccountName $item.PipelineName 
}
$selection = Read-MenuSelection `
    -prompt "Select Pipeline to deploy" `
    -min 1 `
    -max $pipelinesMenu.Count `
    -indent $indent `
    -options "q" 

switch($selection) {
    -1 {
        exit
    } 
    default {
        $pipelineMenuEntry = $pipelinesMenu[$selection - 1]
        $sysCode = $pipelineMenuEntry.SysCode 
        $awsAcctName = $pipelineMenuEntry.AccountName
        $pipelineName = $pipelineMenuEntry.PipelineName
        Write-Host "orgCode" $orgCode 
        Write-Host "sysCode" $sysCode 
        Write-Host "awsAcctName" $awsAcctName
        Write-Host "pipeLineName" $pipelineName
        $awsAcct = $smf.$orgCode.Systems.$sysCode.Accounts.$awsAcctName
        $pipeline = $awsAcct.Pipelines[$pipelineName]

        #$pipeline | ConvertTo-Yaml 

        $LzRegion = $awsAcct.DefaultRegion
        if($null -eq $LzRegion -Or $LzRegion -eq "") {
            $LzRegion = $smf.AWS.DefaultRegion
            if($null -eq $LzRegion -Or $LzRegion -eq "") {
                $LzRegion = "us-east-1"
            }
        }

        $region = $pipeline.Region 
        if($null -eq $region -Or $region -eq "") {
            $region = $LzRegion #default from account
        }
    
        $templateParams = ""
        if($null -ne $pipeline.TemplateParams) {
            foreach($propertyName in $pipeline.TemplateParams.Keys) {
                $templateParams += (" " + $propertyName + "=" + '"' + $pipeline.TemplateParams.$propertyName + '" ')
            }
        }
    
        $LzAccessRoleProfile = $orgCode + $sysCode + $awsAcctName + "AccessRole"
        $stackName = Get-ValidAwsStackName($pipelineName + "-" + $pipeline.Region) # replace non-alphanumeric characters with "-"
        $stackName = $stackName.ToLower()
        if($templateParams -eq "") {
            sam deploy `
            --stack-name $stackName `
            -t $pipeline.TemplatePath `
            --capabilities CAPABILITY_NAMED_IAM `
            --profile $LzAccessRoleProfile `
            --region $region           
        } else {
            sam deploy `
            --stack-name $stackName `
            -t $pipeline.TemplatePath `
            --capabilities CAPABILITY_NAMED_IAM `
            --parameter-overrides $templateParams `
            --profile $LzAccessRoleProfile `
            --region $region           
        }
    }
}



