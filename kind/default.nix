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

  kind-config = ./kind-config.yaml;

  manifest = kubenix.buildResources {
    configuration = import ./configuration.nix;
  };

  ingress-controller-manifest = let
    repo = "https://raw.githubusercontent.com/kubernetes/ingress-nginx";
    rev = "68c57386d0f2bed815782d60e9714fc0ff7550af";
    path = "deploy/static/provider/kind/deploy.yaml";
  in builtins.fetchurl "${repo}/${rev}/${path}";

in with pkgs; rec {
  shell = mkShell {
    buildInputs = [
      helloApp
      kind
      kubectl
      deploy-to-kind
      apply-deployment
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
    ${kind}/bin/kind create cluster --config ${kind-config}

    apply-deployment

    echo "Creating ingress-controller ..."
    ${kubectl}/bin/kubectl --context kind-kind apply -f ${ingress-controller-manifest}
    ${kubectl}/bin/kubectl --context kind-kind --namespace ingress-nginx wait \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=120s
  '';

  apply-deployment = writeScriptBin "apply-deployment" ''
    #! ${runtimeShell}
    set -euo pipefail

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
