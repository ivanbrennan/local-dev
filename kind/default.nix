let
  pkgs = let
    rev = "32b46dd897ab2143a609988a04d87452f0bbef59";
    sha256 = "1gzfrpjnr1bz9zljsyg3a4zrhk8r927sz761mrgcg56dwinkhpjk";
  in import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${rev}.tar.gz";
    inherit sha256;
  }) { };

  kubenix = let
    rev = "611059a329493a77ec0e862fcce4671cd3768f32";
    sha256 = "1lmmzb087ahmx2mdjarbi52a9424qczhzqbxrvcrg11cbmv9b191";
  in import (builtins.fetchTarball {
    url = "https://github.com/xtruder/kubenix/archive/${rev}.tar.gz";
    inherit sha256;
  }) { inherit pkgs; };

  manifest = kubenix.buildResources {
    configuration = import ./configuration.nix;
  };

in with pkgs; rec {
  shell = mkShell {
    buildInputs = [
      helloApp
      kind
      kubectl
      deploy-to-kind
    ];
  };

  helloApp = callPackage ./hello-app {};

  appImage = dockerTools.buildLayeredImage {
    name = "hello-app";
    tag = "latest";
    config.Cmd = [ "${helloApp}/bin/hello-app" ];
  };

  deploy-to-kind = writeScriptBin "deploy-to-kind" ''
    #! ${runtimeShell}
    set -euo pipefail

    ${kind}/bin/kind delete cluster || true
    ${kind}/bin/kind create cluster

    echo "Loading the docker image inside the kind docker container ..."
    ( tmpfile=$(mktemp -t appImage.XXXXXX)
      trap "rm -f '$tmpfile'" EXIT INT TERM
      gzip --decompress --stdout ${appImage} > "$tmpfile"
      kind load image-archive "$tmpfile"
    )

    echo "Applying the configuration ..."
    ${jq}/bin/jq "." ${manifest}
    ${kubectl}/bin/kubectl --context kind-kind apply -f ${manifest}
  '';
}
