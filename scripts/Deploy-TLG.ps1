# Provide parameter values
$resourceGroup = "Howilab-RG"
$location = "eastus"

$configName = "HowiLab-01" # The name of the deployment, i.e. BaseConfig01. Do not use spaces or special characters other than _ or -. Used to concatenate resource names for the deployment.
$domainName = "corp.howilab.local" # The FQDN of the new AD domain.
$serverOS = "Windows Server 2019" # The OS of server VMs in your deployment, i.e. Windows Server 2016 or Windows Server 2012 R2.
$clientOS = "Windows 10" # The OS of client VMs in your deployment, i.e. Windows Server 2016 or Windows 10.
$adminUserName = "student" # The name of the domain administrator account to create, i.e. globaladmin.
$adminPassword = "Pa55w.rd1234" # The administrator account password.
$vmSize = "Standard_D2s_v3" # Select a VM size for all server VMs in your deployment.
$dnsLabelPrefix = "howilab" # DNS label prefix for public IPs. Must be lowercase and match the regular expression: ^[a-z][a-z0-9-]{1,61}[a-z0-9]$.
$_artifactsLocation = "https://raw.githubusercontent.com/jmenne/AZ-Howilab/master" # Location of template artifacts.
$templateUri = "$_artifactsLocation/azuredeploy.json"

# Add parameters to array
$parameters = @{}
$parameters.Add("configName",$configName)
$parameters.Add("domainName",$domainName)
$parameters.Add("serverOS",$serverOS)
$parameters.Add("clientOS",$clientOS)
$parameters.Add("adminUserName",$adminUserName)
$parameters.Add("adminPassword",$adminPassword)
$parameters.Add("vmSize",$vmSize)
$parameters.Add("dnsLabelPrefix",$dnsLabelPrefix)
$parameters.Add("_artifactsLocation",$_artifactsLocation)

# Log in to Azure subscription
Connect-AzAccount

# Deploy resource group
New-AzResourceGroup -Name $resourceGroup -Location $location

# Deploy template
New-AzResourceGroupDeployment -Name $configName -ResourceGroupName $resourceGroup `
  -TemplateUri $templateUri -TemplateParameterObject $parameters -DeploymentDebugLogLevel All