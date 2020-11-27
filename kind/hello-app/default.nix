{ pkgs ? import <nixpkgs> {} }:

pkgs.mkYarnPackage {
  name = "hello-app";
  src = ./.;
  packageJson = ./package.json;
  yarnLock = ./yarn.lock;
}
