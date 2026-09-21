# Deployment: configure, explain, verify

[Learning path](../README.md) · [Ports and terms](02-ports-and-glossary.md)

**Start with the [command-by-command decision runbook](08-command-runbook.md).** It states where each command runs, expected results, failure branches and the next action. New clusters also need the [self-contained foundation](00-foundation.md).

This is a reproducible procedure assembled from the observed lab. Menu labels can vary by CUCM service update. Steps marked **verification** are checks a new student must perform; they do not imply every original screenshot showed that field.

## 1. Establish the network and stable identity

On PC3, before launching CIPC:

```powershell
hostname
Get-NetIPConfiguration
Get-NetAdapter | Select-Object Name, Status, MacAddress
Resolve-DnsName cucm-pub.ccie.collab
Resolve-DnsName cucm-sub.ccie.collab
Get-Date
w32tm /query /status
```

| Setting | Lab value | Purpose / expected result |
|---|---|---|
| Client IP | 192.168.20.52/24 | Identifies the TLS client in traces |
| Default gateway | 192.168.20.1 | Routes from client subnet to CUCM subnet |
| DNS | 192.168.10.157 | Resolves PUB and SUB names to .150 and .151 |
| Stable device identity | SEP020000000301 in examples | Matches the CUCM record and downloaded configuration |
| Time | Correct current date/time | Certificates have validity intervals; timezone display is not proof of clock accuracy |

Record your real adapter-derived device name locally. Do not enter the guide's generic name on a device whose CIPC identity differs. Changing a VM adapter/MAC can make the client request a different record.

**Verification:** name resolution returns the correct addresses; Windows and CUCM clocks are credible. Successful ping alone does not test CAPF or SIP TLS.

## 2. Prepare call routing and device defaults

Reuse existing lab objects if they match these settings. The [self-contained foundation](00-foundation.md) explains the network, user and provisioning objects within this TLS repository.

| CUCM path | Object / value | Why it exists |
|---|---|---|
| Call Routing → Class of Control → Partition | PT-HQ-INTERNAL | Holds permanent user DNs such as 2103 |
| Same path | PT-HQ-SERVICES | Holds provisioning IVR 2099 |
| Same path | PT-HQ-AUTOREG | Holds optional temporary staging DNs; not used to allocate this manually created phone |
| Call Routing → Class of Control → Calling Search Space | CSS-HQ-INTERNAL: INTERNAL then SERVICES partitions | Allows user calls to internal DNs and the IVR |
| Same path | CSS-HQ-AUTOREG: SERVICES only | Restricted access for optional temporary phones |
| System → Cisco Unified CM Group | CMG-HQ-LAB: PUB first, SUB second | Supplies call-processing priority; independent of TFTP selection |
| System → Phone NTP Reference | .10.1 and .10.2, lab time sources | References for devices that use phone NTP |
| System → Date/Time Group | DTG-HQ-INDIA, India UTC+05:30, DD/MM/YY-style display, 24-hour | Time presentation and phone time references |
| System → Device Pool | DP-HQ-INDIA, group above, date/time group above, Default region | Collects shared device settings |

Create partitions with Time Schedule None for continuous lab availability. Creating a partition does not reserve or create any DN. On PC3, manually assign **2103**; the auto-registration range does not constrain a manually assigned permanent DN.

**Verification:** open the objects and inspect their contents, then confirm the phone actually references the pool. CSS names do not prove partition membership. A wrong CSS can stop calls after registration; it does not explain a TLS handshake failure.

## 3. Understand user provisioning before touching security

For an existing LDAP-synchronized ONPREM user, do not recreate LDAP synchronization. Open **User Management → End User → ONPREM** and verify status. The TLS client certificate identifies the phone; the LDAP password and user PIN are not its private key.

