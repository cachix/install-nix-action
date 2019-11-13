{ pkgs ? import <nixpkgs> {}
}:

pkgs.mkShell {
  name = "install-nix-action-shell";

  buildInputs = [ pkgs.yarn ];
}
