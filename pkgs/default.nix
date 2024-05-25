{ pkgs }:

{
  core-0-21-0 = pkgs.callPackage ./core/0.21.0 { };
  core-22-0 = pkgs.callPackage ./core/0.22.0 { };
  mutinynet = pkgs.callPackage ./forks/mutinynet { };
  sv2 = pkgs.callPackage ./forks/sv2 { };
  sv2-testnet4 = pkgs.callPackage ./forks/sv2-testnet4 { };
}