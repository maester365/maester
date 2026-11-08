This inventory counts distinct DHCP server authorization entries stored in the `dhcpServers` attribute of `dhcpClass` objects under the AD NetServices configuration container. It reports registered DNS names and IPv4 addresses, including entries whose format cannot be parsed, rather than treating a registration container as one server.

A registration count does not identify an unauthorized server or prove that all DHCP servers are registered. The IPv4 value `255.0.0.1` can represent a DHCPv6 server registered without IPv4; it is not proof of an invalid server.

#### Remediation action

Compare each registration with the approved DHCP server inventory and investigate unexpected changes. Do not remove a registration based only on a count.

#### Related links

- [Microsoft MS-DHCPE: DHCP authorization attribute format](https://learn.microsoft.com/openspecs/windows_protocols/ms-dhcpe/52a47b66-fe0a-47e3-b4e0-92016f69c71f)

<!--- Results --->
%TestResult%
