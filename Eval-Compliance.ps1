 param (
 [String][Parameter(Mandatory=$true, Position=1)] $ConfigurationBaselineName_PartialMatch,
 [String][Parameter(Mandatory=$false, Position=1)] $ConfigurationBaselineName_MustContainText
 )
 

$Baselines = Get-WmiObject -Namespace root\ccm\dcm -Class SMS_DesiredConfiguration | Where-Object {$_.DisplayName -like "*$ConfigurationBaselineName_PartialMatch*"}
 
If($ConfigurationBaselineName_MustContainText){
    $Baselines = $Baselines | Where-Object {$_.DisplayName -like "*$ConfigurationBaselineName_MustContainText*"}
}

$Baselines | % {
 
 ([wmiclass]"root\ccm\dcm:SMS_DesiredConfiguration").TriggerEvaluation($_.Name, $_.Version) 
 
}
 
