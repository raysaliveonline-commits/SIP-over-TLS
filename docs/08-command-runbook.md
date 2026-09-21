# Command runbook: current state → action → result → next step

[Start](../README.md) · [Why CAPF and each port exist](09-capf-trust-and-ports.md)

Run CUCM commands in the **CUCM platform CLI** using the platform administrator account, normally over SSH. Run PowerShell on Windows. Do not paste CUCM CLI commands into Windows PowerShell. Read commands below do not change state; commands explicitly marked CHANGE do.

This runbook is for a legacy CIPC **SIP/TLS endpoint**. Mixed mode is unnecessary for a SIP/UDP-only exercise. The completed cluster is already mode 1: a student continuing this exact lab should verify and proceed, not enable mixed mode again.

## Checkpoint 1 — determine the installed version and current security state

On PUB, then record relevant node state on SUB:

```text
show version active
show ctl
show tls min-version
utils service list
```

| Command / GUI check | Why run it | Interpret the result | What to do next |
|---|---|---|---|
| show version active | Establish exact running CUCM release/build | Record actual output; don't use the installer folder as CUCM version proof | Use that release's CLI/security documentation |
| show ctl | Check whether a CTL file exists and verifies | Original first result: file not found; later: verified successfully | If absent + mode 0, prepare mixed mode; if valid + mode 1, skip the change |
| show tls min-version | Read TLS minimum allowed by this CUCM configuration | Lab retained 1.0; successful SIP trace negotiated 1.0 | Compare client offerings before changing policy; don't automatically lower it |
| utils service list | Distinguish actual service state from activation checkbox | Find CallManager, CTIManager, TFTP and CAPF states on intended nodes | Fix a relevant stopped service before interpreting absent traffic |
| System → Enterprise Parameters → Security Parameters | Read Cluster Security Mode | 0 = nonsecure; 1 = mixed | Record alongside show ctl; neither alone proves endpoint registration |
| License page | Record registration/authorization/export capability for the release | Lab showed registered but Enhanced Out of Compliance | Do not label licensing the root cause without a license-related failure; honor platform prerequisites |

**Stop condition:** contradictory state (e.g. mode 1 but CTL missing/unverified on a relevant node), an unknown release dependency, or a required stopped service. Investigate it rather than issuing mode changes repeatedly.

**Safe return:** these are read-only checks, so no rollback is needed.

## Checkpoint 2 — prepare services and preserve the working state

In **Cisco Unified Serviceability → Tools → Service Activation**, select the intended server. In **Tools → Control Center – Feature Services**, select that server again and verify runtime state.

| Node | Required for this procedure |
|---|---|
| PUB | CallManager, TFTP, CAPF Started; CTIManager if used by the cluster/app workflow |
| SUB | CallManager Started; CTIManager if used; TFTP only if actually configured as a second configuration server |

The observed CAPF service name is **Cisco Certificate Authority Proxy Function**. Cisco Certificate Enrollment Service is a different service; its Not Running state did not prevent this CAPF-issued LSC success. Not every activated feature service is a TLS dependency.

Before a **new** mixed-mode change, record phone profiles, current mode, services, trust/certificate state and a supported DRS backup. Schedule the service restarts. The operator skipped backup in the original session; the guide preserves that fact without making it a recommended step.

**Expected/next:** prerequisites are ready; change mixed mode once only if still mode 0.

## Checkpoint 3 — when and why to enable mixed mode

**When:** after version/service/impact checks, before expecting this manually prepared CIPC to authenticate and register securely. It can be configured before CIPC's first launch. Creating a TLS phone profile alone does not establish cluster secure-phone capability.

**Why:** mixed mode prepares the cluster for secure-phone operation while retaining support for nonsecure devices. CTL distributes trusted cluster security identities/roles. CAPF provides a separate endpoint certificate. A mixed cluster still needs a per-phone security profile and certificate enrollment; it does not convert every phone automatically.

**CHANGE — run on PUB, once:**

```text
utils ctl set-cluster mixed-mode
```

Read and retain the command's actual result. The session displayed a warning that auto-registration was enabled and instructions to restart CallManager and CTIManager. PC3 was manually precreated, so no temporary auto-registration DN was needed. Do not depend on legacy auto-registration for a secure phone or change number ranges to fix a certificate failure.

For required restarts, use **Serviceability → Tools → Control Center – Feature Services → select PUB → select the service → Restart**. Complete one node, verify service return, then do SUB. If using CLI, the relevant commands are:

```text
utils service restart Cisco CallManager
utils service restart Cisco CTIManager
```

These interrupt the selected services. Execute only the restarts required by your release/change result, not every time you run show ctl. Do not substitute `utils system restart` for a service restart.

**Expected:** services return to Started; mode changes to 1; CTL verifies. **Next:** checkpoint 4 before launching CIPC.

**Failure/rollback:** stop if the command fails or services do not recover; retain logs/output. Do not casually run the reverse cluster-mode command as a one-phone fix. A cluster rollback must restore the planned security/trust state for all affected endpoints, with release-specific guidance and the recorded backup.

## Checkpoint 4 — prove cluster readiness on both nodes

On PUB and SUB:

```text
show ctl
utils service list
```

In **System → Enterprise Parameters**, verify **Cluster Security Mode = 1**.

