# Get images from Visio stencils and export them as jpg
# By Jack Rudlin
# 24/10/19

# Custom SCCM Stencils used for building the infrastructure diagram
$SCCM_Servers_Stencil_Path="C:\Temp\ConfigMgr 1810 (All) v1.4\ConfigMgr 1810\ConfigMgr 1810 (Servers).vss"
$VisioModule = "Visio" # https://www.powershellgallery.com/packages/Visio
$ExportLocation = "c:\temp\SCCM_Images"

If(-not(Test-Path -Path $SCCM_Servers_Stencil_Path)){write-error -Message "Could not access or find the stencils @ $SCCM_Servers_Stencil_Path. Please check this location exists"}

Install-Module -Name $VisioModule

New-VisioApplication
$app = Get-VisioApplication

#Set the background color
#$app.Settings.RasterExportBackgroundColor = 14798527
#Set the transparency color
#$app.Settings.RasterExportTransparencyColor = 13269045
#Use the transparency color
$app.Settings.RasterExportUseTransparencyColor = $false


New-VisioDocument

$sccmshapes = Open-VisioDocument $SCCM_Servers_Stencil_Path
md $ExportLocation
ForEach ($SCCMShape in ($sccmshapes.Masters | select Name).Name){
    write-host "Working on shape [$SCCMShape]"
    $master = Get-VisioMaster "$SCCMShape" -Document $sccmshapes
    $points = New-Object VisioAutomation.Geometry.Point(4,5)
    $shape = New-VisioShape -Master $master -Position $points
    #$shape.Export("c:\temp\SCCM_Images\$SCCMShape.png")
    $FileName = $SCCMShape -replace '_*(\[.*?\]|\(.*?\)|\\|\/)_*'
    write-host "Filename: [$FileName]"
    Export-VisioShape -Filename "$ExportLocation\$FileName.png" -Shape $shape -Overwrite
    Remove-VisioShape -Shape $shape
}