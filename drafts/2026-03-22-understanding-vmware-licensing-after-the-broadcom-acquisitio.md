# Meta Description
Navigate the changes in VMware licensing following Broadcom's acquisition. Covers the shift from perpetual to subscription models, vCPU-based pricing mechanics, product name consolidation, and managing entitlements on the Broadcom Support Portal.

---

# Understanding VMware Licensing After the Broadcom Acquisition

## What Changed and Why It Matters

Broadcom acquired VMware in late 2023. The licensing model that followed is different from the VMware licensing model that preceded it in nearly every respect: pricing basis, contract structure, product naming, and procurement portal.

The headline change: **perpetual licenses are gone for new contracts.** VMware now sells subscriptions only. The per-socket pricing model is also gone, replaced by vCPU-based pricing. And the familiar product names — vSphere Standard, vSphere Enterprise Plus, NSX Advanced Load Balancer, standalone vSAN — have been consolidated into broader bundles, primarily organized around VMware Cloud Foundation (VCF).

These changes affect budgeting, procurement workflow, and how administrators think about VM sizing. A VM with 8 vCPUs costs more to license than one with 4 vCPUs, which was not true under per-socket licensing.

## The Pricing Model: Per-Socket to vCPU

### How Per-Socket Worked

Under the old model, you bought licenses per physical CPU socket. A dual-socket server with 128 total cores cost the same as a dual-socket server with 16 total cores — two socket licenses either way. The number of VMs and their vCPU allocations did not affect the license cost.

### How vCPU-Based Pricing Works

Licensing is now based on the total number of virtual CPUs assigned to powered-on VMs.

*   A host with 128 physical cores running VMs that total 64 vCPUs is licensed for 64 vCPUs.
*   The same host running VMs totaling 100 vCPUs is licensed for 100 vCPUs.
*   This means VM right-sizing has a direct financial impact. Over-allocated VMs — the ones with 8 vCPUs that never use more than 2 — now cost real money in licensing overhead.

The flip side: if you run fewer, well-sized VMs, the vCPU model can cost less than the old per-socket model did for underutilized hosts. Whether that applies to your environment depends on your VM density and allocation patterns.

## Subscription Terms and Perpetual License Migration

All new contracts are subscription-based, available in 1, 3, or 5-year terms.

If you hold a perpetual license from before the acquisition, it still functions — your software does not stop working. What changes is support access. To continue receiving patches, updates, and VMware support, you must transition to a subscription via the Broadcom Support Portal. The annual maintenance fee you were paying is effectively replaced by the subscription cost, though the pricing is not a 1:1 conversion.

Broadcom has set migration timelines for existing perpetual license holders. If you have not already checked your specific deadline, do so on the MyBroadcom portal under your account's entitlements.

## Product Name Consolidation

The product catalog has been restructured. Long-time VMware administrators will not find the names they are used to.

**What happened to specific products:**

*   **vSphere Standard and Enterprise Plus** are now mapped to a base "Compute" tier within the subscription model. The feature set you get depends on which tier you subscribe to. DRS, vMotion, and Fault Tolerance — previously Enterprise Plus features — are now gated by subscription tier rather than standalone SKU.
*   **NSX, vSAN, and HCX** are no longer always sold as separate line items. They are bundled into higher-tier subscriptions or sold as "Service Units" added to your base compute subscription.
*   **Service Units** are the new granular pricing element. Each service unit represents a capability — advanced networking, storage management, etc. Your total cost is the compute subscription plus whatever service units your environment requires.

The practical effect: you cannot buy "vSAN" by itself anymore for a new deployment. You buy a subscription tier that includes it, or you add it as a service unit. The exact mapping between old SKUs and new tiers changes periodically — check with your Broadcom account representative for current pricing.

## The Broadcom Support Portal (MyBroadcom)

All licensing activity has moved from the VMware Customer Connect portal to **MyBroadcom** at `support.broadcom.com`.

### Setting Up Access

1.  **Create an account** at `support.broadcom.com` if you do not have one.
2.  **Link your entitlements.** You need either your old VMware Customer ID or your new Broadcom contract number. The portal should prompt you to migrate existing perpetual licenses if applicable.
3.  **Generate license keys** under the **Entitlements > Licenses** section. The new keys are structured differently from the old VMware keys — a serial number from your previous license will not work in the new system.

