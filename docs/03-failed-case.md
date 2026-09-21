# Case A: no LSC installed, secure configuration, plain TCP registration

[Learning path](../README.md) · [Next: successful case](04-success-case.md)

**Observed outcome:** registration rejected. This is a missing-LSC/pre-enrollment state, not evidence of an expired or incorrectly signed LSC. No LSC was installed to inspect.

## State before the fix

| Item | Observed or anonymized value | Interpretation |
|---|---|---|
| Phone identity | SEP020000000301 (generic) | Must correspond to actual CUCM record in a real lab |
| Line | 2103 | Displayed DN does not prove registration |
| CTL | Downloaded; phone displayed a CTL entry | A trust file and an LSC serve different purposes |
| LSC status | Not Installed | Phone lacked its enrolled identity certificate |
| CAPF server | 192.168.10.150:3804 | Configured target does not prove enrollment was initiated |
| Configuration deviceSecurityMode | 3 | Download requested Encrypted mode |
| Configuration certHash | Empty | Corroborates missing certificate state; not a standalone certificate test |
| Actual registration transport | TCP to 5060 | Did not satisfy CUCM's expected TLS policy |

The client temporarily showed Authenticated in a later screenshot. Changing Encrypted to Authenticated did not install an LSC. Do not combine screenshots from different moments as if they were one immutable state.

## Packet walkthrough

Source: private failure capture, 6,071 frames over approximately 572.787 seconds. These frame numbers apply only to that file.

| Frame(s) | What happened | What it proves / next question |
|---|---|---|
| 1646–1648 | TCP connection to PUB 6970 | Configuration service reachable |
| 1649 → 1651 | GET generic CTL filename → HTTP 200 | CTL bytes delivered; signature validation not established by HTTP status |
| 1667 → 1668 | GET generic signed phone configuration → HTTP 200 | Phone received its configuration |
| Configuration payload | deviceSecurityMode=3, transportLayerProtocol=3, voipControlPort=5061, CAPF 3804, empty certHash | Secure intent was present in downloaded data |
| 2997 / 2998 | Connection attempts to PUB/SUB TCP 5060 | Client attempted the non-TLS SIP destination |
| 3003 | REGISTER to PUB, Via TCP | Actual request contradicted secure intent |
| 3005 | 100 Trying | Provisional processing, not acceptance |
| 3008 | 403 Forbidden with security-mismatch warning | Explicit reason: expected TLS, received TCP/UDP |
| 3257 → 3263 | Repeated PUB REGISTER and rejection | Failure persisted |
| 3268 → 3272 | SUB REGISTER and matching rejection | Changing node did not remove the same policy mismatch |
| Whole PC3 capture | No TCP 3804 or 5061 traffic | No captured CAPF enrollment or secure SIP attempt |

Sanitized representative excerpt; not a complete raw SIP packet:

```text
REGISTER sip:192.168.10.150 SIP/2.0
Via: SIP/2.0/TCP 192.168.20.52:<client-source-port>
Device identity: SEP020000000301
Directory number: 2103

SIP/2.0 403 Forbidden
Warning: 399 CUCM-PUB "Device security mismatch: expected TLS, received TCP/UDP"
```

**Diagnosis boundary:** the 403 directly proves the transport mismatch. The missing-LSC display and absent enrollment traffic explain the unfinished certificate prerequisite. The capture does not expose every internal CIPC decision that led it to use 5060.

## Correction and validation

1. Verify CAPF is Started on PUB and the phone record/identity match.
2. Arm Install/Upgrade with By Authentication String and a future deadline.
3. Save/Apply Config; enter the generated private string under CIPC Security Configuration → LSC → Update (unlock with `**#` where required).
4. Verify LSC Installed and CUCM operation status.
5. Allow reload/restart and verify TCP 5061, client Certificate, CertificateVerify, completed handshakes and encrypted application data.
6. Check CUCM Registered separately.

Do not repair this by moving 2103 into the services partition, adding Standard CTI Enabled to the end user, changing the auto-registration pool, or removing the security profile just to suppress the rejection.

## A different failure students should recognize

An installed LSC can still fail because it is expired, not yet valid, untrusted, mismatched to the device, or incompatible with the peer's algorithms. Those would require certificate/TLS-alert/log evidence. **They were not the failure demonstrated here.** A wrong authentication string is another possible enrollment failure, but was not proven in this trace.

See [generic failed-state JSON](../examples/failure.json).
