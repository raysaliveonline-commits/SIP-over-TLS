# Session review: what was retained and what remains unproven

[Start](../README.md)

This audit covers the supplied September 20–21 chat, current published guides, recovered prior-session context, screenshots described in the session, and recorded packet findings. It does not invent missing full CLI output or claim an unobserved setting was saved. Raw private captures and credentials remain unpublished.

## Chronology and evidence

| Stage | What happened | Where the learning is preserved |
|---|---|---|
| Existing UDP endpoint | PC1 .20.50, DN1003, MicroSIP UDP5060 conflict | Separate UDP repository |
| PUB/SUB questions | Phone alternated active node; GUI view confused with persistent device record | Operations; do not infer cause without relevant capture/logs |
| CIPC legacy video question | Client requested CUVA 2.0(1)+; installer unavailable | Scope appendix below |
| PC3 network | HQ-PC3-TLS .20.52, domain DNS .10.157, PUB/SUB resolution correct | Foundation and runbook |
| CIPC package | Same 8.6.6 package used on Win11 as Win10 | Deployment; lab interoperability boundary |
| Initial security profile | Authenticated/TLS shown, then Encrypted/TLS with By Authentication String | Deployment field table and mode explanation |
| Service audit | CallManager/TFTP/CAPF started; Certificate Enrollment Service not running | Runbook and service distinctions |
| Licensing question | Registered, Enhanced Out of Compliance | Recorded without attributing the later transport error to licensing |
| Initial cluster checks | Mode 0; show ctl file not found | Runbook checkpoint 1 |
| Mixed-mode action | utils ctl set-cluster mixed-mode; auto-registration warning; service-restart instructions | Runbook checkpoint 3 |
| Subsequent cluster checks | Mode 1 screenshot, CTL verified on PUB then SUB | Runbook checkpoint 4 |
| Device identity question | Adapter-derived SEP identity could be known before first registration | Foundation identity mapping |
| Admin GUI security error | Retry using a fresh valid admin session | Operations roadblocks |
| User and number | ONPREM owner, Self-Service ID2103, Line1 DN2103, label2103 - TLS | Deployment and identity distinction |
| Startup | Capture first, manual server .150, stable adapter identity | Runbook checkpoints 6–7 |
| Registering with no LSC | CIPC LSC Not Installed; CAPF server .150:3804; CTL present | Failure case |
| Failure trace | Downloaded secure config but plain TCP5060 REGISTER;403 expected TLS | Packet-level failure case |
| LSC installation | CAPF enrollment action followed by new client certificate | Runbook checkpoint 8 and success case |
| Success trace | TLS1.0/AES128-CBC-SHA mutual TLS with PUB/SUB; encrypted application records | Successful case; no invented SIP plaintext |
| GitHub publication | Generic MACs, issuer IDs, serials and hashes; no originals | All public examples |
| Separation correction | UDP and TLS each have independent README, docs and scripts | Current standalone layouts |

## Topic coverage checklist

| Student requirement | Primary location |
|---|---|
| Every network address and role | Foundation; README |
| Partition/CSS menu paths, membership, why | Foundation |
| CM group / NTP / IST / device pool | Foundation |
| LDAP sync versus authentication | Foundation |
| ULT/UDT/User Profile/Feature Group Template | Foundation optional provisioning |
| IVR2099/CTI route point/application user | Foundation and CAPF/ports lesson |
| Manual2103 versus auto-reg pool | Foundation and deployment |
| show version active / show ctl / show tls min-version | Command runbook |
| Mixed mode: when/why/how/expected result | Command runbook checkpoints1–4 |
| show ctl after PUB and SUB change | Checkpoint4 |
| Service activation versus Started | Checkpoint2 |
| Restart CallManager/CTIManager order and purpose | Checkpoint3 |
| Encrypted versus Authenticated | Deployment; actual capture result retained |
| Security profile fields and assignment | Deployment steps6–7 |
| CAPF Install/Upgrade/string/deadline/RSA | Deployment step9 and runbook8 |
| Unlock **# and enter string at LSC Update | Deployment step11 and runbook8 |
| CAPF3804 versus incorrect3084 | Dedicated CAPF/ports lesson |
| HTTP6970 versus TFTP setting | Dedicated CAPF/ports lesson |
| CTL, ITL, LSC, MIC, issuer, serial, key, fingerprint | Glossary and trust comparison |
| Windows probes and socket ownership | Runbook and read-only script |
| One failed missing-LSC state | Failure case and synthetic JSON |
| One successful LSC/TLS state | Success case and synthetic JSON |
| Wireshark filters and packet sequence | Workbook and both cases |
| PUB/SUB active versus two connections | Success case and operations |
| TLS signaling versus SRTP media | Success limits and acceptance checklist |
| Persistent device record versus live registration | Operations |
| Failure symptoms, next action and recovery | Runbook + troubleshooting worksheet |
| Exact observed versus proposed values | Case studies and this audit |

## Adjacent questions from the day

- **CUVA/video:** the client displayed that Cisco Unified Video Advantage 2.0(1) or greater was required; no installer was available in the session. No working video deployment or supported Win11 CUVA combination was established. Do not present video as completed or necessary for TLS registration.
- **RDP:** Windows 11 Pro can be managed through Settings → System → Remote Desktop. It is optional administration, not a SIP dependency. An RDP login/audio redirection is a separate operational variable when testing a softphone; the trace here does not establish its effects.
- **Installer provenance:** client EXE/MSI were alternative installation methods; no redistributable or current supported Win11 CIPC installer was established. AdminTool is not a prerequisite for PC3 registration.
- **HTTPS trust:** AD CA/GPO/browser security was earlier work. It does not replace CAPF phone enrollment.

## Evidence that is still a separate test

1. The exact encrypted REGISTER/200 OK content requires authorized decryption or correlated CUCM traces.
2. The active registrar is not proved by opening two TLS connections; use CUCM/CIPC state.
3. SRTP needs a call-specific test; the session's TLS handshake alone does not prove it.
4. A brief success capture does not establish long-term renewals or reboot stability.
5. The original IVR's final user authentication/template application was not fully verified; preserve that boundary in the UDP guide.

The earlier master plan preferred Authenticated/RTP. The later session selected Encrypted, and the success download had deviceSecurityMode3 with an AES cipher. This guide follows the later evidence instead of silently restoring the older plan.
