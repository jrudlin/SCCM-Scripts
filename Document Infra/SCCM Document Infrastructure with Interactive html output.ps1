# SCCM Infrastructure diagram generator
# for visually documenting your SCCM Hierachy in interactive html

# By Jack Rudlin

# 25/10/19

param (
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]
    $SCCM_SSRS_FQHostname = "sccm-ssrs.jrit.local", # SCCM Central Administration Site reporting point # This should be the FQDN of the SCCM Reporting Point server at the top level, so CAS, if it's a hierarchy.

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]
    $PSWriteHTMLModuleName = "PSWriteHTML", # Awesome PS module by https://twitter.com/evotecpl

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [URI]
    $ImagesBaseURL = "http://blogsite.com/SCCMImages", # Where all the SCCM Images are stored and can be downloaded by this script. Probably the same site where you will publish this output html file ideally.

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [String]
    $HeaderText = "SCCM - Dev" # SCCM Environment displayed as the header on the HTML output
    
)

# GLOBAL Variables

# SaveAs/Export path and file name
$SaveAsFileName = "SCCM Infrastructure Diagram"
$SaveAsPath = $(If(test-path ([environment]::getfolderpath("mydocuments"))){
                ([environment]::getfolderpath("mydocuments"))}
              else {
                  $env:TEMP
              })
$HTML = $SaveAsPath+"\"+$SaveAsFileName+"_$(get-date -Format yyyy-MM-dd).html"

# Unlikely this will ever need to change, unless a newer version of SQL Server removes the old ReportExecution service.
$ReportServerUri = "http://$SCCM_SSRS_FQHostname/ReportServer/ReportExecution2005.asmx?wsdl"
$ReportServerServiceUri = "http://$SCCM_SSRS_FQHostname/ReportServer/ReportService2010.asmx";

# Unlikely these will need to be changed. But a quick check after a new version of SCCM is released and installed is all that's needed
$SCCM_SiteRoles_ReportName = 'Site system roles and site system servers for a specific site'
$SCCM_SiteStatus_ReportName = 'Site status for the hierarchy'
$RolesToIgnore = @('Component server','Site system');#Don't include these site components in the Visio text shape as all site systems have these


If(-not((Test-NetConnection -ComputerName $SCCM_SSRS_FQHostname -CommonTCPPort HTTP).TcpTestSucceeded)){
    Write-Error -Message "Could not connect to SSRS on $SCCM_SSRS_FQHostname. Please check in the browser to http://$SCCM_SSRS_FQHostname"
    return
}

# Check modules
If(-not(Get-Module -ListAvailable -Name $PSWriteHTMLModuleName)){

        Write-Error -Message "`nCould not find module $PSWriteHTMLModuleName. `nThis module needs to be installed before running this script."
        return
    
} else {
    Import-Module -Name $PSWriteHTMLModuleName
}

Function Get-SCCMImageName{
    [CmdletBinding()]
    param(    
        [parameter(Mandatory=$true)]
        $SCCMRoles,
        [parameter(Mandatory=$true)]
        [bool]$IsCAS,
        [parameter(Mandatory=$false)]
        $IgnoreRoles,
        $ImagesBaseURL

    )

    $RolesFiltered = ($SCCMRoles | Where-Object {$_ -NotIn $RolesToIgnore})
    # Priorise which image to select where servers contain multiple roles
    If($RolesFiltered -contains "Site server"){
        $SCCMRole = "Site server"
    } elseif($RolesFiltered -contains "Site database server"){
        $SCCMRole = "Site database server"
    } elseif($RolesFiltered -contains "Reporting services point"){
        $SCCMRole = "Reporting services point"
    } else {
        $SCCMRole = $RolesFiltered | Select-Object -Last 1
    }

        switch($SCCMRole){

            "Site server" { If($IsCAS){$return = "CAS.png"}else{$return = "Primary_Site_Server.png"}}
            "Site database server" { If($IsCAS){$return = "SQL_Server_-_CAS.png"}else{$return = "SQL_Server_-_Primary_Site.png"}}
            "Software update point" {$return = "Software_Update_Point.png"}
            "Reporting services point" {$return = "Reporting_Services_Point_.png"}
            "Management point" {$return = "Management_Point.png"}
            "Distribution point" {$return = "Distribution_Point_Server.png"}
            "State Migration Point" {$return = "State_Migration_Point.png"}
            "Fallback Status Point" {$return = "Fallback_Status_Point.png"}
            "SMS Provider" {$return = "SMS_Provider.png"}
            default {$return = "Management_Point.png"}

        }

        

        return "$ImagesBaseURL/$return"
}

