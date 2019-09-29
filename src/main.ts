import * as core from '@actions/core';
import * as exec from '@actions/exec';
import * as tc from '@actions/tool-cache';
import {homedir, userInfo} from 'os';
import {existsSync} from 'fs';

async function run() {
  try {
    const home = homedir();
    const {username} = userInfo();
    const PATH = process.env.PATH;  
    const CERTS_PATH = home + '/.nix-profile/etc/ssl/certs/ca-bundle.crt';

    // TODO: retry due to all the things that go wrong
    const nixInstall = await tc.downloadTool('https://nixos.org/nix/install');
    await exec.exec("sh", [nixInstall]);
    core.exportVariable('PATH', `${PATH}:${home}/.nix-profile/bin`)
    core.exportVariable('NIX_PATH', `/nix/var/nix/profiles/per-user/${username}/channels`)

    // macOS needs certificates hints
    if (existsSync(CERTS_PATH)) {
      core.exportVariable('NIX_SSL_CERT_FILE', CERTS_PATH);
    }
  } catch (error) {
    core.setFailed(`Action failed with error: ${error}`);
    throw(error);
  } 
}

run();
