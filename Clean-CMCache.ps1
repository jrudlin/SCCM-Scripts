<#

.DESCRIPTION
    Cleaning up CCM cache items which is not a part of the In-Place Upgrade and PreCache Task Sequence AND is older than 1 day
    PackageIDs which is a part of the ApprovedPkgsIDs array is skipped.
#> 

# Variables
$Win10UpgradeVersion = "1809"
$WaaS_Reg = "HKLM:\Software\JR IT\WaaS\$Win10UpgradeVersion"


# Check for administrative rights
if (-NOT([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    
    Write-Warning -Message "The script requires elevation" ; break
    
}

# Array to store PackageIDs needed by the pre-cache TS
$ApprovedPkgIDs = @()

# Create Registry path 
$RegistryPath = $WaaS_Reg
if (-not(Test-Path -Path $RegistryPath -ErrorAction SilentlyContinue)) {
    New-Item -Path $RegistryPath –Force
}

Try {
    # Check running in Task Sequence
    $TSEnv = New-Object -ComObject Microsoft.SMS.TSEnvironment -ErrorAction SilentlyContinue
    If($TSEnv){
    
        #Get all TS references
        $Namespace = "ROOT\ccm\Policy\Machine"
        $TSClass = "CCM_TaskSequence"
        $RunningTS_PackageID = $TSEnv.Value('_SMSTSPackageID')
        $TS = Get-WmiObject -Namespace $Namespace -Class $TSClass -Filter "PKG_PackageID='$RunningTS_PackageID'" -ErrorAction SilentlyContinue
        If($TS){
    
            ForEach ( $Ref in $TS.TS_References ) {
    
                $Ref.Split(' ') | % {
                    If ( $_ -like "PackageID*" )
                    { 
                        $ApprovedPkgIDs += ($_.split('='))[1] -replace '"', ""
                    }
                }

            }

            $CM_Applications = Get-WmiObject -Namespace root\ccm\ClientSDK -Query 'SELECT * FROM CCM_Application' -ErrorAction Stop 
            Foreach ($Application in $CM_Applications) {     
                #write-output $Application.FullName
                $Application.Get() 
                Foreach ($DeploymentType in $Application.AppDTs) { 

                    ## Get content ID for specific application deployment type 
                    $AppType = 'Install',$DeploymentType.Id,$DeploymentType.Revision 

                    $AppContent = Invoke-WmiMethod -Namespace root\ccm\cimodels -Class CCM_AppDeliveryType -Name GetContentInfo -ArgumentList $AppType 
                    $ApprovedPkgIDs += $AppContent.ContentId
                }

            }

            write-output "[$($ApprovedPkgIDs)] package IDs discovered from running TS [$RunningTS_PackageID]"

        } else {
            write-output "Could not locate Task Sequence [$RunningTS_PackageID] in WMI"
        }

    }
}
Catch
{
    write-output "Couldn't set approved package IDs using the running TS IDs"
}
Finally
{
    If(-not($ApprovedPkgIDs)){
        # PackageIDs which is a part of the precaching
        $ApprovedPkgIDs = "JR100002","JR1067C6","JR1067CA","Content_125312f0-da74-48e0-926a-f9f04f1d2b6d"
        write-output "Set static approved package IDs to keep in CCMCache [$ApprovedPkgIDs]"
    }
}
# Construct COM Object
$CMClient = New-Object -ComObject "UIResource.UIResourceMgr"

# Get CM cache information
$CacheInfo = $CMClient.GetCacheInfo()
$CacheUsedSpace = $CacheInfo.TotalSize - $CacheInfo.FreeSize

# Minimum space required in MB
[int32]$CacheMinSpace = "5000"

# Remove PackageIDs content size (that are part of the TS) from the total required space as they are already downloaded and present in the cache
write-output "Removing [$($ApprovedPkgIDs.Count)] items from MinCacheSpace required var"
ForEach ( $ContentItem in $ApprovedPkgIDs ){
    $Cache = $null
    write-output "Checking if [$ContentItem] is already in CCMCache"
    $Cache = ($CacheInfo.GetCacheElements() | Where-Object -Property ContentId -EQ $ContentItem -ErrorAction SilentlyContinue | Sort-Object -Property ContentVersion -Descending)
    If($Cache){
        If($Cache.count -gt 1){
             Write-Output "Removing [$($Cache[0].ContentSize /1024)]MB's from MinCacheSpace required [$CacheMinSpace]"
             $CacheMinSpace = $CacheMinSpace - $($Cache[0].ContentSize /1024)
        } else {
            Write-Output "Removing [$($Cache.ContentSize /1024)]MB's from MinCacheSpace required [$CacheMinSpace]"
            $CacheMinSpace = $CacheMinSpace - $($Cache.ContentSize /1024)
        }
    } else {
       Write-Output "Could not find [$ContentItem] in CCMCache"
    }
}

# If the free space in the CM cache is less than or equal to the minimum required by the IPU -> Do cleanup
if ($CacheInfo.FreeSize -le $CacheMinSpace) {

    Write-Output "CM cache is containing $($CacheUsedSpace)MB and has $($CacheInfo.FreeSize)MB free space. Not enough to precache IPU content"
    
    # Counting items in the CM cache for the first time. Only items not a part of the approved apps is being count
    $CacheCount = ($CacheInfo.GetCacheElements() | Where-Object {$_.ContentId -notin $ApprovedPkgIDs -AND $_.LastReferenceTime -lt (Get-Date).AddDays(-1)}).count

    # If items found, continue deletion
    if ($CacheCount -ge "1") {

        # For each element in the CM cache - delete it
        $CacheInfo.GetCacheElements() | Where-Object {$_.ContentId -notin $ApprovedPkgIDs -AND $_.LastReferenceTime -lt (Get-Date).AddDays(-1)} | % {
        
            try {
                Write-Output "Deleting cacheElementID" $_.CacheElementID
                $CacheInfo.DeleteCacheElement($_.CacheElementID)
            }
            catch [exception] {
                Write-Output "Something went wrong when deleting the cache element. Error message is: $_"
                    
            }
        }
    
        # If the cache is now empty, create registry entries for inventory and reporting
        $CacheCount = ($CacheInfo.GetCacheElements() | Where-Object {$_.ContentId -notin $ApprovedPkgIDs -AND $_.LastReferenceTime -lt (Get-Date).AddDays(-1)}).count
        if ($CacheCount -eq "0") {
            
            Write-Output "CM cache is empty"
            $RegistryPath = $WaaS_Reg
            if (-not(Test-Path -Path $RegistryPath)) {
                New-Item -Path $RegistryPath –Force
            }

            New-ItemProperty -Path $RegistryPath -Name "CacheCleanUpStatus" -Value 0 -PropertyType "String" -Force
        }

        # If cache is not empty, something is not right - investigate
        $CacheCount = ($CacheInfo.GetCacheElements() | Where-Object {$_.ContentId -notin $ApprovedPkgIDs -AND $_.LastReferenceTime -lt (Get-Date).AddDays(-1)}).count
        if ($CacheCount -gt "0") {
        
            Write-Output "Something is not right - there are still contents in the CM cache"

            New-ItemProperty -Path $RegistryPath -Name "CacheCleanUpStatus" -Value 1 -PropertyType "String" -Force

        }
    }
    
    # Not enough space in the CM cache AND nothing to clean up
    else {
        Write-Output "Not enough free space in the CM cache and nothing to cleanup. Used space is: $($CacheUsedSpace) and free space is: $($CacheInfo.FreeSize)"
    } 
}

# Else do nothing
else {
    Write-output "CM cache is all good - no cleanup needed. Free space is: $($CacheInfo.FreeSize)MB"
    New-ItemProperty -Path $RegistryPath -Name "CacheCleanUpStatus" -Value 0 -PropertyType "String" -Force
}
