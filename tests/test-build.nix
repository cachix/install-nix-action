# Realizes <num>> of derivations with size of <size>MB
{ size ? 1 # MB
, num ? 10 # count 
, currentTime ? builtins.currentTime
, noChroot ? false
}:

with import <nixpkgs> {};

let
  drv = i: runCommand "${toString currentTime}-${toString i}" {
    __noChroot = noChroot;
  } ''
    dd if=/dev/zero of=$out bs=${toString size}MB count=1
  '';
in writeText "empty-${toString num}-${toString size}MB" ''
  ${lib.concatMapStringsSep "" drv (lib.range 1 num)}
''
