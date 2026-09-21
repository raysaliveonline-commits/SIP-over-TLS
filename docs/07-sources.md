# Sources, scope and evidence

[Learning path](../README.md)

## Evidence labels

- **Observed:** screenshots, CLI/PowerShell output, operator confirmation, or the private captures analyzed during this lab.
- **Procedure:** instructions for reproduction; not proof every corresponding GUI field was visible in the original evidence.
- **Example:** deliberately synthetic certificate/device values; not runnable certificate material.
- **Not established:** requires another capture, call test, application status or logs.

The source failure capture contained 6,071 frames; the success capture contained 2,317. Analysis distinguished PC3 (.20.52) from PC1 (.20.50), configuration downloads from TLS, and CAPF from CallManager sessions. Public documentation contains the derived sequence, not original capture payloads. Because the raw captures remain private, readers should reproduce with their own lab rather than expect bundled PCAP exercises.

## Primary references

| Topic | Official reference |
|---|---|
| Phone security modes/profiles | [Cisco CUCM 14 Phone Security](https://www.cisco.com/c/en/us/td/docs/voice_ip_comm/cucm/security/14SU2/cucm_b_security-guide-14su2/cucm_m_phone-security_reorg.html) |
| Mixed mode and CTL | [Cisco CUCM 14 Security Modes](https://www.cisco.com/c/en/us/td/docs/voice_ip_comm/cucm/security/14SU2/cucm_b_security-guide-14su2/cucm_m_ucm-security-modes_reorg.html) |
| LSC enrollment / CAPF | [Cisco CUCM 14 CAPF](https://www.cisco.com/c/en/us/td/docs/voice_ip_comm/cucm/security/14SU2/cucm_b_security-guide-14su2/cucm_m_certificate-authority-proxy-function_su2_reorg.html) |
| Cipher identifiers | [IANA TLS Parameters](https://www.iana.org/assignments/tls-parameters) |
| TLS packet fields | [Wireshark TLS filter reference](https://www.wireshark.org/docs/dfref/t/tls.html) |
| SIP packet fields | [Wireshark SIP filter reference](https://www.wireshark.org/docs/dfref/s/sip.html) |
| TCP endpoint inspection | [Microsoft Get-NetTCPConnection](https://learn.microsoft.com/en-us/powershell/module/nettcpip/get-nettcpconnection) |
| UDP endpoint inspection | [Microsoft Get-NetUDPEndpoint](https://learn.microsoft.com/en-us/powershell/module/nettcpip/get-netudpendpoint) |

Configuration values in this guide primarily describe the lab, not universal defaults. Consult documentation for the exact endpoint and CUCM service update before transferring the procedure to another environment. The observed TLS 1.0 session establishes interoperability only, not Windows 11 certification or a recommended cryptographic baseline.

## Publication rules

The original MACs/device names, LSC subject identifiers, CAPF issuer identifier, serials, CTL/certificate hashes and enrollment secrets are omitted or replaced. No binary certificates, screenshots, installers or captures are included. The SHA-256 example is synthetic and is not the phone configuration's certHash. Existing lab IP addresses and public repository ownership remain visible by design.
