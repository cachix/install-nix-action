"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (Object.hasOwnProperty.call(mod, k)) result[k] = mod[k];
    result["default"] = mod;
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
const core = __importStar(require("@actions/core"));
const exec = __importStar(require("@actions/exec"));
const tc = __importStar(require("@actions/tool-cache"));
const os_1 = require("os");
function run() {
    return __awaiter(this, void 0, void 0, function* () {
        try {
            const PATH = process.env.PATH;
            const INSTALL_PATH = '/opt/nix';
            // Workaround a segfault: https://github.com/NixOS/nix/issues/2733
            yield exec.exec("sudo", ["mkdir", "-p", "/etc/nix"]);
            yield exec.exec("sudo", ["sh", "-c", "echo http2 = false >> /etc/nix/nix.conf"]);
            // Set jobs to number of cores
            yield exec.exec("sudo", ["sh", "-c", "echo max-jobs = auto >> /etc/nix/nix.conf"]);
            // Allow binary caches for runner user
            yield exec.exec("sudo", ["sh", "-c", "echo trusted-users = root runner >> /etc/nix/nix.conf"]);
            // Catalina workaround https://github.com/NixOS/nix/issues/2925
            if (os_1.type() == "Darwin") {
                yield exec.exec("sudo", ["sh", "-c", `echo \"nix\t${INSTALL_PATH}\"  >> /etc/synthetic.conf`]);
                yield exec.exec("sudo", ["sh", "-c", `mkdir -m 0755 ${INSTALL_PATH} && chown runner ${INSTALL_PATH}`]);
                yield exec.exec("/System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util", ["-B"]);
                // Needed for sudo to pass NIX_IGNORE_SYMLINK_STORE
                yield exec.exec("sudo", ["sh", "-c", "echo 'Defaults env_keep += NIX_IGNORE_SYMLINK_STORE'  >> /etc/sudoers"]);
                core.exportVariable('NIX_IGNORE_SYMLINK_STORE', "1");
                // Needed for nix-daemon installation
                yield exec.exec("sudo", ["launchctl", "setenv", "NIX_IGNORE_SYMLINK_STORE", "1"]);
            }
            // Needed due to multi-user being too defensive
            core.exportVariable('ALLOW_PREEXISTING_INSTALLATION', "1");
            // TODO: retry due to all the things that go wrong
            const nixInstall = yield tc.downloadTool('https://nixos.org/nix/install');
            yield exec.exec("sh", [nixInstall, "--daemon"]);
            core.exportVariable('PATH', `${PATH}:/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/per-user/runner/profile/bin`);
            core.exportVariable('NIX_PATH', `/nix/var/nix/profiles/per-user/root/channels`);
            if (os_1.type() == "Darwin") {
                // macOS needs certificates hints
                core.exportVariable('NIX_SSL_CERT_FILE', '/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt');
            }
        }
        catch (error) {
            core.setFailed(`Action failed with error: ${error}`);
            throw (error);
        }
    });
}
run();
