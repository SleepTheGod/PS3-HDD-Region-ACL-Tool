# PS3 HDD Region ACL Tool

This script allows you to print, patch, or restore the region ACL entries of the disk storage device on a PlayStation 3. It interacts with the PS3 RAM and HVC devices to read and modify the necessary values.

# Usage
./ps3_acl_tool.sh <print|patch|restore>

# Commands
print: Display the current ACL entries.
patch: Modify the ACL entries to a specific value.
restore: Restore the ACL entries to their original value.

# Example
./ps3_acl_tool.sh print

# Constants
PS3RAM_DEV: Path to the PS3 RAM device.
PS3HVC_DEV: Path to the PS3 HVC device.
PS3HVC_HVCALL: HV call command for PS3 HVC device.
LPAR_ID: Logical partition ID.
LAID: Logical address ID.
HDD_OBJ_FIRST_REG_OBJ_OFFSET: Offset for the first region object in the HDD object.
REG_OBJ_ACL_TABLE_OFFSET: Offset for the ACL table in the region object.
NUM_ACL_ENTRIES: Number of ACL entries.
ACL_ENTRY_SIZE: Size of each ACL entry.
REG_OBJ_SIZE: Total size of the region object.

# Functions
ram_read_val_8: Read an 8-bit value from the PS3 RAM device.
ram_read_val_64: Read a 64-bit value from the PS3 RAM device.
ram_write_val_64: Write a 64-bit value to the PS3 RAM device.
hdd_reg_is_valid: Check if the HDD region is valid.
hdd_reg_acl_get_laid: Get the logical address ID of an ACL entry.
hdd_reg_acl_get_access_rights: Get the access rights of an ACL entry.
hdd_reg_acl_set_access_rights: Set the access rights of an ACL entry.

# Script Details
The script performs the following steps
Determines the PS3 firmware version and sets the storage system offset accordingly.
Checks if VFLASH is enabled.
Retrieves the number of storage devices and identifies the disk storage device.
Reads the RAM address of the disk storage device object.
Prints, patches, or restores the ACL entries for each region of the disk storage device.
Requirements
Access to the PS3 RAM and HVC devices.
Appropriate permissions to read and write to the PS3 RAM device.

# Notes
The script assumes specific offsets and values based on the PS3 firmware version. It may not work on all firmware versions.
Use this script with caution, as modifying ACL entries can affect the system's functionality.

# Disclaimer
# This script is provided for educational purposes only. Use it at your own risk. The author is not responsible for any damage caused by using this script.
