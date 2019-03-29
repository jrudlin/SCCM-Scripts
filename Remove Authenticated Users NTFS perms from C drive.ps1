    function Remove-NTFSPermissions{
 
        [CmdletBinding()]
        Param(
            [parameter(Mandatory=$True)]
            [String]$folderPath,
            [parameter(Mandatory=$True)]
            [String]$accountToRemove,
            [parameter(Mandatory=$True)]
            [String]$permissionToRemove
        )
        
        $fileSystemRights = [System.Security.AccessControl.FileSystemRights]$permissionToRemove
     
        $inheritanceFlag = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit"
     
        $propagationFlag = [System.Security.AccessControl.PropagationFlags]"None"
     
        $accessControlType =[System.Security.AccessControl.AccessControlType]::Allow
     
     
     
     
        $ntAccount = New-Object System.Security.Principal.NTAccount($accountToRemove)
     
        if($ntAccount.IsValidTargetType([Security.Principal.SecurityIdentifier])) {
     
            Try {
                $FileSystemAccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($ntAccount, $fileSystemRights, $inheritanceFlag, $propagationFlag, $accessControlType)          
                $oFS = New-Object IO.DirectoryInfo($folderPath)
                $DirectorySecurity = $oFS.GetAccessControl([System.Security.AccessControl.AccessControlSections]::Access)         
                $DirectorySecurity.RemoveAccessRuleAll($FileSystemAccessRule)
                $oFS.SetAccessControl($DirectorySecurity)

                return "Permissions " + $permissionToRemove + " Removed on " + $folderPath + " folder"
                
            } Catch {
                return "Error, could not set permissions for [$accountToRemove] $_"
            }
        }
          
    }


$Folder = "C:\"
Remove-NTFSPermissions -folderPath $folder -accountToRemove "Authenticated Users" -permissionToRemove "Modify"
#Remove-NTFSPermissions $folder Authenticated Users Create folders  append data
