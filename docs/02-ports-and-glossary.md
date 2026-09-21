# Ports and technical glossary

[Learning path](../README.md)

## Port map: identify the service before diagnosing it

A connection is identified by protocol plus source/destination addresses and ports. TCP 5060 and UDP 5060 are distinct sockets. A destination/service port is not necessarily the client's source port.

| Protocol / server port | Conversation | Purpose | Scope / evidence |
|---|---|---|---|
| UDP or TCP 53 | Client → DNS .10.157 | Resolve server names | Background dependency; IP-only requests need not cause DNS packets |
| UDP 123 | Time client → NTP source | Clock synchronization | Windows/server/phone time mechanisms are separate |
| UDP 69, then negotiated UDP ports | Phone ↔ TFTP | Initial file request and transfer | Possible phone provisioning path; do not filter only port 69 for the whole transfer |
| TCP 6970 | PC3 → PUB | HTTP configuration/trust-file download | Observed in both TLS case studies |
| TCP 3804 | PC3 → PUB CAPF | LSC enrollment over a TLS-protected connection | Observed in successful case; absent in failed case |
| TCP 5061 | PC3 → PUB and SUB | SIP over TLS | Observed client source ports 56153 and 56154 in success capture |
| TCP or UDP 5060 | Phone ↔ CallManager | Nonsecure SIP | Failure capture used TCP even though CUCM expected TLS |
| TCP 443 | Browser → CUCM | HTTPS administration | GUI security is not proof of phone SIP TLS |
| TCP 2748 / 2749 | CTI application → CTIManager | Conventional nonsecure / secure CTI application connectivity | Background ports; verify release-specific CTI configuration; not the observed CIPC SIP registration path |
| TCP 389 / 636 | CUCM directory client → directory server | LDAP / LDAPS, subject to configured directory design | User synchronization/authentication; not LSC enrollment |
| Negotiated UDP ports | Endpoint ↔ endpoint or media resource | RTP/SRTP media; RTCP/SRTCP control | Read actual media negotiation/configuration; do not assume audio traverses 5061 |

Common CUCM media ranges are not a universal rule for every softphone/media resource. This lab did not establish a final SRTP port range. Open only the ranges required by the actual deployment and verify media flows.

The name “TFTP server” in CIPC preferences does not guarantee all downloads use TFTP. The captures showed HTTP on 6970. HTTP 200 proves file delivery, not successful signature validation.

