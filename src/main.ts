import * as core from '@actions/core';
import * as exec from '@actions/exec';
import * as tc from '@actions/tool-cache';
import {execFileSync} from 'child_process';
import {type} from 'os';

async function nixConf() {
    // Workaround a segfault: https://github.com/NixOS/nix/issues/2733
    await exec.exec("sudo", ["mkdir", "-p", "/etc/nix"]);
    await exec.exec("sudo", ["sh", "-c", "echo http2 = false >> /etc/nix/nix.conf"]);

    // Set jobs to number of cores
    await exec.exec("sudo", ["sh", "-c", "echo max-jobs = auto >> /etc/nix/nix.conf"]);

    // Allow binary caches for runner user
    await exec.exec("sudo", ["sh", "-c", "echo trusted-users = root runner >> /etc/nix/nix.conf"]);
}

async function run() {
  try {
    const PATH = process.env.PATH;
 
    await nixConf();

    // Catalina workaround https://github.com/NixOS/nix/issues/2925
    if (type() == "Darwin") {
      execFileSync(`${__dirname}/create-darwin-volume.sh`, { stdio: 'inherit' });
    }

    // Needed due to multi-user being too defensive
    core.exportVariable('ALLOW_PREEXISTING_INSTALLATION', "1"); 

    // TODO: retry due to all the things that can go wrong
    const nixInstall = await tc.downloadTool('https://nixos.org/nix/install');
    await exec.exec("sh", [nixInstall, "--daemon"]);

    // write nix.conf again as installation overwrites it, reload the daemon to pick up changes
    await nixConf();
    await exec.exec("sudo", ["pkill", "-HUP", "nix-daemon"]);

    // setup env
    core.exportVariable('PATH', `${PATH}:/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/per-user/runner/profile/bin`)
    core.exportVariable('NIX_PATH', `/nix/var/nix/profiles/per-user/root/channels`)
    if (type() == "Darwin") {
      // macOS needs certificates hints
      core.exportVariable('NIX_SSL_CERT_FILE', '/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt');

      // TODO: nc doesn't work correctly on macOS :(
      await exec.exec("sleep", ["10"]);
    }
  } catch (error) {
    core.setFailed(`Action failed with error: ${error}`);
    throw(error);
  }
}

run();
