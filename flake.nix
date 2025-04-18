{
  description = "Mimosa.";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.systems.url = "github:nix-systems/default";
  inputs.pre-commit-hooks.url = "github:cachix/git-hooks.nix";
  inputs.flake-utils = {
    url = "github:numtide/flake-utils";
    inputs.systems.follows = "systems";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }@inputs:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        checks = {
          pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              nixfmt-rfc-style.enable = true;
              ripsecrets.enable = true;
            };
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = self.checks.${system}.pre-commit-check.enabledPackages;
          packages = with pkgs; [
            nixfmt-rfc-style
            talosctl
            kubectl
            just
            kubernetes-helm
            age
            sops
          ];
          shellHook = ''
            ${self.checks.${system}.pre-commit-check.shellHook}
            export http_proxy= https_proxy= all_proxy=
            export TALOSCONFIG=$(realpath ./talos/talosconfig)
            export STARSHIP_CONFIG=$(realpath ./.starship.toml)
          '';
        };
      }
    );
}