CTI port mapping and its separate application security workflow: [Cisco CTI, JTAPI and TAPI security](https://www.cisco.com/c/en/us/td/docs/voice_ip_comm/cucm/security/14SU2/cucm_b_security-guide-14su2/cucm_b_security-guide-1251SU2_chapter_010101.html).

## Core terms

| Term | Technical meaning | Why students need it |
|---|---|---|
| CUCM | Cisco Unified Communications Manager | Call-processing and device-configuration platform |
| CIPC | Cisco IP Communicator | Legacy Windows software phone |
| PUB / SUB | Publisher / Subscriber | Cluster node roles; either can process calls if configured/running |
| SIP | Session Initiation Protocol | Signaling messages such as REGISTER, INVITE and BYE |
| UDP / TCP | Datagram / reliable byte-stream transports | TCP has connection setup and retransmission; UDP does not |
| TLS | Transport Layer Security | Negotiates authentication, integrity and, with an encrypting cipher, confidentiality over a connection |
| Mutual TLS / mTLS | Both sides authenticate with certificates | CUCM requests a client certificate; the phone presents its LSC and proves key possession |
| CAPF | Certificate Authority Proxy Function | Issues/manages phone LSCs; **CAPF**, not “CPAF” |
| LSC | Locally Significant Certificate | Cluster-enrolled phone identity certificate; contains public key and identity, not the private key |
| MIC | Manufacturer Installed Certificate | Factory device certificate on supported hardware; do not assume CIPC has one |
| CA | Certificate Authority | Entity signing certificates and asserting identity bindings |
| CSR | Certificate Signing Request | Request containing public key/identity information to be certified |
| X.509 | Certificate format | Encodes subject, issuer, validity, public key, signature and extensions |
| CN / subject | Common Name / certified identity fields | Phone subject in examples is CN=SEP020000000301 |
| Issuer | Certificate signer identity | Synthetic example CN=CAPF-LAB-EXAMPLE |
| Serial number | Identifier assigned by issuer | Not an enrollment password; uniqueness is interpreted with issuer |
| Fingerprint / hash | Digest computed from certificate or other data | Identifies bytes for comparison; cannot replace the certificate/private key |
| Private key | Secret used for signature/decryption operations | Must remain protected; never put it in the repository |
| CTL | Certificate Trust List | Trusted cluster security identities/roles for this legacy secure-phone workflow |
| ITL | Initial Trust List | Initial/default phone trust mechanism; not identical to CTL |
| TVS | Trust Verification Service | Helps supported phones validate certificates; not the CAPF enrollment service |
| Mixed mode | Cluster security mode supporting secure and nonsecure endpoints | Cluster capability; each device still has its own security profile |
| Device security profile | Phone model/protocol/security policy | Determines TLS/UDP/TCP and security behavior |
| SIP Profile | SIP operational/timer behavior | Different CUCM object from a Phone Security Profile |
| CAPF authentication string | Per-operation enrollment credential | Entered at LSC Update; different from user PIN or digest password |
| Digest authentication | Challenge-response authentication with a nonce | Separate from certificate-based mutual TLS |
| Nonce | Challenge value used in authentication | Nonce validity 600 is not certificate validity |
| CTI | Computer Telephony Integration | Applications control/monitor devices/calls |
| CTIManager | CUCM service exposing CTI control | Supports JTAPI/TAPI applications; does not issue LSCs |
| JTAPI / TAPI | Java / Telephony Application Programming Interface | APIs used by telephony applications |
| CTI route point | Virtual call-routing device controlled by an application | CTIRP-SELFPROV carries IVR DN 2099; it is not the PC3 TLS endpoint |
| IVR | Interactive Voice Response | Prompts and keypad interaction for provisioning or other services |
| DN / partition | Directory number / routing namespace | 2103 in INTERNAL is distinct from another 2103 in another partition |
| CSS | Calling Search Space | Ordered visibility of partitions for call routing |
| Device pool | Shared device settings container | Links phone to CM group, date/time and other site settings |
| CM group | Ordered call-processing server list | Explains candidate PUB/SUB connections |
| UDT / ULT | Universal Device / Line Template | Supplies defaults when provisioning devices/lines |
| LDAP | Lightweight Directory Access Protocol | Directory integration; LDAP sync does not create a TLS certificate |
| FQDN | Fully Qualified Domain Name | Complete server name, e.g. cucm-pub.ccie.collab |
| NTP | Network Time Protocol | Clock synchronization; certificate validity depends on time |
| SDP | Session Description Protocol | Negotiates media addresses, ports, codecs and related attributes within signaling |
| RTP / RTCP | Real-time Transport / Control Protocol | Media delivery and quality/control reporting |
| SRTP / SRTCP | Secure RTP / secure RTCP | Media/control protection independent of the SIP TLS transport |
| DRS | Disaster Recovery System | CUCM supported backup/restore facility |

## TLS handshake terms used in the successful trace

| Message / field | Meaning | Evidence strength |
|---|---|---|
| ClientHello | Client offers versions, suites and other parameters | Offer is not the final negotiated result |
| ServerHello | Server selects protocol/cipher | Inspect this to identify actual TLS version and cipher |
| Certificate | Sends public certificate chain | Read subject, issuer and validity; private key is not sent |
| CertificateRequest | Server asks for client certificate | Request alone does not prove client authentication succeeded |
| ClientKeyExchange | Participates in session key establishment | Details depend on suite; captured suite used RSA key exchange |
| CertificateVerify | Client signs handshake material | Demonstrates possession of the client private key when successfully verified |
| ChangeCipherSpec | Switches record protection state in this TLS version | Not the same as a SIP status code |
| Finished | Protects a summary of handshake state | Successful completion and subsequent traffic support an accepted handshake |
| Application Data | Protected higher-layer content | Cannot label an individual encrypted record REGISTER without decryption/log correlation |
| TLS alert | Protocol notification/error/closure | An encrypted alert's description may be unreadable |
| TCP RST | Abrupt TCP connection termination | Not a diagnosis of wrong PIN, certificate or password by itself |

The observed SIP suite **TLS_RSA_WITH_AES_128_CBC_SHA (0x002f)** uses RSA key exchange/authentication, AES-128 CBC record encryption and SHA-1-based HMAC integrity. It does not imply that the certificate itself was signed with SHA-1. Static RSA lacks forward secrecy. The CAPF connection selected **0x0035**, AES-256-CBC-SHA. Suite definitions: [IANA TLS registry](https://www.iana.org/assignments/tls-parameters).
