<!-- Extracted from: how-to-build-a-vmware-home-lab-on-a-budget.html -->
<!-- Article: How to Build a VMware Home Lab on a Budget (2026 Edition) -->
<!-- Sections: Part 3 (Proxmox nested virtualization) and Part 4 (Storage architecture) -->

## Part 3: The Hybrid Proxmox + VMware Strategy

Here's where budget lab builders get serious use: run **Proxmox VE as your bare-metal hypervisor**, and run ESXi (or vCenter + ESXi) as nested VMs *inside* Proxmox.

### Why This Works

**Proxmox VE** (current release: 8.x, Debian-based, Apache 2.0 licensed) gives you:

- Unlimited VMs and vCPUs — no licensing caps whatsoever
- LXC containers for lightweight Linux services (Pi-hole, Home Assistant, etc.)
- ZFS storage with checksumming and easy snapshots
- Built-in clustering, live migration, and HA for *Proxmox-managed* VMs
- A free web UI that's genuinely excellent

The strategy:

1. Install Proxmox VE on your physical hardware (bare metal)
2. Run general services (DNS, NAS, containers) directly on Proxmox
3. Create a dedicated "VMware Training" VM group: one or more nested ESXi hosts + nested vCenter
4. Use VMUG Advantage licenses for your nested vCenter + ESXi VMs
5. Practice vMotion, HA, DRS, vSAN — all inside Proxmox VMs

This gives you a complete enterprise VMware lab without dedicating physical hardware exclusively to VMware.

### Enabling Nested Virtualization on Proxmox

On the Proxmox host (bare metal), enable nested KVM before creating your VMware VMs:

```bash
# For Intel CPUs
echo "options kvm-intel nested=Y" > /etc/modprobe.d/kvm-intel.conf
update-initramfs -u -k all

# For AMD CPUs
echo "options kvm-amd nested=1" > /etc/modprobe.d/kvm-amd.conf
update-initramfs -u -k all

# Verify after reboot
cat /sys/module/kvm_intel/parameters/nested  # should output: Y
# or for AMD:
cat /sys/module/kvm_amd/parameters/nested    # should output: 1
```

> **Note:** Use `kvm-intel` for Intel and `kvm-amd` for AMD — they are separate kernel modules with different conf file names. The original generic `kvm` module approach in many older guides is unreliable.

In the Proxmox GUI, for each ESXi VM:

1. Go to VM → Hardware → Processor
2. Enable **"Virtualize Intel VT-x/EPT"** (or AMD equivalent)
3. Set CPU type to `host` for best compatibility

### Installing Proxmox VE

```bash
# After installation, verify version
pveversion -v

# Update your Proxmox node (use community repo if no subscription)
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" \
  > /etc/apt/sources.list.d/pve-install-repo.list
apt update && apt full-upgrade -y
```

## Part 4: Storage Architecture for Labs

Storage mistakes are the #1 cause of lab performance frustration. Here's the hierarchy:

### Recommended Layout

```
Physical Host
├── /dev/nvme0n1  →  Boot disk (Proxmox OS + config) — 128GB NVMe
├── /dev/nvme1n1  →  VM fast storage (ZFS pool or LVM) — 1TB NVMe
│   ├── VMware nested lab VMs
│   └── vCenter appliance VMDK
└── /dev/sda      →  Bulk/archive storage — 2TB+ HDD
    └── ISO library, snapshots, backups
```

### ZFS vs LVM-thin

| | ZFS | LVM-thin |
|--|-----|----------|
| Snapshots | Fast, space-efficient | Fast, space-efficient |
| Data integrity | Checksumming + scrubbing | No checksumming |
| RAM requirement | ~1GB per TB (ARC cache) | Minimal |
| Best for | Production-like VMs, data safety | Maximum IOPS, minimal overhead |

**Recommendation:** ZFS for VM data if you have 32GB+ host RAM. LVM-thin if RAM is scarce and IOPS matter more.

```bash
# Check disk I/O health — useful when diagnosing slow VMs
iostat -x 1 5
# Look for: high %util (>80% sustained), or await >10ms on your SSD
```
