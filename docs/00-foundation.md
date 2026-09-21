# Foundation: build the objects without another repository

[Start](../README.md) · [Next: command and decision runbook](08-command-runbook.md)

This lab manually precreates one SIP/TLS phone, enrolls an LSC and verifies its secure connection. Auto-registration and IVR self-provisioning are alternative onboarding mechanisms, not prerequisites for this endpoint. The optional provisioning section below explains those objects so students can understand the preceding lab without running it.

## 1. Network and time

| Component | Address / setting | Why |
|---|---|---|
| Client / PC3 | 192.168.20.52/24, gateway 192.168.20.1 | DATA VLAN 20 endpoint |
| PUB | 192.168.10.150, cucm-pub.ccie.collab | Configuration/CAPF and preferred lab call processor |
| SUB | 192.168.10.151, cucm-sub.ccie.collab | Alternate call processor |
| DNS / AD | 192.168.10.157, CCIE.COLLAB | Authoritative lab names and users |
| Phone NTP references | 192.168.10.1 and .2 | Lab phone time-source configuration |
| Generic device identity | 02:00:00:00:03:01 → SEP020000000301 | Example only; substitute the actual selected adapter identity |

VLAN 20 used a Windows DHCP scope .50–.225, exclusions .61–.69, router .20.1 and DNS .10.157. The SVI helper pointed to .10.157. No DHCP option 150 was used on this data VLAN; CIPC's configuration-server IP was entered manually. If your client has a static address instead, do not recreate DHCP just for TLS.

Check routing from VLAN 20 to VLAN 10. DNS should resolve PUB/SUB to .150/.151. CIPC and CUCM certificate checks need valid clocks. CUCM OS NTP, Windows time and Phone NTP Reference are different configuration contexts. A +05:30 display setting does not synchronize time.

## 2. Partitions and calling search spaces

**Call Routing → Class of Control → Partition → Add New**. Multiline creation:

```text
PT-HQ-INTERNAL,HQ permanent extensions
PT-HQ-SERVICES,HQ provisioning services
PT-HQ-AUTOREG,HQ temporary auto registration
```

Save with Time Schedule None. Partitions are routing namespaces; this action does not create DNs or reserve ranges.

**Call Routing → Class of Control → Calling Search Space → Add New**:

| CSS | Selected partitions in order | Use |
|---|---|---|
| CSS-HQ-INTERNAL | PT-HQ-INTERNAL; PT-HQ-SERVICES | PC3 final phone/line access |
| CSS-HQ-AUTOREG | PT-HQ-SERVICES only | Optional restricted staging phones |

Place **2103** in INTERNAL and optional IVR **2099** in SERVICES. A calling phone reaches 2099 through its effective line/device CSS; moving 2103 to SERVICES is not the fix. Both line and device CSS can affect calling permissions; a broad line CSS can defeat an intended restricted staging policy.

**Verify/next:** inspect Selected Partitions and save; then create the CM group. A CSS error concerns call routing, not the TLS handshake.

## 3. CM group, time group and device pool

1. **System → Cisco Unified CM Group → Add New**: CMG-HQ-LAB; PUB first, SUB second. Keep auto-registration group selection outside this manual-PC3 procedure. Server order is the lab choice.
2. **System → Phone NTP Reference → Add New**: one reference for .10.1 and one for .10.2, unicast for reproduction.
3. **System → Date/Time Group → Add New**: DTG-HQ-INDIA; India UTC+05:30; separator `/`; day/month/year; 24-hour; Add Phone NTP References, select the two sources and save.
4. **System → Device Pool → Add New**: DP-HQ-INDIA; CMG-HQ-LAB; DTG-HQ-INDIA; Default region. The pool's Auto-registration CSS can be CSS-HQ-AUTOREG for a separate staging design; the manually created phone gets CSS-HQ-INTERNAL explicitly.
5. On the phone select Hub_None for this lab's location.

**Verify/next:** open the saved pool and check actual references. Creating objects does not bind them to a phone until selected. Continue with user identity, then the security runbook.

## 4. LDAP user: reuse first, create only if absent

The TLS session used **ONPREM** (display label “ON PREM 1”). Owner/User ID and display name are not necessarily identical. Use the actual CUCM User ID.

