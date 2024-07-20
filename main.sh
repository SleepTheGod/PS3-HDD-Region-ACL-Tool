#!/bin/bash

# Constants
PS3RAM_DEV="/dev/ps3ram"
PS3HVC_DEV="/dev/ps3hvc"
PS3HVC_HVCALL="ps3hvc_hvcall"
LPAR_ID=1
LAID=0x1070000002000001
HDD_OBJ_FIRST_REG_OBJ_OFFSET=0xb0
REG_OBJ_ACL_TABLE_OFFSET=0x58
NUM_ACL_ENTRIES=8
ACL_ENTRY_SIZE=24
REG_OBJ_SIZE=$((REG_OBJ_ACL_TABLE_OFFSET + NUM_ACL_ENTRIES * ACL_ENTRY_SIZE))

# Functions
ram_read_val_8() {
    local _off=$1
    local _val
    _val=$(dd if="$PS3RAM_DEV" bs=1 count=1 skip="$_off" 2>/dev/null | hexdump -v -e '1/1 "%02x"')
    printf "0x%02x" "$_val"
}

ram_read_val_64() {
    local _off=$1
    local _val
    _val=$(dd if="$PS3RAM_DEV" bs=1 count=8 skip="$_off" 2>/dev/null | hexdump -v -e '1/1 "%02x"')
    printf "0x%016x" "$_val"
}

ram_write_val_64() {
    local _off=$1
    local _val=$2
    printf "$_val" | dd of="$PS3RAM_DEV" bs=1 count=8 seek="$_off" 2>/dev/null
}

hdd_reg_is_valid() {
    local _hdd_obj_off=$1
    local _reg_idx=$2
    local _val
    _val=$(ram_read_val_8 $((_hdd_obj_off + HDD_OBJ_FIRST_REG_OBJ_OFFSET + _reg_idx * REG_OBJ_SIZE + 0x50)))
    echo "$_val"
}

hdd_reg_acl_get_laid() {
    local _hdd_obj_off=$1
    local _reg_idx=$2
    local _acl_idx=$3
    local _val
    _val=$(ram_read_val_64 $((_hdd_obj_off + HDD_OBJ_FIRST_REG_OBJ_OFFSET + _reg_idx * REG_OBJ_SIZE + REG_OBJ_ACL_TABLE_OFFSET + _acl_idx * ACL_ENTRY_SIZE)))
    echo "$_val"
}

hdd_reg_acl_get_access_rights() {
    local _hdd_obj_off=$1
    local _reg_idx=$2
    local _acl_idx=$3
    local _val
    _val=$(ram_read_val_64 $((_hdd_obj_off + HDD_OBJ_FIRST_REG_OBJ_OFFSET + _reg_idx * REG_OBJ_SIZE + REG_OBJ_ACL_TABLE_OFFSET + _acl_idx * ACL_ENTRY_SIZE + 8)))
    echo "$_val"
}

hdd_reg_acl_set_access_rights() {
    local _hdd_obj_off=$1
    local _reg_idx=$2
    local _acl_idx=$3
    local _val=$4
    ram_write_val_64 $((_hdd_obj_off + HDD_OBJ_FIRST_REG_OBJ_OFFSET + _reg_idx * REG_OBJ_SIZE + REG_OBJ_ACL_TABLE_OFFSET + _acl_idx * ACL_ENTRY_SIZE + 8)) "$_val"
}

# Usage menu
usage() {
    echo "Usage: $0 <print|patch|restore>"
    echo
    echo "Commands:"
    echo "  print     Print the ACL entries of the disk storage device"
    echo "  patch     Patch the ACL entries of the disk storage device"
    echo "  restore   Restore the ACL entries of the disk storage device"
    exit 1
}

# Main script
if [ $# -ne 1 ]; then
    usage
fi

case $1 in
    print|patch|restore) ;;
    *) usage ;;
esac

CMD=$1

fw_ver=$($PS3HVC_HVCALL "$PS3HVC_DEV" get_version_info)

# Set STORAGE_SYS_OFFSET based on firmware version
case $fw_ver in
    0x0000000300040001) STORAGE_SYS_OFFSET=0x348300 ;;
    0x0000000300050000) STORAGE_SYS_OFFSET=0x348350 ;;
    0x0000000300050005) STORAGE_SYS_OFFSET=0x34b3b8 ;;
    *) echo "Unsupported firmware version $fw_ver" >&2; exit 1 ;;
