# Exchange Server SE Edge Transport as the priority front door

An optional variant of the design: Exchange Server SE replaces Postfix as the SMTP
front door on the priority lane. The Azure tier behind it is unchanged.

This was built and tested end to end. The scripts below are the ones that worked,
including fixes for the three things that stop the install outright.

## Why Exchange needs its own server per lane

Postfix routes by **sender**, which is how one Postfix instance can serve both lanes.
Exchange cannot: send connector selection is by **recipient** address space and cost,
never by sender. `RouteMessageOutboundConnector` does route by sender but is Exchange
Online only — the cmdlets do not exist in Exchange Server.

So splitting traffic by sender needs one Edge Transport server per lane. That is not
a workaround so much as a match for how most organisations already work, since lanes
are usually separated by relay hostname at the application tier anyway.

## Build order

| # | Script | Runs on | Notes |
|---|---|---|---|
| 00 | `00-provision-vm.ps1` | your machine | Subnet, NAT association, VM, NSG rule. Needs `EXCH_ADMIN_PASSWORD`. |
| 06 | `06-vcredist.ps1` | the VM | **Run before setup.** Visual C++ 2012 is a hard prerequisite the ISO does not carry. |
| 01 | `01-prereq.ps1` | the VM | AD LDS, DNS suffix, paging file, egress check. Reboot after. |
| 02 | `02-download-iso.ps1` | the VM | Downloads the Exchange SE ISO (about 6 GB). |
| 03 | `03-install-exchange.ps1` | the VM | Setup via a scheduled task. **Must not run as SYSTEM** — see below. |
| 03a | `03a-clear-setup-watermark.ps1` | the VM | Only if a setup attempt failed. Clears the retry blocker. |
| 04 | `04-status.ps1` | the VM | Poll during the roughly 40 minute install. |
| 11 | `11-receive.ps1` | the VM | Restricts the receive connector, **then** grants relay. |
| 11a | `11a-send-connector.ps1` | the VM | The connector to ACS. Needs `ACS_SMTP_USER` / `ACS_SMTP_PASSWORD`. |
| 08 | `08-verify.ps1` | the VM | Services, version, role, edition. |
| 12 | `12-track.ps1` | the VM | Queues and message tracking. |

The remaining numbered scripts (05, 07, 09, 10, 13–19) are read-only diagnostics and
recovery helpers used while debugging. They are safe to run at any time.

## Three things that will stop you

**Setup cannot run as SYSTEM.** Edge Transport creates an AD LDS instance during
setup, and AD LDS needs a real user account as its administrator. `az vm run-command`
executes as SYSTEM, so setup fails with *"The value entered for Administrator is not a
valid user account."* Use the scheduled task in `03-install-exchange.ps1`, or RDP in
and run `Setup.exe` interactively.

**A failed attempt blocks every retry.** It leaves a watermark, and subsequent runs
abort in seconds with *"A Setup failure previously occurred."* Re-running setup does
not clear it. Run `03a-clear-setup-watermark.ps1` first.

**Visual C++ 2012 Redistributable is required and is not on the ISO.** Setup fails its
prerequisite check without it. Install it before anything else.

## Two things that look like failures but are not

**The setup log is full of "The LDAP server is unavailable."** Harmless. Edge uses
local AD LDS and never contacts a domain controller — these appear even on a
completely successful install. Judge success by setup exit code 0 and by the eight
`MSExchange*` services running.

**`Get-MessageTrackingLog` returns nothing.** On an Edge server you must pass
`-Server <name>`. The outbound event is also called `SENDEXTERNAL`, not `SEND`, so
filtering on `SEND` returns an empty result even when mail was delivered perfectly.

## Do not build an open relay

Setup creates a receive connector bound to `0.0.0.0:25` accepting from
`0.0.0.0-255.255.255.255`. `11-receive.ps1` narrows `RemoteIPRanges` to the
application subnet **before** granting `ms-Exch-SMTP-Accept-Any-Recipient`. Keep that
order, and do not widen the range — an open relay on a public cloud is found and
abused within hours.

## Renaming the server afterwards

You cannot. The Edge server's object in AD LDS is keyed to the machine FQDN, so
changing the primary DNS suffix after installation orphans it and
`MSExchangeTransport` refuses to start with *"Microsoft Exchange couldn't read the
Receive connector configuration."* Reverting the suffix and rebooting recovers it.

Set the DNS suffix you want **before** installing Exchange. The connector `Fqdn` can
be changed safely at any time, but it only affects the SMTP HELO and does not change
the `Message-ID`, which is generated from the machine name.

## Licensing

Installing without a product key yields **Trial Edition**, which Microsoft identifies
as suitable for labs and demos. Confirm with `(Get-ExchangeServer).Edition` returning
`StandardEvaluation`.

Do not read that as a licensing position for a permanent relay-only deployment.
Microsoft publishes no CAL exemption for relay-only use, and the multiplexing rules in
the Product Terms cut against assuming one. That question needs a licensing specialist.
