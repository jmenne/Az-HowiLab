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
    $Interface=Get-NetAdapter|Where-Object Name -Like "Ethernet*"|Select-Object -First 1
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
                    Write-Verbose -Verbose "setting  forwarder to 1.1.1.1"
                    Set-DnsServerForwarder -IPAddress "1.1.1.1"
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

        xADOrganizationalUnit HowiLabOU
                {
                    Name = 'HowiLab'
                    Path = "DC=corp,DC=howilab,dc=internal"
                    ProtectedFromAccidentalDeletion = $true
                    Ensure = 'Present'
                    DependsOn = "[xADDomain]FirstDS" 
                }

                xADOrganizationalUnit ClientsOU
                {
                    Name = 'Clients'
                    Path = "OU=howilab,DC=corp,DC=howilab,dc=internal"
                    ProtectedFromAccidentalDeletion = $true
                    Ensure = 'Present'
                    DependsOn = "[xADOrganizationalUnit]HowiLabOU" 
                }

                xADOrganizationalUnit ServersOU
                {
                    Name = 'Servers'
                    Path = "OU=howilab,DC=corp,DC=howilab,dc=internal"
                    ProtectedFromAccidentalDeletion = $true
                    Ensure = 'Present'
                    DependsOn = "[xADOrganizationalUnit]HowiLabOU" 
                }

                 xADOrganizationalUnit GroupsOU
                {
                    Name = 'Groups'
                    Path = "OU=howilab,DC=corp,DC=howilab,dc=internal"
                    ProtectedFromAccidentalDeletion = $true
                    Ensure = 'Present'
                    DependsOn = "[xADOrganizationalUnit]HowiLabOU" 
                }
                
                xADOrganizationalUnit UsersOU
                {
                    Name = 'Users'
                    Path = "OU=howilab,DC=corp,DC=howilab,dc=internal"
                    ProtectedFromAccidentalDeletion = $true
                    Ensure = 'Present'
                    DependsOn = "[xADOrganizationalUnit]HowiLabOU" 
                }

                xADUser Anna
                {
                    DomainName = $DomainName
                    DomainAdministratorCredential = $domainCred
                    CommonName = "Anna Bolika"
                    UserName = "Anna"
                    GivenName = "Anna"
                    SurName = "Bolika"
                    Displayname = "Anna Bolika"
                    UserPrincipalName = "Anna@corp.howilab.internal"
                    Company = "HowiLab"
                    Department = "Forschung"
                    Jobtitle ="Leitung"
                    Password = $DomainCreds
                    Ensure = "Present"
                    DependsOn = "[xADOrganizationalUnit]UsersOU"
                    Path = "OU=Users,OU=HowiLab,DC=corp,DC=howilab,dc=internal"
                    PasswordNeverExpires = $true
                }

                xADUser Ellen
                {
                    DomainName = $DomainName
                    DomainAdministratorCredential = $domainCred
                    CommonName = "Ellen Bogen"
                    UserName = "Ellen"
                    GivenName = "Ellen"
                    SurName = "Bogen"
                    Displayname = "Ellen Bogen"
                    UserPrincipalName = "Ellen@corp.howilab.internal"
                    Company = "HowiLab"
                    Department = "IT"
                    Jobtitle = "Leitung"
                    Password = $DomainCreds
                    Ensure = "Present"
                    DependsOn = "[xADOrganizationalUnit]UsersOU"
                    Path = "OU=Users,OU=HowiLab,DC=corp,DC=howilab,dc=internal"
                    PasswordNeverExpires = $true
                }

                xADUser Ansgar
                {
                    DomainName = $DomainName
                    DomainAdministratorCredential = $domainCred
                    CommonName = "Ansgar Ragentor"
                    UserName = "Ansgar"
                    GivenName = "Ansgar"
                    SurName = "Ragentor"
                    Displayname = "Ansgar Ragentor"
                    UserPrincipalName = "Ansgar@corp.howilab.internal"
                    Company = "HowiLab"
                    Department = "Forschung"
                    Jobtitle = "Mitarbeiter"
                    Password = $DomainCreds
                    Ensure = "Present"
                    DependsOn = "[xADOrganizationalUnit]UsersOU"
                    Path = "OU=Users,OU=HowiLab,DC=corp,DC=howilab,dc=internal"
                    PasswordNeverExpires = $true
                }

                xADUser Erkan
                {
                    DomainName = $DomainName
                    DomainAdministratorCredential = $domainCred
                    CommonName = "Erkan Nichtanders"
                    UserName = "Erkan"
                    GivenName = "Erkan"
                    SurName = "Nichtanders"
                    Displayname = "Erkan Nichtanders"
                    UserPrincipalName = "Erkan@corp.howilab.internal"
                    Company = "HowiLab"
                    Department = "IT"
                    Jobtitle = "Mitarbeiter"
                    Password = $DomainCreds
                    Ensure = "Present"
                    DependsOn = "[xADOrganizationalUnit]UsersOU"
                    Path = "OU=Users,OU=HowiLab,DC=corp,DC=howilab,dc=internal"
                    PasswordNeverExpires = $true
                 }

                xADUser Ben
                {
                    DomainName = $DomainName
                    DomainAdministratorCredential = $domainCred
                    CommonName = "Ben Utzer"
                    UserName = "Ben"
                    GivenName = "Ben"
                    SurName = "Utzer"
                    Displayname = "Ben Utzer"
                    UserPrincipalName = "Ben@corp.howilab.internal"
                    Company = "HowiLab"
                    Department = "HelpDesk"
                    Jobtitle = "Mitarbeiter"
                    Password = $DomainCreds
                    Ensure = "Present"
                    DependsOn = "[xADOrganizationalUnit]UsersOU"
                    Path = "OU=Users,OU=HowiLab,DC=corp,DC=howilab,dc=internal"
                    PasswordNeverExpires = $true
                 }

                xADUser Lasse
                {
                    DomainName = $DomainName
                    DomainAdministratorCredential = $domainCred
                    CommonName = "Lasse Reden"
                    UserName = "Lasse"
                    GivenName = "Lasse"
                    SurName = "Reden"
                    Displayname = "Lasse Reden"
                    UserPrincipalName = "Lasse@corp.howilab.internal"
                    Company = "HowiLab"
                    Department = "HelpDesk"
                    Jobtitle = "Leitung"
                    Password = $DomainCreds
                    Ensure = "Present"
                    DependsOn = "[xADOrganizationalUnit]UsersOU"
                    Path = "OU=Users,OU=HowiLab,DC=corp,DC=howilab,dc=internal"
                    PasswordNeverExpires = $true
                 }

                xADUser Claudia
                {
                    DomainName = $DomainName
                    DomainAdministratorCredential = $domainCred
                    CommonName = "Claudia Manten"
                    UserName = "Claudia"
                    GivenName = "Claudia"
                    SurName = "Reden"
                    Displayname = "Claudia Manten"
                    UserPrincipalName = "Claudia@corp.howilab.internal"
                    Company = "HowiLab"
                    Department = "Vertrieb"
                    Jobtitle = "Leitung"
                    Password = $DomainCreds
                    Ensure = "Present"
                    DependsOn = "[xADOrganizationalUnit]UsersOU"
                    Path = "OU=Users,OU=HowiLab,DC=corp,DC=howilab,dc=internal"
                    PasswordNeverExpires = $true
                 }

                xADUser Theo
                {
                    DomainName = $DomainName
                    DomainAdministratorCredential = $domainCred
                    CommonName = "Theo Retisch"
                    UserName = "Theo"
                    GivenName = "Theo"
                    SurName = "Retisch"
                    Displayname = "Theo Retisch"
                    UserPrincipalName = "Theo@corp.howilab.internal"
                    Company = "HowiLab"
                    Department = "Vertrieb"
                    Jobtitle = "Mitarbeiter"
                    Password = $DomainCreds
                    Ensure = "Present"
                    DependsOn = "[xADOrganizationalUnit]UsersOU"
                    Path = "OU=Users,OU=HowiLab,DC=corp,DC=howilab,dc=internal"
                    PasswordNeverExpires = $true
                 }   

                xADUser Ed
                {
                    DomainName = $DomainName
                    DomainAdministratorCredential = $domainCred
                    CommonName = "Ed Was"
                    UserName = "Ed"
                    GivenName = "Ed"
                    SurName = "Was"
                    Displayname = "Ed Was"
                    UserPrincipalName = "Ed@corp.howilab.internal"
                    Company = "HowiLab"
                    Department = "Buchhaltung"
                    Jobtitle = "Mitarbeiter"
                    Password = $DomainCreds
                    Ensure = "Present"
                    DependsOn = "[xADOrganizationalUnit]UsersOU"
                    Path = "OU=Users,OU=HowiLab,DC=corp,DC=howilab,dc=internal"
                    PasswordNeverExpires = $true
                 }

                xADUser Gesa
                {
                    DomainName = $DomainName
                    DomainAdministratorCredential = $domainCred
                    CommonName = "Gesa Melte-Werke"
                    UserName = "Gesa"
                    GivenName = "Gesa"
                    SurName = "Melte-Werke"
                    Displayname = "Gesa Melte-Werke"
                    UserPrincipalName = "Gesa@corp.howilab.internal"
                    Company = "HowiLab"
                    Department = "Buchhaltung"
                    Jobtitle = "Leitung"
                    Password = $DomainCreds
                    Ensure = "Present"
                    DependsOn = "[xADOrganizationalUnit]UsersOU"
                    Path = "OU=Users,OU=HowiLab,DC=corp,DC=howilab,dc=internal"
                    PasswordNeverExpires = $true
                 }

                xADUser Heinz
                {
                    DomainName = $DomainName
                    DomainAdministratorCredential = $domainCred
                    CommonName = "Heinz Ellmann"
                    UserName = "Heinz"
                    GivenName = "Heinz"
                    SurName = "Ellmann"
                    Displayname = "Heinz Ellmann"
                    UserPrincipalName = "Heinz@corp.howilab.internal"
                    Company = "HowiLab"
                    Department = "Management"
                    Jobtitle = "Mitarbeiter"
                    Password = $DomainCreds
                    Ensure = "Present"
                    DependsOn = "[xADOrganizationalUnit]UsersOU"
                    Path = "OU=Users,OU=HowiLab,DC=corp,DC=howilab,dc=internal"
                    PasswordNeverExpires = $true
                 }

                xADUser Jack
                {
                    DomainName = $DomainName
                    DomainAdministratorCredential = $domainCred
                    CommonName = "Jack Pott"
                    UserName = "Jack"
                    GivenName = "Jack"
                    SurName = "Pott"
                    Displayname = "Jack Pott"
                    UserPrincipalName = "Jack@corp.howilab.internal"
                    Company = "HowiLab"
                    Department = "Management"
                    Jobtitle = "Leitung"
                    Password = $DomainCreds
                    Ensure = "Present"
                    DependsOn = "[xADOrganizationalUnit]UsersOU"
                    Path = "OU=Users,OU=HowiLab,DC=corp,DC=howilab,dc=internal"
                    PasswordNeverExpires = $true
                 }

                xADGroup 'Forschung'
                {
                  Ensure       = 'Present'
                  GroupName    = 'Forschung'
                  Path         = "OU=Groups,OU=HowiLab,DC=corp,DC=howilab,dc=internal"
                  GroupScope   = 'Global'
                  Category     = 'Security'
                  Description  = "Mitarbeiter der Forschungsabteilung"
                  MembersToInclude = "Anna","Ansgar"
                  DependsOn    = "[xADOrganizationalUnit]GroupsOU"
                }
                
                xADGroup 'IT'
                {
                  Ensure       = 'Present'
                  GroupName    = 'IT'
                  Path         = "OU=Groups,OU=HowiLab,DC=corp,DC=howilab,dc=internal"
                  GroupScope   = 'Global'
                  Category     = 'Security'
                  Description  = "Mitarbeiter der IT-Abteilung"
                  MembersToInclude = "Ellen","Erkan"
                  DependsOn    = "[xADOrganizationalUnit]GroupsOU"
                }

                xADGroup 'HelpDesk'
                {
                  Ensure       = 'Present'
                  GroupName    = 'HelpDesk'
                  Path         = "OU=Groups,OU=HowiLab,DC=corp,DC=howilab,dc=internal"
                  GroupScope   = 'Global'
                  Category     = 'Security'
                  Description  = "Mitarbeiter der IT-Abteilung"
                  MembersToInclude = "Lasse","Ben"
                  DependsOn    = "[xADOrganizationalUnit]GroupsOU"
                }

                xADGroup 'Management'
                {
                  Ensure       = 'Present'
                  GroupName    = 'Management'
                  Path         = "OU=Groups,OU=HowiLab,DC=corp,DC=howilab,dc=internal"
                  GroupScope   = 'Global'
                  Category     = 'Security'
                  Description  = "Mitarbeiter der IT-Abteilung"
                  MembersToInclude = "Heinz","Jack"
                  DependsOn    = "[xADOrganizationalUnit]GroupsOU"
                }

                xADGroup 'Vertrieb'
                {
                  Ensure       = 'Present'
                  GroupName    = 'Vertrieb'
                  Path         = "OU=Groups,OU=HowiLab,DC=corp,DC=howilab,dc=internal"
                  GroupScope   = 'Global'
                  Category     = 'Security'
                  Description  = "Mitarbeiter der IT-Abteilung"
                  MembersToInclude = "Claudia","Theo"
                  DependsOn    = "[xADOrganizationalUnit]GroupsOU"
                }

                xADGroup 'Buchhaltung'
                {
                  Ensure       = 'Present'
                  GroupName    = 'Buchhaltung'
                  Path         = "OU=Groups,OU=HowiLab,DC=corp,DC=howilab,dc=internal"
                  GroupScope   = 'Global'
                  Category     = 'Security'
                  Description  = "Mitarbeiter der IT-Abteilung"
                  MembersToInclude = "Ed","Gesa"
                  DependsOn    = "[xADOrganizationalUnit]GroupsOU"
                }

                xADGroup 'EWS'
                {
                  Ensure       = 'Present'
                  GroupName    = 'EWS'
                  Path         = "OU=Groups,OU=HowiLab,DC=corp,DC=howilab,dc=internal"
                  GroupScope   = 'Global'
                  Category     = 'Security'
                  Description  = "Alle User sollen sich per RDP am Client anmelden können"
                  MembersToInclude = "Ed","Gesa","Claudia","Theo","Heinz","Jack","Lasse","Ben","Ellen","Erkan","Anna","Ansgar"
                  DependsOn    = "[xADOrganizationalUnit]GroupsOU"
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