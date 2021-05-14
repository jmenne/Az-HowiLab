<#
    .CreateADPDC
    This configuration creates a new domain with a new forest and a forest functional level of Server 2016,
    and adds User1 with membership in Domain Admins.

    kvice 7/11/2018
#>

configuration CreateADPDC
{
   param
   (
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    )

# Import DSC modules
    Import-DscResource -ModuleName PSDesiredStateConfiguration, xActiveDirectory, xDisk, xNetworking, cDisk

# Create domain admin creds
    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)

# Get network adapter
    $Interface=Get-NetAdapter|Where Name -Like "Ethernet*"|Select-Object -First 1
    $InterfaceAlias=$($Interface.Name)


# Apply configuration
    Node localhost
    {
        LocalConfigurationManager
        {
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }

        WindowsFeature DNS
            {
                Ensure = "Present"
                Name = "DNS"
            }

        WindowsFeature DnsTools
        {
            Ensure = "Present"
            Name = "RSAT-Dns-Server"
            DependsOn = "[WindowsFeature]DNS"
        }

	Script SetDNSForwarder
        {
            #
            # 
            #
            SetScript =
            {
                $dnsrunning = $false
                $triesleft = $Using:RetryCount
                While (-not $dnsrunning -and ($triesleft -gt 0))
                {
                    $triesleft--
                    try
                    {
                        $dnsrunning = (Get-Service -name dns).Status -eq "running"
                    } catch {
                        $dnsrunning = $false
                    }
                    if (-not $dnsrunning)
                    {
                        Write-Verbose -Verbose "Waiting $($Using:RetryIntervalSec) seconds for DNS service to start"
                        Start-Sleep -Seconds $Using:RetryIntervalSec
                    }
                }

                if (-not $dnsrunning)
                {
                    Write-Warning "DNS service is not running, cannot edit forwarder. Template deployment will fail."
                    # but continue anyway.
                }
                try {
                    Write-Verbose -Verbose "Getting list of DNS forwarders"
                    $forwarderlist = Get-DnsServerForwarder
                    if ($forwarderlist.IPAddress)
                    { 
                        Write-Verbose -Verbose "Removing forwarders"
                        Remove-DnsServerForwarder -IPAddress $forwarderlist.IPAddress -Force
                    } else {
                        Write-Verbose -Verbose "No forwarders found"
                    }
                } catch {
                    Write-Warning -Verbose "Exception running Remove-DNSServerForwarder: $_"
                }
                try {
                    Write-Verbose -Verbose "setting  forwarder to 8.8.8.8"
                    Set-DnsServerForwarder -IPAddress "8.8.8.8"
                } catch {
                    Write-Warning -Verbose "Exception running Set-DNSServerForwarder: $_"
                }
                 
            }
            GetScript =  { @{} }
            TestScript = { $false }
            DependsOn = "[WindowsFeature]DNSTools"
        }

	WindowsFeature RSAT_ADDS 
	{
		Ensure = 'Present'
		Name   = 'RSAT-ADDS'
	}

	WindowsFeature RSAT_AD_PowerShell 
	{
		Ensure = 'Present'
		Name   = 'RSAT-AD-PowerShell'
	}

	WindowsFeature RSAT_AD_Tools 
	{
		Ensure = 'Present'
		Name   = 'RSAT-AD-Tools'
	}

	WindowsFeature RSAT_Role_Tools 
	{
		Ensure = 'Present'
		Name   = 'RSAT-Role-Tools'
	}
 
	WindowsFeature RSAT_GPMC 
	{
		Ensure = 'Present'
		Name   = 'GPMC'
	}

        xDnsServerAddress DnsServerAddress
        {
            Address        = '127.0.0.1'
            InterfaceAlias = $InterfaceAlias
            AddressFamily  = 'IPv4'
	        DependsOn = "[WindowsFeature]DNS"
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

        WindowsFeature ADDSInstall
        {
            Ensure = "Present"
            Name = "AD-Domain-Services"
            DependsOn = "[cDiskNoRestart]ADDataDisk"
        }

        xADDomain FirstDS
        {
            DomainName = $DomainName
            DomainAdministratorCredential = $DomainCreds
            SafemodeAdministratorPassword = $DomainCreds
            DatabasePath = "F:\NTDS"
            LogPath = "F:\NTDS"
            SysvolPath = "F:\SYSVOL"
	        DependsOn="[WindowsFeature]ADDSInstall"
        }

        xWaitForADDomain DscForestWait
        {
            DomainName = $DomainName
            DomainUserCredential = $DomainCreds
            RetryCount = $RetryCount
            RetryIntervalSec = $RetryIntervalSec
            DependsOn = "[xADDomain]FirstDS"
        }

        xADUser FirstUser
        {
            DomainName = $DomainName
            UserName = "User1"
            Password = $DomainCreds
            Ensure = "Present"
            DependsOn = "[xWaitForADDomain]DscForestWait"
        }

	    Script AddUserToGroup
        {
            SetScript =
            {
                Import-Module ActiveDirectory
                try {
                    Add-ADGroupMember -Identity "Domain Admins" -Members "User1"
                    }
                catch {
                    Write-Warning -Verbose "Exception adding user to group: $_"
                }
            }
            GetScript =  { @{} }
            TestScript = { $false }
            DependsOn = "[xADUser]FirstUser"
        }
   }
}