Function Update-VisioShapeText{

    [CmdletBinding(DefaultParameterSetName="Update_Text")]
    param(    
        [parameter(Mandatory=$true)]
        $Shape,
        [parameter(ParameterSetName="Update_Text",Mandatory=$false)]
        [string]$Text,
        [parameter(ParameterSetName="AddIP",Mandatory=$false)]
        [bool]$AddIP
    )

    if($AddIP){
        write-host "`n-ADDIP specified. Resolving IP of $($shape.name)" -ForegroundColor Green
        $address=Resolve-DnsName $shape.name
        $text = $address.IPAddress
    }
  
    Try{
        write-host "Adding text: $text to shape $($shape.name)" -ForegroundColor Green
        $newLabel="{0}`n{1}" -f $Shape.text,$Text
        $Shape.Text=$newLabel
    } catch {
        write-error "Could not set shape $($Shape.Name) to text $Text. Please check Visio is open and shape exists" -ErrorAction SilentlyContinue
    }

}

function Set-VisioServer{

    [CmdletBinding()]
    param(    
        [parameter(Mandatory=$true)]
        $Server,
        [parameter(Mandatory=$true)]
        [double]$x,
        [parameter(Mandatory=$true)]
        [double]$y,
        [parameter(Mandatory=$true)]
        $RolesToIgnore,
        [parameter(Mandatory=$true)]
        $page,
        [parameter(Mandatory=$false)]
        $ConnectToShape,
        [parameter(Mandatory=$false)]
        $SiteContainer,
        [parameter(Mandatory=$false)]
        $IsCAS = $false
    )

        # Pick a visio shape from the custom stencil based on the SCCM roles (but not the ones in $rolestoignore)
        $SCCM_Stencil_Shape_Name = Get-VisioSCCMStencilShapeName -SCCMRoles $server.group.Details_Table0_RoleName -IsCAS $IsCAS -IgnoreRoles $RolesToIgnore

        $Visio_Custom_Stencil=$SCCM_Servers_Stencil.Masters($SCCM_Stencil_Shape_Name)
        
        $VisioServer = $Page.Drop($Visio_Custom_Stencil,$x,$y)
        $VisioServerNetbiosName=($($Server.Name).Split('.'))[0]
        $VisioServer.text=$VisioServerNetbiosName
        $VisioServerFQDN=($($Server.Name).TrimStart($VisioServerNetbiosName).TrimStart('.'))
        Update-VisioShapeText -Shape $VisioServer -Text $VisioServerFQDN
        $VisioServer.Name=$($Server.Name)
        write-host "Drop locations set to X:$x and Y:$y for shape: $($VisioServer.Name)" -ForegroundColor Blue -BackgroundColor white

        Update-VisioShapeText -Shape $VisioServer -AddIP $True
                            
        If($ConnectToShape){
            $ConnectToShape.AutoConnect($VisioServer,0)
            $connector = $page.Shapes | Where-Object {$_.style -eq 'Connector'} | Select-Object -Last 1
            $Connector.Cells('ShapeRouteStyle') = 16
            $Connector.Cells('ConLineRouteExt') = 1
        }
        

        if($SiteContainer)
        {
            write-host "Adding shape $($VisioServer.Name) to container: $($SiteContainer.Name)"
            $SiteContainer.ContainerProperties.AddMember($VisioServer,0)
        }
        
        foreach($role in ($Server.Group | where-object {$_.Details_Table0_RoleName -notin $RolesToIgnore} | select-object -ExpandProperty Details_Table0_RoleName))
        {
            Update-VisioShapeText -Shape $VisioServer -Text $role;
        }

        $TextBoxLineCount = ($VisioServer.text | Measure-Object -Line).Lines
        $TextBoxLineCountSplit = [int[]](($TextBoxLineCount -split '') -ne '')
        If($TextBoxLineCountSplit.count -eq 2){
            $TxtHeight = "Height*-$($TextBoxLineCountSplit[0]).$($TextBoxLineCountSplit[1])"
        } elseif ($TextBoxLineCountSplit.count -eq 1) {
            $TxtHeight = "Height*-0.$($TextBoxLineCountSplit)"
        } else {
            $TxtHeight = "Height*-0.4"
        }
        
        $VisioServer.CellsSRC($visSectionObject, $visRowTextXForm, $visXFormWidth).FormulaU = "Width*4"
        
        If($IsCAS -or ($server.group.Details_Table0_RoleName | Where-Object {$_ -eq "Site server"})){
        } else {
            $VisioServer.CellsSRC($visSectionObject, $visRowTextXForm, $visXFormPinY).FormulaU = $TxtHeight
        }
        
               
}

