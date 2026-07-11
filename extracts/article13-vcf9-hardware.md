<!-- Extracted from: vsphere-foundation-vs-vcf-comparison.html -->
<!-- Article: vSphere Foundation vs VCF: Real Pricing and Which One to Deploy (2026) -->
<!-- Sections: VCF 9 minimum hardware requirements and VVF discontinuation risk -->

## VCF 9 Minimum Hardware — The 7-Node Myth

The "7-node minimum" for VCF (4 management + 3 workload) was true for VCF 5.x. VCF 9 changed this.

**VCF 9 actual minimums** (per William Lam's June 2025 lab guide and Broadcom's installer):

- **3 ESXi hosts** when using vSAN (OSA or ESA)
- **2 ESXi hosts** when using external storage (FC VMFS or NFS)
- The old 4-host management domain requirement came from vSAN's need for a fault tolerance host during patching — with VCF 9's updated lifecycle tooling, 3 hosts is a supported minimum for production

If you're doing capacity planning against VCF 5.x docs, re-read the VCF 9 requirements. The floor dropped.

```bash
# VCF 9.0 installer — verify host count pre-check output
# Minimum 3 hosts for vSAN OSA/ESA, 2 for external storage
cat /var/log/vmware/vcf/installer/vcf-installer.log | grep "host-count-validation"
```

That said: running a VCF management domain on 3 nodes with vSAN leaves zero fault tolerance headroom during patching. If a host needs to enter maintenance mode for a VCF lifecycle upgrade, you're down to 2 active vSAN nodes. Minimum 4 hosts is still the right answer for any production cluster you actually care about.

## The VVF Discontinuation Risk

This deserves a direct mention: as of early 2026, multiple r/vmware threads report that Broadcom sales reps are steering customers away from VVF. Some shops are having difficulty getting VVF quoted at all, with reps quoting VCF instead.

A November 2025 r/vmware thread included a rep's statement that "VVF will be phased out within 18 months." Broadcom hasn't made an official announcement, but the pattern matches what happened to vSphere Standard (end-of-sale July 2025 with no replacement below VVF).

If you're building a 3-5 year infrastructure plan, factor this in. VVF might not be available at your next renewal. That's not a reason to overbuy VCF today — if VVF pricing is right for your current environment, use it — but it's a reason to architect for a migration path to VCF without needing to rip out NSX-incompatible network configs when the time comes.
