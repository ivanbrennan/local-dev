let
  pkgs = let
    rev = "32b46dd897ab2143a609988a04d87452f0bbef59";
    sha256 = "1gzfrpjnr1bz9zljsyg3a4zrhk8r927sz761mrgcg56dwinkhpjk";
  in import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${rev}.tar.gz";
    inherit sha256;
  }) { };

in with pkgs; rec {
  shell = mkShell {
    buildInputs = [
      helloApp
      kind
      kubectl
    ];
  };

  helloApp = callPackage ./hello-app {};

  appImage = dockerTools.buildLayeredImage {
    name = "hello-app";
    tag = "latest";
    config.Cmd = [ "${helloApp}/bin/hello-app" ];
  };
}
