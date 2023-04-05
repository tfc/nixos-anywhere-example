{ lib, ... }:
{
  disk = lib.genAttrs [ "/dev/nvme0n1" "/dev/nvme1n1" ]
    (disk: {
      type = "disk";
      device = disk;
      content = {
        type = "table";
        format = "gpt";
        partitions = [
          {
            name = "boot";
            type = "partition";
            start = "0";
            end = "1M";
            part-type = "primary";
            flags = [ "bios_grub" ];
          }
          {
            type = "partition";
            name = "ESP";
            start = "1M";
            end = "1GiB";
            fs-type = "fat32";
            bootable = true;
            content = {
              type = "mdraid";
              name = "boot";
            };
          }
          {
            type = "partition";
            name = "nixos";
            start = "1GiB";
            end = "100%";
            content = {
              type = "mdraid";
              name = "nixos";
            };
          }
        ];
      };
    }) // (lib.genAttrs [ "/dev/sda" "/dev/sdb" ] (disk: {
    type = "disk";
    device = disk;
    content = {
      type = "table";
      format = "gpt";
      partitions = [
        {
          type = "partition";
          name = "varlib";
          start = "0";
          end = "100%";
          part-type = "primary";
          content = {
            type = "mdraid";
            name = "varlib";
          };
        }
      ];
    };
  }));
  mdadm = {
    boot = {
      type = "mdadm";
      level = 1;
      metadata = "1.0";
      content = {
        type = "filesystem";
        format = "vfat";
        mountpoint = "/boot";
      };
    };
    nixos = {
      type = "mdadm";
      level = 1;
      content = {
        type = "filesystem";
        format = "ext4";
        mountpoint = "/";
      };
    };
    varlib = {
      type = "mdadm";
      level = 1;
      content = {
        type = "filesystem";
        format = "ext4";
        mountpoint = "/var/lib";
      };
    };
  };
}
