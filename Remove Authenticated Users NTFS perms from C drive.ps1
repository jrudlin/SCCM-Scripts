function Remove-Inheritance($folderPath) {

    $isProtected = $true

    $preserveInheritance = $true

    

    $oFS = New-Object IO.DirectoryInfo($folderPath)

    $DirectorySecurity = $oFS.GetAccessControl([System.Security.AccessControl.AccessControlSections]::Access)

    

    $DirectorySecurity.SetAccessRuleProtection($isProtected, $preserveInheritance)

    

    $oFS.SetAccessControl($DirectorySecurity)

}




function Remove-NTFSPermissions($folderPath, $accountToRemove, $permissionToRemove) {

    $fileSystemRights = [System.Security.AccessControl.FileSystemRights]$permissionToRemove

    $inheritanceFlag = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit"

    $propagationFlag = [System.Security.AccessControl.PropagationFlags]"None"

    $accessControlType =[System.Security.AccessControl.AccessControlType]::Allow




    $ntAccount = New-Object System.Security.Principal.NTAccount($accountToRemove)

    if($ntAccount.IsValidTargetType([Security.Principal.SecurityIdentifier])) {

        $FileSystemAccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($ntAccount, $fileSystemRights, $inheritanceFlag, $propagationFlag, $accessControlType)

        

        $oFS = New-Object IO.DirectoryInfo($folderPath)

        $DirectorySecurity = $oFS.GetAccessControl([System.Security.AccessControl.AccessControlSections]::Access)

        

        $DirectorySecurity.RemoveAccessRuleAll($FileSystemAccessRule)

        

        $oFS.SetAccessControl($DirectorySecurity)

        

        return "Permissions " + $permissionToRemove + " Removed on " + $folderPath + " folder"

    }

    return 0

}




function Add-NTFSPermissions($folderPath, $accountToAdd, $permissionToAdd) {

    $fileSystemRights = [System.Security.AccessControl.FileSystemRights]$permissionToAdd

    $inheritanceFlag = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit"

    $propagationFlag = [System.Security.AccessControl.PropagationFlags]"None"

    $accessControlType =[System.Security.AccessControl.AccessControlType]::Allow




    $ntAccount = New-Object System.Security.Principal.NTAccount($accountToAdd)

    if($ntAccount.IsValidTargetType([Security.Principal.SecurityIdentifier])) {

        $FileSystemAccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($ntAccount, $fileSystemRights, $inheritanceFlag, $propagationFlag, $accessControlType)

        

        $oFS = New-Object IO.DirectoryInfo($folderPath)

        $DirectorySecurity = $oFS.GetAccessControl([System.Security.AccessControl.AccessControlSections]::Access)

        

        $DirectorySecurity.AddAccessRule($FileSystemAccessRule)

        

        $oFS.SetAccessControl($DirectorySecurity)

        

        return "Permissions " + $permissionToAdd + " Added on " + $folderPath + " folder for " + $accountToAdd

    }

    return 0

} 


$folder = "C:\"


##Remove Inheritance from Top Folder and Child Objects



    #Remove-Inheritance $folder

Remove-NTFSPermissions $folder "Authenticated Users" "Modify"

    #Remove-NTFSPermissions $folder "Authenticated Users" "Create folders / append data"