esac

STORAGE_SYS_DEV_TABLE_OFFSET=0xee8

# Check for VFLASH
flag=$($PS3HVC_HVCALL "$PS3HVC_DEV" get_repo_node_val "$LPAR_ID" "0x0000000073797300" "0x666c617368000000" "0x6578740000000000" 0 | awk '{ printf $1 }')

if [ "$flag" = "0x00000000000000fe" ]; then
    # VFLASH on
    HDD_REG_LIST="2 3"
else
    # VFLASH off
    HDD_REG_LIST="1 2"
fi

# Get number of storage devices
num_dev=$($PS3HVC_HVCALL "$PS3HVC_DEV" get_repo_node_val "$LPAR_ID" "0x0000000062757304" "0x6e756d5f64657600" 0 0 | awk '{ printf $1 }')
num_dev=$(printf "%d" "$num_dev")

echo "Number of storage devices: $num_dev"

# Get index of disk storage device
echo "Searching for disk storage device ..."

dev_idx=0
found=0
while [ $dev_idx -lt $num_dev -a $found -eq 0 ]; do
    rnv_dev="$(expr substr 0x6465760000000000 1 17)${dev_idx}"

    type=$($PS3HVC_HVCALL "$PS3HVC_DEV" get_repo_node_val "$LPAR_ID" "0x0000000062757304" "$rnv_dev" "0x7479706500000000" 0 | awk '{ printf $1 }')
    if [ "$type" = "0x0000000000000000" ]; then
        found=1
    else
        dev_idx=$(expr $dev_idx + 1)
    fi
done

if [ $found -eq 0 ]; then
    echo "Disk storage device was not found"
    exit 1
fi

echo "Found disk storage device"
echo "Device index: $dev_idx"

# Get ID of disk storage device
dev_id=$($PS3HVC_HVCALL "$PS3HVC_DEV" get_repo_node_val "$LPAR_ID" "0x0000000062757304" "$rnv_dev" "0x6964000000000000" 0 | awk '{ printf $1 }')

echo "Device ID: $dev_id"

# Get number of regions on disk storage device
n_regs=$($PS3HVC_HVCALL "$PS3HVC_DEV" get_repo_node_val "$LPAR_ID" "0x0000000062757304" "$rnv_dev" "0x6e5f726567730000" 0 | awk '{ printf $1 }')
n_regs=$(printf "%d" "$n_regs")

echo "Number of regions: $n_regs"

# Get RAM address of disk storage device object
val=$(ram_read_val_64 "$STORAGE_SYS_OFFSET")
val=$(ram_read_val "$val")
hdd_obj_offset=$(ram_read_val_64 $val)
hdd_obj_offset=$(ram_read_val_64 $((val + $STORAGE_SYS_DEV_TABLE_OFFSET + 8 * dev_id)))

printf "Disk storage device object is at address 0x%x\n" "$hdd_obj_offset"

# Print/patch/restore region ACL entries of disk storage device
for reg_idx in $HDD_REG_LIST; do
    valid=$(hdd_reg_is_valid "$hdd_obj_offset" "$reg_idx")
    if [ "$valid" = "0x01" ]; then
        echo "Region $reg_idx"

        for acl_idx in {0..7}; do
            laid=$(hdd_reg_acl_get_laid "$hdd_obj_offset" "$reg_idx" "$acl_idx")
            access_rights=$(hdd_reg_acl_get_access_rights "$hdd_obj_offset" "$reg_idx" "$acl_idx")

            if [ "$laid" = "$LAID" ]; then
                echo "Found GameOS ACL entry index $acl_idx"

                if [ "$CMD" = "print" ]; then
                    echo "$laid $access_rights"
                elif [ "$CMD" = "patch" ]; then
                    echo "Patching ..."
                    hdd_reg_acl_set_access_rights "$hdd_obj_offset" "$reg_idx" "$acl_idx" '\x00\x00\x00\x00\x00\x00\x00\x02'
                else
                    echo "Restoring ..."
                    hdd_reg_acl_set_access_rights "$hdd_obj_offset" "$reg_idx" "$acl_idx" '\x00\x00\x00\x00\x00\x00\x00\x03'
                fi
            fi
        done
    fi
done
