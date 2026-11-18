Published printer inventory.

Inventory of published printQueue objects and their name, server, location and description. The count does not indicate printer access or security.

Published printer names and locations can reveal infrastructure details; printing systems may also require access control, driver maintenance and sensitive-document handling. This directory inventory does not inspect drivers, print jobs, ACLs or network exposure.

#### Control Type

**Operational**

#### Security Recommendation

1. Review the objects in **Active Directory Sites and Services** or **Active Directory Users and Computers**, as appropriate.
2. Review the reported objects with the directory and network owners; update any outdated configuration only after checking intended topology and dependencies.

Publish only printers that need to be discoverable and review location/description fields for sensitive details. Independently verify printer ACLs, driver updates and secure-release practices before making claims about printing security.

#### How the Test Works

Inventories published `printQueue` directory objects with their names, servers, locations and descriptions. It does not test whether any printer is accessible or correctly secured.



#### Related links

* [Microsoft Learn: Active Directory design guidance](https://learn.microsoft.com/windows-server/administration/windows-commands/pubprn)

<!--- Results --->
%TestResult%
