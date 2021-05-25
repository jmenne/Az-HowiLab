<#
    .ClientConfig
    This configuration:
    * Ensures that group corp\ews is in local group Remote Desktop Users
    * Initialises and formats Data Disk with driveletter F

    jmenne 5/25/20218

#>

configuration ClientConfig
{
    param
   (
        [Parameter(Mandatory)]
        [String]$DomainName
    )

    Import-DscResource -Module PSDesiredStateConfiguration, xDisk, cDisk
    
# Apply configuration
    Node localhost
    {
        LocalConfigurationManager
        {
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }     
    }

    xWaitforDisk Disk2
    {
         DiskNumber = 2
         RetryIntervalSec =$RetryIntervalSec
         RetryCount = $RetryCount
    }

    cDiskNoRestart ADDataDisk
    {
        DiskNumber = 2
        DriveLetter = 'F'
    }

    Group RemoteDesktopUsers
    {
        GroupName = 'Remote Desktop Users'
        Ensure = 'Present'
        MembersToInclude = "corp\EWS"
    }
}