If LDAP is already functioning, open **User Management → End User**, find ONPREM and preserve synchronization. If starting from a fresh lab:

1. Activate/start Cisco DirSync on the intended synchronization node.
2. **System → LDAP → LDAP System**: enable synchronization; Microsoft Active Directory; User ID attribute sAMAccountName.
3. **System → LDAP → LDAP Directory**: use server .10.157, a privately entered authorized bind account, and your actual search base. Example for a dedicated OU: `OU=HQ-CIPC-LAB,DC=CCIE,DC=COLLAB`; create/use it only if that OU exists.
4. Configure the directory transport to match your deployment (LDAP/LDAPS), mappings and schedule. The original TLS evidence does not establish the exact LDAP transport or search base.
5. Save, perform a full sync, verify the user status. LDAP password authentication is a separate configuration from synchronization.
6. After creating PC3's line, set Controlled Device to the correct PC3 device, Primary Extension 2103/PT-HQ-INTERNAL, and optionally Self-Service ID 2103. Keep the private PIN private.

A manually configured local CUCM end user is another valid lab ownership approach when LDAP is outside scope; do not convert an existing synchronized account merely to make TLS work. Neither LDAP sync nor the PIN enrolls an LSC.

## 5. Optional provisioning objects, explained independently

These explain the earlier exercise. **Skip to the security runbook for the manually precreated PC3.**

| Object / menu | Values used in the earlier exercise | Role and verification |
|---|---|---|
| User Management → User/Phone Add → Universal Line Template | ULT HQ Users; PT-HQ-INTERNAL; CSS-HQ-INTERNAL; external mask blank | Defaults for created lines; verify resulting DN/partition |
| Same area → Universal Device Template | UDT HQ Users; DP-HQ-INDIA; Standard SIP Profile; compatible universal security profile | Defaults for created devices; actual model-specific security profile must be verified after provisioning |
| User Management → User Settings → User Profile | HQ Users User Profile; UDT/ULT above; Allow End User to Provision own phones; limit 1 for the earlier single-phone exercise | User provisioning policy; an already-owned phone can affect IVR behavior |
| User/Phone Add → Feature Group Template | Example FGT-HQ-USERS, chosen User Profile and end-user access settings | Defaults used when directory users are initially inserted; not a guaranteed update of existing users |
| Device → CTI Route Point | CTIRP-SELFPROV; DP-HQ-INDIA; DN 2099/PT-HQ-SERVICES | Application-controlled IVR destination |
| User Management → Application User | Piyush@self; controlled CTIRP-SELFPROV; Standard CTI Enabled | Application authorization, distinct from ordinary phone owner |
| User Management → Self-Provisioning | Route point/app above; user Password/PIN authentication; English US | Connects IVR service to its application/device |

Phone descriptions used template tags `#FN##LN#-#ID#`. Literal tags on a phone are not evidence that user substitution/provisioning completed. Use the editor's supported tag syntax. Never bind a reusable line template to an arbitrary existing DN just because it appears in a dropdown.

The speed dial **Self-Provision / 2099** may occupy button 2 in the demonstrated universal button template or button 3 in Standard CIPC SIP (which has two line slots). It is not a third directory number.

Auto-registration requires deliberate node/group/protocol/templates/range configuration in a compatible cluster state. The earlier observed range was **1001–11000**, with phone DN **1003**; **2900–2910** was a restricted future design. Do not label the plan as observed. PC3's manual **2103** is independent of both ranges. Mixed mode changes the secure onboarding context; do not assume an existing auto-registration plan remains the way to create secure phones.

## 6. Keep the four identities separate

| Identity | Example | What it does |
|---|---|---|
| Device identity | SEP020000000301 | Selects phone record/configuration and certificate identity |
| Calling identity | 2103 / ONPREM display | Directory number and caller presentation |
| End-user identity | ONPREM; Self-Service ID 2103 | Ownership/provisioning/user services |
| Certificate identity | Synthetic CN=SEP020000000301 | Authenticates the phone during TLS |

Matching a Self-Service ID to the DN is convenient, not how CIPC finds its configuration. An IVR PIN, LDAP password, CAPF string and certificate private key have different purposes.

**Next:** [execute the security checkpoints](08-command-runbook.md), then [create/apply the profile and phone](01-deployment.md).