| User field | Lab choice | Purpose |
|---|---|---|
| User ID | ONPREM | Owner identity; use the actual User ID, not merely display name |
| Controlled Devices | Your PC3 device | Associates the user with the phone |
| Primary Extension | 2103 / PT-HQ-INTERNAL after line creation | Declares the user's primary DN |
| Self-Service User ID | 2103 if retained for this user | Numeric identifier for self-provisioning; matching the DN is convenient, not a requirement |
| PIN | Existing private value | Used by applicable user services; not the CAPF authentication string |
| Standard CCM End Users | Retain as appropriate | End-user access; does not install an LSC |
| Standard CTI Enabled | Only for an actual CTI application use case | Does not repair SIP TLS registration |

A ULT supplies line defaults; a UDT supplies device defaults; a User Profile connects provisioning policy to templates. A manually created TLS phone does not need to call IVR 2099 before it can enroll a certificate. An IVR speed dial is optional and is not Line 2 or an additional registered DN.

## 4. Verify services and cluster prerequisites

Open **Cisco Unified Serviceability → Tools → Service Activation** and **Control Center – Feature Services**. Activated means enabled; Started means running.

| Service | Node / purpose in this lab | Verification |
|---|---|---|
| Cisco CallManager | PUB and SUB; SIP registration and call control | Started on each intended call processor |
| Cisco Tftp | PUB; distributes configuration/trust files | Started; actual capture used HTTP TCP 6970 |
| Cisco Certificate Authority Proxy Function | PUB; issues phone LSCs | Started; reachable on TCP 3804 |
| Cisco CTIManager | Nodes serving CTI applications | Handles application device control, not phone TLS handshakes |
| Cisco DirSync | Directory-sync node | Needed for LDAP synchronization, not each SIP REGISTER |
| Self Provisioning IVR | IVR node if using 2099 | Separate optional service for this manually provisioned TLS endpoint |

The lab's Cisco Certificate Enrollment Service was Activated but Not Running; CAPF was Started. Those names are not interchangeable. Do not start every service as a diagnostic substitute.

From CUCM CLI, record:

```text
show version active
show ctl
show tls min-version
```

**Verification:** use the actual CUCM release/security documentation and inspect licensing/export-controlled capability. In this session, Enhanced was Out of Compliance but mixed-mode activation and subsequent TLS worked; that status alone did not establish the registration fault. It is not a general license exemption.

For exact command placement and result interpretation, use [runbook checkpoints 1–4](08-command-runbook.md). For why enrollment/configuration use 3804/6970, read [CAPF and ports](09-capf-trust-and-ports.md).

## 5. Enable and verify mixed mode once

For a new lab, take a supported DRS backup and record existing settings before this cluster-wide change. Schedule service interruption. The original operator proceeded without a backup; that is historical context, not a reproduction recommendation.

On **PUB**:

```text
utils ctl set-cluster mixed-mode
```

Follow the command's restart instructions for the installed release. The session instructed restarting Cisco CallManager and Cisco CTIManager on PUB and SUB, one node at a time; preserve service availability where possible. Do not repeatedly toggle security mode to fix an individual phone.

Check `show ctl` on both nodes. In **System → Enterprise Parameters → Security Parameters**, verify **Cluster Security Mode = 1**. A previous “CTL file not found” changed to successful verification in this lab. An auto-registration warning accompanied the change; manual precreation avoids depending on auto-registration for PC3.

