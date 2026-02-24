{
  description = "Reproducible madv kernel regression test";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Linux 6.17 was removed from nixpkgs (EOL upstream).
      # Define it locally by overriding the 6.12 kernel source.
      linux_6_17 = pkgs.linux_6_12.override {
        argsOverride = rec {
          version = "6.17";
          modDirVersion = "6.17.0";
          src = pkgs.fetchurl {
            url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${version}.tar.xz";
            hash = "sha256-m2BxZqHJmdgyYJgSEiL+sICiCjJTl1/N+i3pa6f3V6c=";
          };
          ignoreConfigErrors = true;
          structuredExtraConfig = with pkgs.lib.kernel; {
            RUST = pkgs.lib.mkForce no;
          };
        };
      };
      linuxPackages_6_17 = pkgs.linuxPackagesFor linux_6_17;

      inherit (self.packages.${system}) thp-madv-remove-test;

      # A function that returns a NixOS test that spawns a VM booting the given Linux kernel,
      # then runs the thp-madv-remove-test binary inside the VM
      # to check for the presence of the regression.
      test = linuxPackages: pkgs.testers.nixosTest {
        name = "thp-madv-remove-test";

        nodes.machine = {
          boot.kernelPackages = linuxPackages;
          environment.systemPackages = [thp-madv-remove-test];
          virtualisation.memorySize = 16 * 1024;
        };

        testScript = ''
          machine.wait_for_unit("multi-user.target")
          machine.succeed("systemd-run --wait --pipe -u thp-madv-remove-test thp-madv-remove-test")
        '';
      };
    in
    {
      # For `nix develop` to drop us in a shell where we can develop the rust code using cargo and clippy.
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.cargo
          pkgs.clippy
          pkgs.rustc
        ];
      };

      packages.${system} = {
        inherit linux_6_17;

        thp-madv-remove-test = pkgs.rustPlatform.buildRustPackage {
          pname = "thp-madv-remove-test";
          version = "0.1.0";
          src = pkgs.lib.fileset.toSource {
            root = ./.;
            fileset = pkgs.lib.fileset.unions [
              ./main.rs
              ./Cargo.toml
              ./Cargo.lock
            ];
          };
          cargoLock.lockFile = ./Cargo.lock;
        };

        default = thp-madv-remove-test;
      };

      # Run these tests like: `nix build .#checks.x86_64-linux.test_6_17 -L`
      checks.${system} = {
        test_6_17 = test      linuxPackages_6_17;
        test_6_18 = test pkgs.linuxPackages_6_18;
      };
    };
}