function Get-WebServiceConnection
{
    [CmdletBinding()]
    param(    
        [parameter(Mandatory=$true)]
        [string]$url,
        [parameter(Mandatory=$false)]
        $Creds
    )
  
    $reportServerURI = $url

    Write-Host "Getting Web Proxy Details $url"

    Try{
    $RS = New-WebServiceProxy -Uri $reportServerURI -UseDefaultCredential -ErrorAction Stop
    } Catch {
        Write-Host "Error: $_ when connecting to $reportServerURI" -ForegroundColor Yellow
        write-host "Try providing creds to connect to the report server..." -ForegroundColor Yellow
        $RS = New-WebServiceProxy -Uri $reportServerURI -Credential $Creds
    }

    $RS.Url = $reportServerURI
    return $RS
}

function Get-SQLReport
{
    [CmdletBinding()]
    param(    
        [parameter(Mandatory=$true)]
        $ReportingServicesWebProxy,
        [parameter(Mandatory=$true)]
        [string]$reportPath,
        $parameters
    )

    Write-Host "Getting Report $reportPath"
    
    $ReportingServicesWebProxy.GetType().GetMethod("LoadReport").Invoke($ReportingServicesWebProxy, @($reportPath, $null))
    
    $ReportingServicesWebProxy.SetExecutionParameters($parameters, "en-us") > $null

    $devInfo = "<DeviceInfo></DeviceInfo>"
    $extension = ""
    $mimeType  = ""
    $encoding = ""
    $warnings = $null
    $streamIDs = $null

    $RenderedOutPut = $ReportingServicesWebProxy.Render("XML",$devInfo,[ref]$extension,[ref]$mimeType,[ref]$encoding,[ref]$warnings,[ref]$streamIDs)

    $doc = [System.Xml.XmlDocument]::new()
    $memStream = New-Object System.IO.MemoryStream  @($RenderedOutPut,$false)
    $doc.Load($memStream)
    write-output $doc

    $memStream.Close()
    
}

function New-SSRSParameter
{
    [CmdletBinding()]
    param(    
                    [string]$Name,
        [string]$Value
    )

    $param = New-Object PSObject
    Add-Member -InputObject $param -Name "Name" -Value $Name -MemberType NoteProperty
    Add-Member -InputObject $param -Name "Value" -Value $Value -MemberType NoteProperty
    Write-Output $param 
}

