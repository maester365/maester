Inventories site links under the Active Directory IP and SMTP inter-site transport containers.

Reports each link's transport, cost, replication interval, connected sites and distinguished name. Transport is determined from the parent container, not by whether cost or interval is populated. A cost of zero remains a reported value; no transport or security baseline is asserted.

#### Remediation action

Compare site links and transports with the approved site topology. Investigate unexpected links with directory replication administrators before modifying production replication routes.

#### Related links

* [Active Directory replication concepts](https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/replication/active-directory-replication-concepts)

<!--- Results --->
%TestResult%