| Observation | Meaning | Next action |
|---|---|---|
| CTL file verified successfully on PUB and SUB | Server-side CTL verification passed | Continue to phone/CAPF configuration |
| File not found after intended change | Missing/distribution/generation issue remains | Check change result, node/service state and logs; don't assume ready |
| CTL verifies but CIPC shows LSC Not Installed | Cluster trust exists, phone identity does not | Enroll LSC; this is not contradictory |
| CTL verifies but no 5061 handshake | Check phone identity/config download, LSC and network | Follow packet sequence; don't regenerate CTL blindly |

The displayed CTL checksum is evidence for local comparison, not an authentication key. Never type it into the LSC authentication-string box. Server-side show ctl does not prove that the phone downloaded/accepted the latest CTL.

## Checkpoint 5 — make the phone configuration concrete

Follow [deployment steps 6–9](01-deployment.md):

1. Create compatible CIPC SIP security profile, final Encrypted/TLS/5061, CAPF By Authentication String and RSA 2048.
2. Create/open the matching device record with CIPC closed; apply DP-HQ-INDIA, SIP profile, security profile, owner ONPREM.
3. Create Line 1 2103/PT-HQ-INTERNAL; Display ONPREM; label 2103 - TLS; leave Line 2 empty.
4. Verify user Controlled Device and Primary Extension separately from owner and Self-Service ID.
5. Under phone CAPF Information, arm Install/Upgrade with a future operation deadline; generate a private authentication string; Save/Apply Config.

**Expected:** saved phone identity/configuration is coherent. **Next:** check network ports and launch with capture running. There is no claim the phone should already be registered while closed or before LSC enrollment.

## Checkpoint 6 — Windows readiness and reachability

On PC3:

```powershell
hostname
Get-NetIPConfiguration
Get-NetAdapter | Select-Object Name, Status, MacAddress
Resolve-DnsName cucm-pub.ccie.collab
Resolve-DnsName cucm-sub.ccie.collab
Get-Date
w32tm /query /status
Test-NetConnection 192.168.10.150 -Port 6970
Test-NetConnection 192.168.10.150 -Port 3804
Test-NetConnection 192.168.10.150 -Port 5061
Test-NetConnection 192.168.10.151 -Port 5061
```

These Test-NetConnection probes test TCP only. A successful test does not authenticate CAPF, validate a certificate or send a SIP REGISTER. A failed test identifies an unreachable TCP connection, not whether the cause is service, route or firewall. Keep these probe packets distinct from CIPC traffic in a capture.

**Expected:** configuration/CAPF/secure-SIP services are reachable as configured. **Next:** start Wireshark on .20.52's adapter, then CIPC. Set manual configuration/TFTP server .10.150 and verify the selected device name.

## Checkpoint 7 — understand the first startup

Use a broad display filter first:

```wireshark
ip.addr == 192.168.20.52
```

Then configuration:

```wireshark
ip.addr == 192.168.20.52 && (tcp.port == 6970 || tftp)
```

**Expected:** CTL/config file requests matching the device identity. The session used HTTP 6970. Configuration delivery can populate DN 2103 while the phone still says Registering. A .sgn suffix indicates signed-file format, not encrypted transport or installed LSC.

**Next:** inspect CIPC Settings → Security Configuration. If LSC Not Installed, perform enrollment. Do not just wait for registration or change the DN.

## Checkpoint 8 — submit the enrollment credential at the correct place

In **CIPC Settings → Security Configuration → LSC**, unlock with `**#` if the menu is locked, choose **Update**, enter the privately generated **CAPF authentication string**, and Submit. The string is not entered in Preferences → Directories or the Windows login dialog.

```wireshark
ip.addr == 192.168.20.52 && tcp.port == 3804
```

**Expected:** TCP/CAPF TLS exchange; LSC Installed on the phone; successful certificate-operation status in CUCM. An expired operation window or wrong string needs correction and a controlled retry, not unrelated cluster reconfiguration.

**Next:** allow reload/restart if requested. Watch configuration refresh followed by TCP 5061.

## Checkpoint 9 — verify mutual TLS, then registration

```wireshark
ip.addr == 192.168.20.52 && tcp.port == 5061
```

Confirm ClientHello, ServerHello, server certificate, CertificateRequest, phone LSC, CertificateVerify, Finished and protected data. Use Follow TCP Stream for each node separately. Record actual version/cipher.

On Windows:

```powershell
Get-NetTCPConnection -ErrorAction SilentlyContinue |
  Where-Object {
    $_.RemoteAddress -in @('192.168.10.150','192.168.10.151') -and
    $_.RemotePort -eq 5061
  } |
  Select-Object LocalAddress,LocalPort,RemoteAddress,RemotePort,State,OwningProcess
```

**Expected:** remote 5061 connections owned by CIPC; client source ports may be ephemeral. Empty UDP 5060 output is not a TLS failure.

**Next:** CUCM Device → Phone → exact identity → Registered and current node; CIPC no longer stuck Registering. These application checks complement encrypted packet evidence. Finally test a call and verify media independently.

## Checkpoint 10 — know when to stop changing settings

When the phone has its LSC, completes expected secure connections and registers, record the working state. Do not change security mode again to chase a cosmetic label or force local TCP 5061. Run a single controlled reboot/relaunch test and a separate call test.

A saved device survives application shutdown; a live registration does not remain active forever when the PC is off. If it disappears from a GUI list, clear filters and search the exact identity before concluding the record was deleted.

Reference: [Cisco security-mode workflow](https://www.cisco.com/c/en/us/td/docs/voice_ip_comm/cucm/security/14SU2/cucm_b_security-guide-14su2/cucm_m_ucm-security-modes_reorg.html). Command output examples in this guide are descriptions of observed outcomes, not fabricated full CLI transcripts.