Function Get-SCCMSiteCodesReport{

    [CmdletBinding()]
    param(    
        [parameter(Mandatory=$true)]
        $ReportingServicesWebProxy,
        [parameter(Mandatory=$true)]
        $SiteStatusReportPath
    )

    # Get all the site codes of the SCCM infrastructure/hierarchy from SSRS
    $parameters = @()
    $SiteCodesReport = Get-SQLReport -ReportingServicesWebProxy $ReportingServicesWebProxy -reportPath $SiteStatusReportPath -parameters $parameters

    Write-Output -InputObject $SiteCodesReport
}

#Get the location of the reports we need to list the site code and site systems in the hierarchy
Try{
    $ReportServiceProxy = New-WebServiceProxy -Uri $ReportServerServiceUri -Namespace "SSRS" -UseDefaultCredential -ErrorAction Stop
} Catch {
    Write-Host "Error: $_ when connecting to $reportServerURI" -ForegroundColor Yellow
        write-host "Try providing creds to connect to the report server..." -ForegroundColor Yellow
        $Creds = (Get-Credential)
        $ReportServiceProxy = New-WebServiceProxy -Uri $ReportServerServiceUri -Namespace "SSRS" -Credential $Creds
}
$AllReports=$ReportServiceProxy.ListChildren("/", $true);
#$items | select Type, Path, ID, Name | sort-object Type, Name
$SiteStatusReportPath = ($AllReports | Where-Object -Property Name -like $SCCM_SiteStatus_ReportName).Path
$SiteRolesReportPath = ($AllReports | Where-Object -Property Name -like $SCCM_SiteRoles_ReportName).Path

$webProxy = Get-WebServiceConnection -url $ReportServerUri -Creds $Creds
$SiteCodesReport = Get-SCCMSiteCodesReport -ReportingServicesWebProxy $webProxy -SiteStatusReportPath $SiteStatusReportPath

# List of all the site codes
$SCCM_SiteCodes = $SiteCodesReport.Report.Table0.Detail_Collection.Detail.Details_Table0_SiteCode | ForEach-Object {$_.Trim()}

# Get the table header name of the secondary sites column as for some reason Microsoft have not standardised on the name
$SCCM_SecondarySite_Report_Header_Filter = ($SiteCodesReport.Report.Table0 | ForEach-Object {$_.PSObject.properties} | Where-Object {$_.Value -like "*Secondary Site"}).Name -split "_" | Select-Object -Last 1
If($SCCM_SecondarySite_Report_Header_Filter.count -ne 1){write-error "`nCould not find 'Secondary Site' header from report $SiteStatusReportPath. Please check that Microsoft have not changed the table header values";break}
# Get the the property name for secondary sites
$SCCM_SecondarySite_Report_Property_Name = ($SiteCodesReport.Report.Table0.Detail_Collection.Detail | ForEach-Object {$_.PSObject.properties} | Where-Object {$_.Name -like "*$SCCM_SecondarySite_Report_Header_Filter*"}).Name  | Select-Object -Last 1
# Check if any of the site codes are marked as secondary sites
$AllSecondarySitesCodes = ($SiteCodesReport.Report.Table0.Detail_Collection.Detail | Where-Object {$_.$($SCCM_SecondarySite_Report_Property_Name) -eq "True"}).Details_Table0_SiteCode
If($AllSecondarySitesCodes){
    write-host "`nSCCM Infrastructure has $($AllSecondarySitesCodes.count) Secondary Site/s" -ForegroundColor Green
    $AllSecondarySitesCodes = $AllSecondarySitesCodes | ForEach-Object {$_.Trim()}
} else {
    write-host "`nSCCM Infrastructure doesn't have a Secondary Site" -ForegroundColor Green
}