**Why:** this legacy phone-security workflow uses mixed mode and a CTL trust list. Mixed mode allows secure and nonsecure devices in the same cluster; it does not encrypt every phone automatically. See [Cisco security modes](https://www.cisco.com/c/en/us/td/docs/voice_ip_comm/cucm/security/14SU2/cucm_b_security-guide-14su2/cucm_m_ucm-security-modes_reorg.html).

**Verification:** CTL verification and mode 1 prove cluster preparation, not phone enrollment. Keep the previously working UDP device's profile separate.

## 6. Create the final phone security profile

**System → Security → Phone Security Profile → Add New → Cisco IP Communicator → SIP.**

| Field | Lab setting | Purpose / consequence |
|---|---|---|
| Name | SIP-Profile-TLS-Encrypted | Descriptive name; actual fields determine behavior |
| Device Security Mode | Encrypted | Requests encrypted signaling/media behavior; verify negotiated signaling and media independently |
| Transport Type | TLS | Runs SIP inside TLS over TCP |
| SIP Phone Port | 5061 | Secure SIP setting; does not require the PC's outgoing source port to be 5061 |
| Nonce Validity Time | 600 | Digest nonce lifetime; not a TLS certificate lifetime or CAPF deadline |
| Enable Digest Authentication | Unchecked | This exercise uses certificate-based phone authentication |
| TFTP Encrypted Config | Unchecked | Configuration-file encryption is separate from SIP TLS; a signed file can still be readable |
| Exclude Digest Credentials in Configuration File | Unchecked in captured setup | No digest enrollment is being demonstrated |
| CAPF Authentication Mode | By Authentication String | Requires the enrollment string entered on the phone |
| Key Order | RSA Only | Algorithm choice for this legacy lab |
| RSA Key Size | 2048 | Phone certificate key size selected in setup; unrelated to TCP port number |
| EC Key Size | None / inactive | No EC key requested in this profile |

Save. Creating this profile does not assign it to a phone.

**Authenticated versus Encrypted:** Cisco's legacy Authenticated mode should not be assumed to provide signaling confidentiality; NULL-encryption suites can be associated with that mode. This guide targets Encrypted and verifies AES in the actual ServerHello. The original session temporarily displayed Authenticated, but the successful capture downloaded security mode 3 and negotiated AES. Profile labels and remembered clicks are weaker evidence than the configuration and negotiated session. See [Cisco phone security](https://www.cisco.com/c/en/us/td/docs/voice_ip_comm/cucm/security/14SU2/cucm_b_security-guide-14su2/cucm_m_phone-security_reorg.html).

Do not lower TLS minimum versions or alter cluster cipher policy without examining ClientHello/ServerHello and checking support. TLS 1.0 was observed in this legacy lab; it is not the target for new production designs.

## 7. Create PC3's phone record while CIPC is closed

**Device → Phone → Find** using your real device name. If absent: **Add New → Cisco IP Communicator → SIP → Next**. Search first to avoid duplicate/incorrect identities.

| Field | Value | Purpose |
|---|---|---|
| Device Name | Your real name; SEP020000000301 only in this guide | Selects the configuration CIPC requests |
| Description | HQ PC3 CIPC SIP TLS | Human-readable inventory |
| Device Pool | DP-HQ-INDIA | Inherits CUCM group and related settings |
| Device Security Profile | SIP-Profile-TLS-Encrypted | Applies the secure policy created above |
| SIP Profile | Standard SIP Profile | SIP operational settings; different from the security profile |
| Phone Button Template | Standard CIPC SIP | Two line slots in the demonstrated layout |
| Softkey Template | Standard User | User button actions |
| Common Phone Profile | Standard Common Phone Profile | Common phone behavior |
| Calling Search Space | CSS-HQ-INTERNAL | Call destination visibility |
| Location | Hub_None | Lab location/admission-control selection |
| Owner User ID | ONPREM | Ownership association; does not supply a certificate |

Save. Keep unrelated defaults unless another requirement justifies a change.

## 8. Configure Line 1 and user association

Click **Line [1] → Add a new DN**:

| Field | Value | Purpose |
|---|---|---|
| Directory Number | 2103 | Called/calling extension |
| Route Partition | PT-HQ-INTERNAL | Namespace containing this DN |
| Calling Search Space | CSS-HQ-INTERNAL | Line calling permissions |
| Display / ASCII Display | ONPREM | Caller display text |
| Line Text Label | 2103 - TLS | Local phone label; does not prove transport encryption |

Save and return to the phone. Leave **Line 2 unassigned**. If desired, configure **2099 / Self-Provision** as a speed dial, not a DN. In Standard CIPC SIP, the first speed dial appeared at button 3; a different template can place it at button 2.

Return to the end user: associate the correct Controlled Device, select Primary Extension 2103/PT-HQ-INTERNAL, and save. A Self-Service ID of 2103 does not create the line and does not make CIPC select a configuration by user ID.

## 9. Arm CAPF enrollment on this phone

On **Device → Phone → PC3 → CAPF Information**, configure the available per-phone fields and verify inherited values:

| Field | Value | Purpose |
|---|---|---|
| Certificate Operation | Install/Upgrade | Requests certificate enrollment, rather than merely displaying a security mode |
| Authentication Mode | By Authentication String | Must agree with the intended enrollment method |
| Authentication String | Generate a new private value | Enrollment credential entered at the endpoint; never commit it to GitHub |
| Operation Completes By | A future lab maintenance deadline | Enrollment must occur while the operation is valid |
| Key algorithm / RSA size, where exposed | RSA / 2048 | Keep consistent with the selected profile |
| Certificate Operation Status | Inspect after enrollment | Confirms whether the requested operation completed |

Save and Apply Config. Keep the generated string privately available. This is **not** the LDAP password, end-user PIN, Self-Service ID, CTL hash, certificate fingerprint or a private key. See [Cisco CAPF phone configuration](https://www.cisco.com/c/en/us/td/docs/voice_ip_comm/cucm/security/14SU2/cucm_b_security-guide-14su2/cucm_m_certificate-authority-proxy-function_su2_reorg.html).

The final TLS profile can be assigned before the first launch. Enrollment still must happen before certificate-based secure registration can succeed. There is no claim that an LSC-free phone can skip this stage.

## 10. Install and launch CIPC with a capture running

Use an authorized CIPC installer source. The observed package folder was `cipc-Admin-fmr.8-6-6-0`. `CiscoIPCommunicatorSetup.exe` and its MSI are alternative installation entry points; do not install both as separate products. `CiscoIPCommunicatorAdminToolSetup` is an administrative utility package, not the client required on PC3. Installers are not redistributed here.

Start Wireshark on PC3 Ethernet0 before starting CIPC. In **Preferences → Network**:

- Select the intended adapter and verify the displayed device name matches CUCM.
- Set TFTP Server 1 to **192.168.10.150**.
- Add .151 as a second server only if its configuration/TFTP service has been verified. TFTP choice is independent of PUB/SUB call-processing priority.
- Confirm audio devices using the client wizard.

**Expected:** configuration and trust-file downloads, then the ability to initiate LSC enrollment. Seeing 2103 on the display proves some configuration arrived, not that SIP registration succeeded.

## 11. Enter the CAPF string and install the LSC

In CIPC **Settings → Security Configuration**, inspect LSC. The failed state was **Not Installed**. On the demonstrated legacy client, unlock settings with **`**#`**, select **LSC → Update**, enter the generated CAPF authentication string, and submit. Softkey wording can vary by load.

Watch for enrollment completion and any requested client restart. Check **LSC Installed** on CIPC and the per-phone certificate-operation status in CUCM. Allow configuration reload/reconnection to complete.

**Expected packets:** PC3 → PUB TCP 3804; CAPF TLS exchange; subsequent PC3 → PUB/SUB TCP 5061 with a client certificate and completed handshakes. The endpoint generates/holds the private key; the authentication string is not that key.

If no 3804 attempt occurs, inspect whether Update was actually initiated and the operation deadline remains valid. If transport works but enrollment fails, inspect CAPF status/logs, auth-string match, clock and trust; do not assume every RST means a wrong string.

## 12. Accept the result with separate checks

| Layer | Acceptance evidence |
|---|---|
| Configuration | Correct device name, DN, pool, profile and signed configuration downloaded |
| Enrollment | CIPC LSC Installed plus successful CAPF operation status |
| TLS | Client certificate matching this phone, completed mutual TLS, encrypted application data |
| SIP registration | CUCM Registered and phone usable; decrypted SIP or correlated CUCM logs for exact REGISTER/200 OK proof |
| Redundancy | Controlled primary-node interruption and recovery, with a fresh capture and active-node verification |
| Media | A test call with negotiated SRTP and appropriate endpoint/call evidence; not established merely by port 5061 |

In the observed success trace, TLS completed to both nodes and the operator reported registration. Active-node identification and SRTP remain separate checks. Follow the two case studies before declaring every security layer proven.
