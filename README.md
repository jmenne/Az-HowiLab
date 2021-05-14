# HowiLab

---

## Schulungs-, Demo-, Testumgebung in Azure

Du benötigst hin und wieder eine Testumgebung bestehend aus einem DC, einem Client und einem Server zu Schulungszwecken, selbstlernen oder experimentieren? Das ganze in Azure?

Microsoft hat dazu Test Lab Guides veröffentlicht. [Simulated Enterprise Base Configuration](https://docs.microsoft.com/en-us/microsoft-365/enterprise/simulated-ent-base-configuration-microsoft-365-enterprise). Auch ein [Github Repository](https://github.com/maxskunkworks/TLG/tree/master/tlg-base-config_3-vm.m365-ems) mit ARM Templates ist vorhanden, welches aber nicht mehr weiterentwickelt wird. Diese Templates dienen mir als Ausgangspunkt für meine persönliche Testumgebung.

### VMs

Ich wähle als Betriebssystem für die Server den Windows Server 2019 Datacenter und den Windows 10 Client 20h2. Die Machine Size für alle ist "Standard_D2s_v3" mit 2 CPU Kernen und 8 GB RAM. Es werden Managed Disks für die OS-Disks und Data-Disks benutzt, so dass man keinen Storage Account braucht.
Alle Maschinen bekommen eine Netzwerkkarte, eine öffentliche IP und sind per RDP erreichbar.
Die Konfiguration erfolgt durch die Desired State Configuration (DSC) Erweiterung.

- **DC01** ist der Domänencontroller der Domäne *corp.howilab.local*.
  - IP-Adresse: 10.0.0.10 (statisch)
  - Der Domänen-Benutzer *user1* wird erstellt und der Gruppe Domänen-Admins hinzugefügt.
- **App01** ist ein Mitgliedsserver der Domäne
  - IP-Adresse: 10.0.0.21 (statisch)
  - IIS und .NET 4.5 wird installiert
  - Der Ordner c:\\files wird als "\\\\App01\files" freigegeben. *user1* bekommt Vollzugriff.
- **Client01** ist ebenfalls Domänenmiglied.
  - IP-Adresse: 10.0.0.50 (statisch)
  