Function Get-SCCMServers{
    [CmdletBinding()]
    param(    
        [parameter(Mandatory=$true)]
        $SiteCodes,
        [parameter(Mandatory=$true)]
        $WebProxy,
        [parameter(Mandatory=$true)]
        $SiteRolesReportPath
    )
     
    #Loop each of the site codes and get the SCCM system servers/systems in the site    
    $SCCMServers = @()
    ForEach($site in $SiteCodes){
        $parameters = @()
        $parameters += New-SSRSParameter -Name "variable" -Value $site

        write-host "Attempting to load report $ReportPath for site $site "
        $SCCM_SiteRoles_ReportXML = Get-SQLReport -ReportingServicesWebProxy $WebProxy -reportPath $SiteRolesReportPath -parameters $parameters

        $SCCMServers += $SCCM_SiteRoles_ReportXML.Report.Table0.Detail_Collection.Detail
        write-host "$(($SCCM_SiteRoles_ReportXML.Report.Table0.Detail_Collection.Detail).count) SCCM system roles details retrieved from the report"
    }
    write-host "`nTotal roles retrieved: $($SCCMServers.count)" -ForegroundColor Green
    Write-Output -InputObject $SCCMServers

}

$SCCMServers = Get-SCCMServers -SiteCodes $SCCM_SiteCodes -WebProxy $webProxy -SiteRolesReportPath $SiteRolesReportPath

