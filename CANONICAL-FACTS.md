# VMware 2026 Canonical Facts — Single Source of Truth
# All articles must reference these numbers. Last verified: July 11, 2026.
# Sources listed inline.

## Pricing (MSRP / List)

| Product | Price | Term | Source |
|---------|-------|------|--------|
| VCF (Cloud Foundation) | $350/core/year | list | Rimini Street estimator, Veeam community blog, Broadcom KB |
| VVF (vSphere Foundation) | $190/core/year | 1-year MSRP | Reddit VAR r/vmware Aug 2025 |
| VVF (vSphere Foundation) | $150/core/year | 3-year MSRP | Reddit VAR r/vmware Aug 2025 |
| VVF (vSphere Foundation) | $135/core/year | average list | Rimini Street estimator |
| vSphere Standard | $50/core/year | subscription | Rimini Street estimator |
| vSphere Enterprise Plus | $150/core/year | subscription | Reddit VAR r/vmware |

**How to use in articles:** "VVF list pricing ranges from $135/core/year (average) to $190/core/year (1-year MSRP), with discounts for multi-year terms ($150/core/year for 3-year)."

## Product Status

| Product | Status | Notes |
|---------|--------|-------|
| vSphere Standard | EXISTS | $50/core/year subscription. One of four bundles. NOT discontinued. |
| vSphere Enterprise Plus | EXISTS | $150/core/year subscription. One of four bundles. |
| VVF (vSphere Foundation) | EXISTS | $135-190/core/year depending on term. |
| VCF (Cloud Foundation) | EXISTS | $350/core/year. Reduced from $700 at acquisition. |
| Perpetual licenses | ENDED | No new perpetual sales since early 2024. Existing perpetual + SnS still honored. |

Source: Storware, Novacloud — "four primary bundles: VCF, VVF, vSphere Standard, vSphere Enterprise Plus"

## Core Minimums

| Rule | Status | Details |
|------|--------|---------|
| 16-core per CPU socket | ACTIVE | Every physical CPU socket licensed for minimum 16 cores. |
| 72-core per order minimum | NUANCED | Introduced April 2025. Partially reversed for some existing renewals late 2025. STILL APPLIES to new orders, subscription transitions, and tier changes. Sources: securityonline.info, licenseware.io, communicat.com.au |

**How to use in articles:** "Broadcom introduced a 72-core per-order minimum in April 2025. After industry backlash, they partially reversed it for some existing renewals, but it still applies to new orders and tier changes. Verify with your reseller."

## vSAN Entitlements

| Product | Entitlement | Source |
|---------|-------------|--------|
| VVF | 0.25 TiB (250 GiB) per core | Broadcom KB #313548, increased from 100 GiB as of Nov 2024 (vSphere 8.0U3e) |
| VCF | 1 TiB per core | Broadcom KB #313548 |

**IMPORTANT:** Both "100 GiB" and "0.25 TiB" are technically correct depending on date. Pre-Nov 2024 = 100 GiB. Post-Nov 2024 = 250 GiB (0.25 TiB). Use 0.25 TiB for current accuracy.

## Kubernetes Naming

| Old Name | Current Name | Notes |
|----------|-------------|-------|
| Tanzu Kubernetes Grid (TKG) | vSphere Kubernetes Service (VKS) | VCF 9 rebranded. Still commonly called "Tanzu" informally. |
| Tanzu Mission Control | Still used | Separate product, not bundled in VVF. |

## Subscription Enforcement

If you stop paying: You lose updates, support, and upgrade rights. The software does NOT immediately stop working, but you are out of compliance and cannot receive patches or support. Continued use depends on your contract terms.

Source: Broadcom subscription model documentation

## Proxmox VE 9.0

Released: August 5, 2025 (CONFIRMED)
Based on: Debian 13 "Trixie", kernel 6.14.8-2
Source: proxmox.com press release
