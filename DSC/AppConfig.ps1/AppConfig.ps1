<#
    .AppConfig
    This configuration:
    * Provisions IIS, .NET 4.5 and management tools.
    * Creates C:\Files, adds example.txt and shares directory with RWX perms for <domain>\User1.

    kvice 7/13/2018

    7/17/2018 - Updated modules to import
#>

configuration AppConfig
{
    param
   (
        [Parameter(Mandatory)]
        [String]$DomainName
    )

    Import-DscResource -Module PSDesiredStateConfiguration, xSmbShare, cNtfsAccessControl
    
# Apply configuration
    Node localhost
    {
        LocalConfigurationManager
        {
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }     

    # Install IIS role 
    WindowsFeature IIS 
    { 
        Ensure  = “Present” 
        Name    = “Web-Server” 
    } 
 
    # Install ASP .NET 4.5 role 
    WindowsFeature AspNet45 
    { 
        Ensure  = “Present” 
        Name    = “Web-Asp-Net45” 
    }
    
    # Install IIS management tools       
    WindowsFeature IISManagementTools {
 
        Name = 'Web-Mgmt-Tools'
        Ensure = 'Present'
        DependsOn = '[WindowsFeature]IIS'
    }

    # Create folder
    File NewFolder {
            Type = 'Directory'
            DestinationPath = 'C:\Files'
            Ensure = "Present"
        }

    # Create file
    File AddFile {
            DestinationPath = 'C:\Files\example.txt'
            Ensure = "Present"
            Contents = ''
        }

    # Share folder
    xSmbShare ShareFolder {
            Ensure = 'Present'
            Name   = 'Files'
            Path = 'C:\Files'
            FullAccess = 'Everyone'
            DependsOn = '[File]NewFolder'
        }

    # Set NTFS perms
    cNtfsPermissionEntry 'FilePermissionChange' {
            Ensure = 'Present'
            DependsOn = "[File]NewFolder"
            Principal = "$DomainName\User1"
            Path = 'C:\Files'
            AccessControlInformation = @(
                cNtfsAccessControlInformation
                {
                    AccessControlType = 'Allow'
                    FileSystemRights = 'FullControl'
                    Inheritance = 'ThisFolderSubfoldersAndFiles'
                    NoPropagateInherit = $false
                }
            )
        }
    }
}