#region Determine top level site code
# Site must be standalone primary site if it only has one site code
write-host "`nDetermine if CAS Hierarchy or Standalone Primary site....." -ForegroundColor Green
If($SCCM_SiteCodes.Count -eq 1 -and (-not($AllSecondarySitesCodes))){
    ######################## Standalone Primary ###############################
    write-host "`nOnly one SCCM site code so infrastructure is an Standalone Primary Site with no secondaries" -ForegroundColor Green
    $SCCM_Standalone_Primary_SiteCode = $SCCM_SiteCodes
    ######################## Standalone Primary ###############################
} elseif (
    ######################## CAS ###############################
    # If there is a site without a management point it must be a CAS site as Primary and Secondary sites both must have at least one MP each
    ($SCCMServers `
     | Where-Object {$_.Details_Table0_RoleName -like "Management Point"} `
     | Select-Object -Property Details_Table0_SiteCode -Unique
    ).Count -ne $SCCM_SiteCodes.Count
){
    write-host "`nSCCM infrastructure is a CAS" -ForegroundColor Green
    $SitesWithMPs = ($SCCMServers | Where-Object {$_.Details_Table0_RoleName -like "Management Point"} | Group-Object -Property Details_Table0_SiteCode).Name
    $SCCM_CAS_SiteCode = ($SCCMServers `
     | Where-Object {$_.Details_Table0_SiteCode -notin $SitesWithMPs}).Details_Table0_SiteCode | Select -First 1
    write-host "CAS Site code determined as: $SCCM_CAS_SiteCode" -ForegroundColor Green

    ######################## CAS ###############################
} else {
    ######################## Primary with Secondaries ###############################
    # If there is no CAS but there are multiple sites, then the infrastructure must be a Primary site with secondaries attached
    write-host "`nSCCM Infrastructure is a standalone with secondaries" -ForegroundColor Green
    $SCCM_Primary_with_Secondaries_SiteCode = $SCCM_SiteCodes | Where-Object {$_ -notin $AllSecondarySitesCodes}
    write-host "The Standalone Primary site code (that also has secondaries) is: $SCCM_Primary_with_Secondaries_SiteCode"
    ######################## Primary with Secondaries ###############################
}
#endregion

# Sort SCCM servers into Groups
$SortedSitesWithoutCAS = $SCCMServers | where-object -FilterScript {$_.Details_Table0_SiteCode -ne $SCCM_CAS_SiteCode} | select-object -unique -Property Details_Table0_SiteCode,Details_Table0_ServerName | group-object -property Details_Table0_SiteCode
$AllServers = $SCCMServers | select-object -unique -Property Details_Table0_SiteCode,Details_Table0_ServerName | group-object -property Details_Table0_SiteCode
#$MaximumServers = $AllServers | Measure-Object -Property Count -Maximum | Select-Object -ExpandProperty Maximum

# Separate Site Server and Site Systems
$SCCMServers_CAS = $SCCMServers | Where-Object {$_.Details_Table0_SiteCode -eq $SCCM_CAS_SiteCode}
$SCCMServer_CAS_SiteServer = $SCCMServers_CAS | Group-Object -Property Details_Table0_ServerName | where-object {$_.Group.Where({$_.Details_Table0_RoleName -eq "Site Server"}) }
$CASSCCMNonSiteServers = $SCCMServers_CAS | Group-Object -Property Details_Table0_ServerName | where-object {!($_.Group.Where({$_.Details_Table0_RoleName -eq "Site Server"})) }
$SCCM_SiteCodes_WithoutCAS = $SCCM_SiteCodes | Where-Object {$_ -ne $SCCM_CAS_SiteCode}



# Start with CAS hierarchies
If($SCCM_CAS_SiteCode){
     
    $CASName = $SCCMServer_CAS_SiteServer.Name -replace('(^[\w-_\d]+)\.(.*)','$1')
    write-host "`nCAS site server hostname: [$CASName]" -ForegroundColor Green

    New-HTML -TitleText 'SCCM Infra Diagram' -UseCssLinks:$false -UseJavaScriptLinks:$false -FilePath $HTML {
        New-HTMLSection -HeaderText $HeaderText -CanCollapse {
            New-HTMLPanel {
                New-HTMLDiagram {
                    New-DiagramOptionsPhysics -Enabled $true
                    New-DiagramOptionsInteraction -Hover $true
                    ForEach ($Server in $CASSCCMNonSiteServers){
                        $ServerName = $Server.Name -replace('(^[\w-_\d]+)\.(.*)','$1')
                        New-DiagramNode -Label $ServerName -To $CASName -ImageType squareImage -Image $(Get-SCCMImageName -SCCMRoles $Server.Group.Details_Table0_RoleName -ImagesBaseURL $ImagesBaseURL -IsCAS $False)
                    }
                    New-DiagramNode -Label $CASName -ImageType squareImage -Image $(Get-SCCMImageName -SCCMRoles $SCCMServer_CAS_SiteServer.Group.Details_Table0_RoleName -ImagesBaseURL $ImagesBaseURL -IsCAS $True)
                    ForEach ($Site in $SCCM_SiteCodes_WithoutCAS){
                        $SCCMServersCurrent = $SCCMServers | Where-Object {$_.Details_Table0_SiteCode -eq $Site}
                        $GroupedSCCMSiteServers = $SCCMServersCurrent | Group-Object -Property Details_Table0_ServerName
                        $SCCMSiteServers = $GroupedSCCMSiteServers | where-object {$_.Group.Where({$_.Details_Table0_RoleName -eq "Site Server"}) }
                        $SCCMNonSiteSystems = $GroupedSCCMSiteServers | where-object {!($_.Group.Where({$_.Details_Table0_RoleName -eq "Site Server"})) }
                        
                        foreach($SiteServer in $SCCMSiteServers){
                            $SiteServerName = $SiteServer.Name -replace('(^[\w-_\d]+)\.(.*)','$1')
                            New-DiagramNode -Label $SiteServerName -To $CASName -ImageType squareImage -Image $(Get-SCCMImageName -SCCMRoles $SiteServer.Group.Details_Table0_RoleName -ImagesBaseURL $ImagesBaseURL -IsCAS $False)
                        }

                        ForEach($SiteSystem in $SCCMNonSiteSystems){
                            $ServerName = $SiteSystem.Name -replace('(^[\w-_\d]+)\.(.*)','$1')
                            New-DiagramNode -Label $ServerName -To $SiteServerName -ImageType squareImage -Image $(Get-SCCMImageName -SCCMRoles $SiteSystem.Group.Details_Table0_RoleName -ImagesBaseURL $ImagesBaseURL -IsCAS $False)
                        }

                    }
                } -BackgroundSize '1000px' -Height '1000px' -Width '1000px'
            }
        }
    } -ShowHTML
 
}