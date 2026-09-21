# Wireshark workbook: follow the evidence

[Learning path](../README.md)

## Capture preparation

1. Choose the Ethernet adapter carrying **192.168.20.52**.
2. Start before CIPC. Record the exact action/time: launch, LSC Update, restart or call.
3. Optional **capture filter**: `host 192.168.20.52`. For maximum context, capture without a filter on the isolated lab interface.
4. Complete one controlled attempt, wait for the result, then stop and save privately.
5. Add useful columns: relative time, source/destination, source/destination ports, protocol, stream index and Info. Use a Time Reference on the first relevant SYN when comparing delays.

Do not paste display-filter syntax into the capture-filter box. Do not distribute original PCAPs just because SIP application data is encrypted: plaintext config, certificates, MACs and other traffic can still identify the lab.

## Display filters

| Question | Display filter |
|---|---|
| All PC3 IPv4 traffic | `ip.addr == 192.168.20.52` |
| PC3 traffic to either CUCM | `ip.addr == 192.168.20.52 && (ip.addr == 192.168.10.150 || ip.addr == 192.168.10.151)` |
| Configuration delivery | `ip.addr == 192.168.20.52 && (tcp.port == 6970 || tftp)` |
| HTTP requests | `ip.addr == 192.168.20.52 && http.request` |
| HTTP failures | `ip.addr == 192.168.20.52 && http.response.code >= 400` |
| CAPF enrollment | `ip.addr == 192.168.20.52 && tcp.port == 3804` |
| Secure SIP connection | `ip.addr == 192.168.20.52 && tcp.port == 5061` |
| PUB secure connection | `ip.addr == 192.168.20.52 && ip.addr == 192.168.10.150 && tcp.port == 5061` |
| SUB secure connection | `ip.addr == 192.168.20.52 && ip.addr == 192.168.10.151 && tcp.port == 5061` |
| Offered TLS handshake | `ip.addr == 192.168.20.52 && tls.handshake.type == 1` |
| ServerHello selections | `ip.addr == 192.168.20.52 && tls.handshake.type == 2` |
| CUCM asks for certificate | `tcp.port == 5061 && tls.handshake.type == 13` |
| Phone presents certificate | `ip.src == 192.168.20.52 && tcp.port == 5061 && tls.handshake.type == 11` |
| Client proof of key possession | `ip.src == 192.168.20.52 && tcp.port == 5061 && tls.handshake.type == 15` |
| Protected application records | `ip.addr == 192.168.20.52 && tcp.port == 5061 && tls.record.content_type == 23` |
| TLS alerts | `ip.addr == 192.168.20.52 && tls.record.content_type == 21` |
| TCP resets | `ip.addr == 192.168.20.52 && tcp.flags.reset == 1` |
| Retransmission symptoms | `ip.addr == 192.168.20.52 && tcp.analysis.retransmission` |
| Plain SIP registration transactions | `ip.addr == 192.168.20.52 && sip.CSeq.method == "REGISTER"` |
| Plain SIP errors | `ip.addr == 192.168.20.52 && sip.Status-Code >= 400` |
| PC3 nonsecure SIP ports | `ip.addr == 192.168.20.52 && (tcp.port == 5060 || udp.port == 5060)` |

Right-click a relevant packet → **Follow → TCP Stream** to isolate a connection. Wireshark supplies the actual `tcp.stream == N`; N is capture-specific. Following a TCP stream does not decrypt TLS. If TLS is not decoded on a relevant port, use **Analyze → Decode As → TLS**, after confirming that the bytes are actually TLS.

