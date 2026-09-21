# Case B: LSC installed, mutual TLS established

[Learning path](../README.md) · [Wireshark exercises](05-wireshark-workbook.md)

**Observed outcome:** after LSC installation the client presented its phone certificate to both PUB and SUB, completed TLS handshakes and exchanged encrypted application data. The operator reported registration. Exact SIP REGISTER/200 OK messages are encrypted and were not decoded in this analysis.

Source: private success capture, 2,317 frames over approximately 157.037 seconds. Frame numbers below are specific to that file. Certificate identities/serials/hashes shown here are synthetic.

## 1. CAPF enrollment conversation

| Frame(s) | Exchange | Purpose / interpretation |
|---|---|---|
| 363–365 | PC3 source 56148 → PUB TCP 3804, SYN/SYN-ACK/ACK | Establish reliable transport to CAPF |
| 366 | ClientHello | Offers TLS parameters |
| 368 | ServerHello, CAPF certificate, ServerHelloDone | Selects TLS 1.0 and suite 0x0035 |
| 369 / 371 | Client/server key-establishment and protected handshake completion | CAPF TLS session becomes usable |
| 372 onward | Encrypted application exchange | Enrollment protocol content is protected |
| 425–433 | Additional protected exchange | Do not infer entered authentication digits from record sizes |
| 435–436 | Encrypted alert then reset | Description unreadable without keys; subsequent success prevents treating this alone as enrollment failure |
| 437–483 | Additional short CAPF connections | Multiple connections occurred; do not assign undocumented meanings to each |

CAPF enrollment success is supported by the subsequent phone certificate, not by guessing at the encrypted CAPF payload.

## 2. Configuration refresh

Frames 506 onward show another signed phone-configuration download. The payload included:

```text
deviceSecurityMode: 3
transportLayerProtocol: 3
voipControlPort: 5061
certHash: <NONEMPTY_VALUE_REDACTED>
```

Mode 3 identifies the Encrypted setting in this observed configuration. The nonempty certHash corroborates the changed state; it is not the full certificate and is not a replacement for verifying the certificate presented during TLS. A later download at 541 onward showed the same relevant state.

## 3. PUB mutual TLS, message by message

| Frame(s) | Direction / message | Read this field or lesson |
|---|---|---|
| 732–734 | PC3:56153 ↔ PUB:5061 TCP handshake | Server destination is 5061; client uses an ephemeral source port |
| 735 | Client → PUB: ClientHello | Client's capabilities, not final selection |
| 737 | PUB → client: ServerHello | TLS 1.0, cipher 0x002f |
| 737 | PUB certificate | Server identity corresponds to PUB |
| 737 | CertificateRequest | PUB asks the phone to authenticate |
| 738 | Client Certificate | Phone presents its CAPF-issued LSC |
| 738 | ClientKeyExchange and CertificateVerify | Key establishment plus proof of client private-key possession |
| 738 / 740 | Cipher-state change and protected Finished exchange | Handshake completes |
| 750 | Client encrypted application data | Higher-layer traffic begins |
| 752, 755, 756–757, 761 | Protected data in both directions | Continuing protected exchange; some records span TCP segments |

A TCP packet may contain multiple TLS handshake messages. Conversely, one TLS record can span several TCP segments. This is why “packet by packet” analysis must also follow the reassembled stream.

## 4. SUB mutual TLS

| Frame(s) | What happened | Meaning |
|---|---|---|
| 741–743 | PC3:56154 ↔ SUB:5061 TCP handshake | Separate connection from the PUB stream |
| 744 | ClientHello | Client initiates SUB TLS |
| 746 | ServerHello, certificate and CertificateRequest | Same observed TLS version/cipher, SUB server identity |
| 747 | Client LSC and CertificateVerify | Same phone identity authenticates to SUB |
| 749 | Server handshake completion | SUB accepts the TLS exchange |
| 759, 760, 762 | Encrypted application data | Protected traffic follows |

Both connections can exist without proving which node is the active registrar. Check CUCM's device status and CIPC Unified CM list, or correlate CallManager traces. Connection timing alone is insufficient to label failover.

## 5. Generic LSC example

```text
EXAMPLE ONLY — NOT AN ACTUAL CERTIFICATE
Status: Installed
Subject CN: SEP020000000301
Issuer CN: CAPF-LAB-EXAMPLE
Serial: 0x1001
SHA-256 fingerprint:
AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:
AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99
Private key: NEVER EXPORTED TO THIS GUIDE
```

The fingerprint is a made-up 32-byte example, not computed from a certificate. It is also not the observed configuration's certHash. Do not compare or import it into a real deployment. [Machine-readable teaching example](../examples/success.json).

## 6. Claims supported by the evidence

| Claim | Status |
|---|---|
| CAPF connectivity occurred | Confirmed |
| Client used an LSC issued by CAPF | Confirmed by presented certificate |
| Mutual TLS completed to both CUCM nodes | Confirmed |
| Signaling connection used encryption | Confirmed by AES cipher and protected records |
| Exact REGISTER/200 OK contents | Not visible without decryption or server-side logs |
| Phone registered | Operator reported; pair with current CUCM/phone status |
| PUB was active solely because its handshake occurred first | Not established |
| SRTP audio was negotiated and carried | Not established; requires a call test |
| Long-term stability / restart recovery | Not established by this short capture |
| Modern production-grade TLS configuration | No; TLS 1.0/static RSA/CBC is legacy |

The observed 0x002f suite is defined in the [IANA registry](https://www.iana.org/assignments/tls-parameters). Do not mistake the record-layer version field for a universal method of identifying all modern TLS versions; inspect negotiated handshake details appropriate to the protocol version.
