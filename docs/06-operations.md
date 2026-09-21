# Operations, roadblocks and recovery

[Learning path](../README.md)

## What persists after shutdown?

The CUCM phone record is configuration stored in the cluster. Its live registration is temporary runtime state. When CIPC/Windows is off, the phone cannot remain actively registered indefinitely. A configured phone should still be discoverable in CUCM even when unregistered.

If it seems missing, clear Find filters and search the exact device name. Verify you opened the intended cluster and are not filtering by Registered/node/status. If the record really is absent, investigate administrative changes, provisioning behavior or database issues with logs; do not blame normal SIP failover for deletion.

Keep the VM adapter/device identity stable. Record the CIPC device name before changing adapters, cloning a VM or reinstalling. Do not clone a live endpoint identity/certificate/private key into another simultaneous phone.

## PUB/SUB behavior

The phone's CM group lists preferred call processors. The lab uses PUB then SUB; that is a lab design, not a universal production recommendation. Starting PUB's GUI does not guarantee CallManager/TFTP services are ready. Availability, connectivity and client fallback behavior affect which node becomes active.

A TFTP setting of .150 does not pin registration to PUB. Successful TLS connections to both nodes do not identify active/standby roles by themselves. A SIP REFER's meaning comes from its headers/context; seeing “SUB” somewhere in a trace is not enough to establish the cause of failover.

Test deliberately: record active node, capture, interrupt one intended service/node in a maintenance window, observe recovery, restore it, and inspect the resulting registration state. Do not repeatedly bounce both nodes while trying to explain one phone's behavior.

## Windows port inspection

Run the included [read-only PowerShell helper](../scripts/Inspect-CipcTransport.ps1), or inspect manually:

```powershell
Get-NetTCPConnection -ErrorAction SilentlyContinue |
  Where-Object {
    $_.RemoteAddress -in @('192.168.10.150','192.168.10.151') -and
    $_.RemotePort -in @(3804,5060,5061,6970)
  } |
  Select-Object LocalAddress,LocalPort,RemoteAddress,RemotePort,State,OwningProcess
```

For the earlier UDP conflict:

```powershell
Get-NetUDPEndpoint -LocalPort 5060 -ErrorAction SilentlyContinue |
  ForEach-Object {
    [pscustomobject]@{
      LocalAddress = $_.LocalAddress
      LocalPort = $_.LocalPort
      PID = $_.OwningProcess
      Process = (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName
    }
  }
```

These commands inspect sockets; they do not reserve or force a port. In the earlier Windows 10 exercise, MicroSIP owned UDP 5060. Exiting it allowed CIPC (`communicatork9`) to bind. Empty UDP output is normal when no UDP listener exists; it is also not a fault when this phone is using outbound TCP/TLS instead.

For TLS, do not force local TCP 5061 to mimic the server's listening port. Do not disable Windows Firewall globally or use TCP portproxy to solve a UDP application conflict. If needed, disable a competing softphone's startup entry through Windows settings; uninstalling is not required for the demonstrated fix.

`Test-NetConnection 192.168.10.150 -Port 5061` tests TCP reachability only. It neither checks certificate trust nor proves SIP registration. TCP 3804 may be used only during enrollment, so no persistent CAPF connection is expected after completion.

## Roadblocks from the session

| Roadblock | Lesson / corrective action |
|---|---|
| CUCM browser security-protocol violation | Use a fresh authenticated page/session and retry; stale concurrent windows/back navigation can invalidate an admin operation. Not a SIP TLS alert |
| CTL file initially absent | Complete mixed-mode preparation and verify CTL on both nodes |
| Services Activated but not Started | Inspect runtime service state; CAPF must run for this workflow |
| Enhanced Out of Compliance | Did not by itself explain this trace; explicit SIP transport warning was stronger evidence |
| Authenticated selected while LSC absent | Changing security mode does not create the certificate |
| Secure config downloaded yet plain TCP used | Verify endpoint enrollment and actual wire transport, not just saved UI fields |
| Optional HTTP file 404 | Separate optional directory/dial-rule resources from required phone configuration |
| CAPF alert/reset after protected exchange | Do not infer wrong string without decryptable alert/status/log evidence |
| Manual DN confused with auto-reg range | 2103 is a permanent manual assignment, independent of temporary auto-reg pool |
| Self-Service ID equals DN | Equality is a convention, not the device-discovery mechanism |
| 2099 shown on button 3 | Template speed-dial position, not a third registered DN |
| End-user CTI permission proposed as fix | CTI application authorization does not fix missing LSC or TLS mismatch |

## Certificate renewal and recovery

Before expiry, schedule a controlled LSC Install/Upgrade with a fresh private enrollment string and a valid operation window. Verify phone time, CAPF status, new certificate state and a subsequent secure connection. Replacing a certificate is not complete merely because the CUCM form was saved.

Before changing cluster certificates/trust or TLS policies, record current values and follow release-specific Cisco procedures, including affected endpoints and required service restarts. Do not delete CTL/ITL trust files or revert cluster security mode as a first response to a single-phone fault.

For recovery, restore the recorded intended device settings and validate each layer again. A deliberate temporary nonsecure test changes the security goal and must be recorded as such; it is not evidence of TLS success. Keep a DRS backup and protect any private capture/log bundle.

## Acceptance worksheet

- [ ] Correct phone identity and DN/partition recorded locally.
- [ ] PUB/SUB DNS and clocks verified.
- [ ] Mixed mode 1 and CTL verification confirmed.
- [ ] Correct final security profile assigned to this phone.
- [ ] LSC Installed; CAPF operation completed.
- [ ] Client certificate identity and issuer verified locally.
- [ ] Actual negotiated TLS version/cipher recorded.
- [ ] CUCM Registered; active node recorded.
- [ ] Restart/relaunch recovery tested once.
- [ ] Call routing tested separately from registration.
- [ ] SRTP tested separately if encrypted media is an objective.
- [ ] No real certificate identifiers, authentication strings, keys or raw captures added to public Git.
