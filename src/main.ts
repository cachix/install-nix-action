import * as core from '@actions/core';
import * as exec from '@actions/exec';
import * as tc from '@actions/tool-cache';
import {homedir, userInfo, type} from 'os';
import {existsSync} from 'fs';

async function run() {
  try {
    const PATH = process.env.PATH;  
    const INSTALL_PATH = '/opt/nix';

    // Workaround a segfault: https://github.com/NixOS/nix/issues/2733
    await exec.exec("sudo", ["mkdir", "-p", "/etc/nix"]);
    await exec.exec("sudo", ["sh", "-c", "echo http2 = false >> /etc/nix/nix.conf"]);

    // Set jobs to number of cores
    await exec.exec("sudo", ["sh", "-c", "echo max-jobs = auto >> /etc/nix/nix.conf"]);

    // Catalina workaround https://github.com/NixOS/nix/issues/2925
    if (type() == "Darwin") {
      await exec.exec("sudo", ["sh", "-c", `echo \"nix\t${INSTALL_PATH}\"  >> /etc/synthetic.conf`]);
      await exec.exec("sudo", ["sh", "-c", `mkdir -m 0755 ${INSTALL_PATH} && chown runner ${INSTALL_PATH}`]);
      await exec.exec("/System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util", ["-B"]);

      // Needed for sudo to pass NIX_IGNORE_SYMLINK_STORE
      await exec.exec("sudo", ["sh", "-c", "echo 'Defaults env_keep += NIX_IGNORE_SYMLINK_STORE'  >> /etc/sudoers"]);
      core.exportVariable('NIX_IGNORE_SYMLINK_STORE', "1");
      // Needed for nix-daemon installation
      await exec.exec("sudo", ["launchctl", "setenv", "NIX_IGNORE_SYMLINK_STORE", "1"]);
    }

    // Needed due to multi-user being too defensive
    core.exportVariable('ALLOW_PREEXISTING_INSTALLATION', "1"); 

    // TODO: retry due to all the things that go wrong
    const nixInstall = await tc.downloadTool('https://nixos.org/nix/install');
    await exec.exec("sh", [nixInstall, "--daemon"]);
    core.exportVariable('PATH', `${PATH}:/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/per-user/runner/profile/bin`)
    core.exportVariable('NIX_PATH', `/nix/var/nix/profiles/per-user/root/channels`)

    if (type() == "Darwin") {
      // macOS needs certificates hints
      core.exportVariable('NIX_SSL_CERT_FILE', '/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt');
    }
  } catch (error) {
    core.setFailed(`Action failed with error: ${error}`);
    throw(error);
  } 
}

run();