```powershell
# PowerShell Example: Checking entitlement status via API (Conceptual)
# Note: This requires valid Broadcom API credentials and authentication tokens.
$ApiToken = Get-BroadcomAuthToken -Username "admin@company.com" -Password "SecurePassword123"
$Entitlements = Invoke-RestMethod -Uri "https://support.broadcom.com/api/v1/entitlements" -Headers @{ "X-Auth-Token" = $ApiToken }

Write-Host "Current Subscriptions:"
$Entitlements | Format-Table Name, Status, ExpiryDate
```

[SCREENSHOT: Screenshot of the MyBroadcom dashboard showing the 'Entitlements' tab and a list of active subscriptions]

### Calculating vCPU-Based Costs for New Deployments

To estimate your licensing cost under the new model:

1.  **Inventory your vCPU allocation.** Sum the vCPU count across all powered-on VMs. You can do this from the vCenter Inventory or with the script below.
2.  **Identify the subscription tier** that covers the features you need.
3.  **Request a quote** from your Broadcom sales representative with the total vCPU count and desired subscription duration.

```bash
# Bash Example: Calculating total vCPUs from a CSV export of VM inventory
#!/bin/bash

# Assume 'vm_inventory.csv' has columns: VM_Name, Num_VCPUs, Status
total_vcpus=0

while IFS=',' read -r vm_name vcpus status; do
    # Skip header row
    if [[ "$vm_name" == "VM_Name" ]]; then continue; fi

    # Only count powered-on VMs (assuming 'PoweredOn' is the status)
    if [[ "$status" == "PoweredOn" ]]; then
        total_vcpus=$((total_vcpus + vcpus))
    fi
done < vm_inventory.csv

echo "Total vCPUs requiring license coverage: $total_vcpus"
```

[SCREENSHOT: Screenshot of the Broadcom Licensing Calculator interface showing vCPU inputs and estimated annual cost]

## Troubleshooting Licensing Issues

### "License Server Not Found" or Activation Failures

**Symptom:** vCenter displays `license_server_not_found` or `invalid_license` after an environment update.

**Cause:** The new license keys use a different structure than the old VMware keys. An old serial number will not activate under the new system.

**Fix:**
1.  Log in to **MyBroadcom**.
2.  Navigate to **Entitlements > Licenses**.
3.  Generate a new license key (not the old serial number).
4.  In vCenter, go to **Administration > Licensing > Manage Licenses** and enter the new key.
5.  If using an embedded license server, restart the license service:
    ```bash
    systemctl restart vmware-lm
    ```

### Cannot Find a Product in the Broadcom Catalog

**Symptom:** Searching for "vSphere Enterprise Plus" or "vSAN" in the Broadcom catalog returns no results.

**Cause:** These product names have been retired. The features they represented are now part of bundled subscription tiers.

**Fix:** Identify the specific features you need (DRS, vMotion, Fault Tolerance, software-defined storage, etc.) and map them to the corresponding Compute Service Unit tier. Your Broadcom account representative can provide the current mapping, which has changed since the initial post-acquisition catalog.

### Unexpectedly High Licensing Costs

**Symptom:** Your invoice under the new model is significantly higher than what you paid under per-socket licensing.

**Cause:** vCPU-based pricing charges for every virtual core allocated to powered-on VMs. Environments with many over-provisioned VMs — machines allocated 8 vCPUs that average 5% utilization — accumulate licensing cost on unused capacity.

**Fix:**
1.  Run a vCPU allocation audit. Identify VMs where the allocated vCPU count significantly exceeds actual utilization. vCenter performance charts or vRealize Operations can show CPU demand vs. allocation.
2.  Right-size the over-allocated VMs. Reducing a VM from 8 vCPUs to 4 cuts its licensing cost in half.
3.  Power off or delete VMs that are no longer in use. Powered-off VMs do not count toward the licensed vCPU total.

## What This Means Going Forward

The shift to subscription-based, vCPU-driven pricing is permanent for new VMware contracts. The financial incentive structure has changed: under per-socket licensing, there was no cost penalty for over-allocating vCPUs. Under the current model, there is.

Organizations that have not yet audited their vCPU allocations should do so before their next renewal. The difference between actual utilization and allocated capacity is now a line item on your invoice.

**Immediate actions:**
*   Verify your MyBroadcom account is set up and entitlements are linked.
*   Check your perpetual license migration deadline if applicable.
*   Run a vCPU inventory and compare it to your actual workload requirements.
*   Talk to your Broadcom representative about tier selection before your next contract renewal — the tier structure and pricing have continued to evolve since the initial post-acquisition rollout.

[SCREENSHOT: A checklist graphic titled 'Post-Transition Action Plan' summarizing the steps above]