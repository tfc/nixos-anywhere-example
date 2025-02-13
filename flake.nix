{
  description = "Example NixOS deployment via NixOS-anywhere";

  inputs = {
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixos-configs.url = "github:tfc/nixos-configs";
  };

  outputs = { self, nixpkgs, disko, home-manager, nixos-configs, ... }: {
    nixosConfigurations.hetzner-cloud = nixpkgs.lib.nixosSystem {
      modules = [
        ({modulesPath, ... }: {
          imports = [
            (modulesPath + "/profiles/qemu-guest.nix")
            disko.nixosModules.disko
            nixos-configs.nixosModules.user-tfc
            nixos-configs.nixosModules.remote-deployable
            nixos-configs.nixosModules.flakes
            home-manager.nixosModules.home-manager
          ];

          nixpkgs.hostPlatform = "aarch64-linux";
          nixpkgs.config.allowUnfree = true;
          disko.devices = import ./single-gpt-disk-fullsize-ext4.nix "/dev/sda";
          boot.loader.grub = {
            devices = [ "/dev/sda" ];
            efiSupport = true;
            efiInstallAsRemovable = true;
          };

          networking.hostName = "nxbd";
          networking.domain = "nix-consulting.de";

          services.openssh.enable = true;
          users.users.root.openssh.authorizedKeys.keys = [
            "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCXfQnzmqFQsUPwJm1sQSh2A7HH1YxO6OOOn1r2QR/PqwVIRu1rOzAC5IXPKmaIN770dLIJzQMqQoUr3ih/x+zweEyUqJTP0sIjA8l9lJNj0S6xVZ594ci/C6w9fR9uKRmXIk7r6usaqTF0Jdf02Al0tB0Lv4Aqi2b6VNPLO3LT162ZuRpcqSDIZzmQg+lkd0s1jWnJGdX5s7G959ouvID5xx7g/e31M/p4PJFvdEtmZ0YGTqju+STyOvX56GvQKRlRRYVFwwTyC1KUr0fJ31dM0DjZoIrfbeY+MBO6JXT23x6iU2sywqxmrDrRphu3raLI/Y2PhopO0q7DutAoolgV cardno:6444835"
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF0iyQuS7BycsHPZCLpkl0ojyiRn2GCPwNhtFjdnwHZx jacek@galowicz.de"
          ];


          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.tfc = { ... }: {
            imports = [
              nixos-configs.homeManagerModules.vim
              nixos-configs.homeManagerModules.tmux
              nixos-configs.homeManagerModules.shelltools
            ];
            home.stateVersion = "24.11";
            programs.home-manager.enable = true;
          };
        })
      ];
    };

    "hetzner-dedicated" = nixpkgs.lib.nixosSystem rec {
        modules = [
          ({modulesPath, ... }: {
            imports = [
              disko.nixosModules.disko
            ];
            disko.devices = import ./two-raids-on-two-disks.nix;

            boot.loader.grub = {
              copyKernels = true;
              devices = [ "/dev/nvme0n1" "/dev/nvme1n1" ];
              efiInstallAsRemovable = true;
              efiSupport = true;
              enable = true;
              fsIdentifier = "uuid";
              version = 2;
            };
            boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "sd_mod" ];

            nixpkgs.hostPlatform = "x86_64-linux";
            powerManagement.cpuFreqGovernor = "ondemand";
            hardware.cpu.intel.updateMicrocode = true;
            hardware.enableRedistributableFirmware = true;

            networking.hostName = "foo";
            networking.fqdn = "bar";

            # Most of this is inspired by existing scripts:
            # https://github.com/nix-community/nixos-install-scripts/tree/master/hosters/hetzner-dedicated

            # Network (Hetzner uses static IP assignments, and we don't use DHCP here)
            networking.useDHCP = false;
            networking.interfaces."enp5s0".ipv4.addresses = [
              {
                address = "1.2.3.4"; # your IPv4 here
                prefixLength = 24;
              }
            ];
            networking.interfaces."enp5s0".ipv6.addresses = [
              {
                address = "1::2::3::4::1"; # Your IPv6 here
                prefixLength = 64;
              }
            ];
            # These settings can be looked up in the running rescue system
            # if unclear
            networking.defaultGateway = "148.251.247.33";
            networking.defaultGateway6 = {
              address = "fe80::1";
              interface = "enp5s0";
            };
            networking.nameservers = [ "8.8.8.8" ];
            networking.firewall.logRefusedConnections = false;

            # Initial empty root password for easy login:
            users.users.root.initialHashedPassword = "";
            services.openssh.permitRootLogin = "prohibit-password";

            users.users.root.openssh.authorizedKeys.keys = [
              "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCXfQnzmqFQsUPwJm1sQSh2A7HH1YxO6OOOn1r2QR/PqwVIRu1rOzAC5IXPKmaIN770dLIJzQMqQoUr3ih/x+zweEyUqJTP0sIjA8l9lJNj0S6xVZ594ci/C6w9fR9uKRmXIk7r6usaqTF0Jdf02Al0tB0Lv4Aqi2b6VNPLO3LT162ZuRpcqSDIZzmQg+lkd0s1jWnJGdX5s7G959ouvID5xx7g/e31M/p4PJFvdEtmZ0YGTqju+STyOvX56GvQKRlRRYVFwwTyC1KUr0fJ31dM0DjZoIrfbeY+MBO6JXT23x6iU2sywqxmrDrRphu3raLI/Y2PhopO0q7DutAoolgV cardno:6444835"
            ];

            services.openssh.enable = true;

            system.stateVersion = "23.11";
          })
        ];
      };

  };
}
