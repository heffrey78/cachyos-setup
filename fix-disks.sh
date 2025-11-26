#!/usr/bin/env bash
set -euo pipefail

echo "=== Disk Mount Cleanup and Configuration ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo: sudo bash $0"
    exit 1
fi

# Step 1: Unmount the partitions
echo "Step 1: Unmounting partitions..."
umount /run/media/jeffw/Secondary1 2>/dev/null || echo "Secondary1 already unmounted"
umount /run/media/jeffw/b5c3818e-9d0e-4129-9930-e7ae9357ea01 2>/dev/null || echo "nvme1n1p5 already unmounted"
echo "✓ Partitions unmounted"
echo ""

# Step 2: Wipe and format nvme1n1p5 as Tertiary
echo "Step 2: Formatting nvme1n1p5 as Tertiary..."
echo "WARNING: This will ERASE ALL DATA on nvme1n1p5!"
read -p "Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

mkfs.ext4 -F -L Tertiary /dev/nvme1n1p5
echo "✓ nvme1n1p5 formatted with label 'Tertiary'"
echo ""

# Step 3: Create mount points
echo "Step 3: Creating mount points..."
mkdir -p /mnt/Secondary
mkdir -p /mnt/Tertiary
chown jeffw:jeffw /mnt/Secondary
chown jeffw:jeffw /mnt/Tertiary
echo "✓ Mount points created: /mnt/Secondary and /mnt/Tertiary"
echo ""

# Step 4: Get UUIDs
echo "Step 4: Getting partition UUIDs..."
SECONDARY_UUID=$(blkid -s UUID -o value /dev/nvme1n1p2)
TERTIARY_UUID=$(blkid -s UUID -o value /dev/nvme1n1p5)
echo "Secondary UUID: $SECONDARY_UUID"
echo "Tertiary UUID: $TERTIARY_UUID"
echo ""

# Step 5: Add to fstab
echo "Step 5: Adding entries to /etc/fstab..."
# Backup fstab
cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d_%H%M%S)

# Check if entries already exist
if grep -q "$SECONDARY_UUID" /etc/fstab; then
    echo "Secondary entry already exists in fstab"
else
    echo "UUID=$SECONDARY_UUID /mnt/Secondary ext4 defaults,noatime 0 2" >> /etc/fstab
    echo "✓ Added Secondary to fstab"
fi

if grep -q "$TERTIARY_UUID" /etc/fstab; then
    echo "Tertiary entry already exists in fstab"
else
    echo "UUID=$TERTIARY_UUID /mnt/Tertiary ext4 defaults,noatime 0 2" >> /etc/fstab
    echo "✓ Added Tertiary to fstab"
fi
echo ""

# Step 6: Mount the drives
echo "Step 6: Mounting drives..."
mount /mnt/Secondary
mount /mnt/Tertiary
echo "✓ Drives mounted"
echo ""

# Step 7: Verify
echo "Step 7: Verification..."
df -h | grep -E "(Secondary|Tertiary)"
echo ""
echo "=== Setup complete! ==="
echo ""
echo "Your drives are now mounted at:"
echo "  - /mnt/Secondary (nvme1n1p2, 953.9G)"
echo "  - /mnt/Tertiary (nvme1n1p5, 949.1G)"
echo ""
echo "They will auto-mount at boot."