TLS field definitions: [Wireshark TLS display-filter reference](https://www.wireshark.org/docs/dfref/t/tls.html). TLS 1.3 hides more handshake content than this TLS 1.0 trace; do not expect identical visibility with modern clients.

## Exercise A: find the first conclusive failure

Open your failed attempt; isolate PC3. Work downward through dependencies:

1. Does configuration retrieval finish? Read the HTTP status and requested device filename.
2. Does any 3804 connection occur? An empty result means no observed enrollment traffic, not proof of a bad authentication string.
3. Does the phone connect to 5060 or 5061? Inspect TCP/UDP and destination port together.
4. If SIP is readable, expand REGISTER Via, Contact, Call-ID and CSeq.
5. Match the reply using stream/transaction fields. Read the Warning header, not only the numeric status.

**Original case answer:** frame 3008 explicitly rejects the TCP registration because TLS was expected. The missing-LSC display identifies an unfinished enrollment prerequisite. A 404 for optional directory/dial-rule files is not a stronger explanation than the direct SIP warning.

## Exercise B: prove phone authentication

On the successful PUB flow:

1. Find ServerHello. Record version and selected cipher.
2. Find the server CertificateRequest.
3. Expand the client Certificate: subject CN must match the phone; issuer must match the intended issuing authority. Inspect validity and key details too.
4. Locate CertificateVerify and completed handshake exchange.
5. Confirm protected application data follows in both directions.

**Original case answer:** 737 requests the certificate; 738 contains the client LSC and CertificateVerify; 740 completes the server side; 750 onward carries protected application data. Repeat on SUB at 746/747/749.

## Exercise C: separate transport, registration and media

| Observation | Valid conclusion | Invalid shortcut |
|---|---|---|
| SYN/SYN-ACK/ACK on 5061 | TCP destination reachable | “The phone is registered” |
| TLS handshake completes | TLS session established | “REGISTER received 200 OK” without decrypt/log proof |
| Encrypted application data | Protected payload exchanged | “That record is definitely REGISTER” based only on size |
| CUCM Registered and phone available | Operational registration reported by application state | “SRTP is proven” |
| Audio flows between endpoints | Media connectivity | “Audio is encrypted” merely because it sounds normal |

To prove SIP messages, use authorized server traces or supported session decryption. A certificate's public key cannot decrypt the capture by itself. Do not export/share private keys as a routine learning exercise. SRTP verification requires its own negotiated-security and call-media evidence.

## Troubleshooting decision table

| First break in the sequence | Inspect next |
|---|---|
| No configuration request | Correct adapter, identity, manual server, routing, application startup |
| Request for wrong SEP name | Selected adapter/MAC or explicitly configured device name |
| Configuration delivered, no CAPF attempt | Install/Upgrade armed, future deadline, LSC Update actually submitted |
| CAPF SYN without SYN-ACK | Route/firewall/listener/service; a timeout alone does not name the blocker |
| CAPF TLS alert | Version, cipher, trust/time and readable alert/logs |
| Enrollment exchange but LSC absent | CAPF operation status and logs; string mismatch is one possibility |
| 5060 REGISTER with expected-TLS warning | Actual loaded configuration and LSC/enrollment state |
| 5061 handshake fails before client cert | Protocol/cipher/server trust, then whether certificate requested |
| Client cert sent, handshake rejected | Identity, issuer trust, validity, key/signature compatibility, CUCM logs |
| TLS succeeds but phone unavailable | SIP-layer behavior and CUCM registration logs/status |
| Registered but cannot call 2099 | CSS/partition, CTI route point, app association, IVR service |
| Call connects but media fails | SDP/media endpoints, negotiated security and UDP routing/firewall |

## Check your understanding

1. Why can a device know DN 2103 while still displaying Registering?
2. Does CTL Installed imply LSC Installed?
3. Must CIPC's local TCP port be 5061?
4. Does CTIManager issue the phone's certificate?
5. Why is a second TLS connection to SUB not sufficient proof of failover?
6. What additional evidence would establish encrypted audio?

<details>
<summary>Answers</summary>

1. Downloaded configuration can provide the DN before registration succeeds.
2. No. The trust list and phone identity certificate have different jobs.
3. No. The successful client used ephemeral source ports to remote 5061.
4. No. CAPF handles LSC enrollment; CTIManager serves application control.
5. Both connections can coexist; active registration requires application-level state or logs.
6. A call's negotiated SRTP/security state plus corresponding media evidence.

</details>
