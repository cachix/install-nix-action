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
const fs_1 = require("fs");
function run() {
    return __awaiter(this, void 0, void 0, function* () {
        try {
            const home = os_1.homedir();
            const { username } = os_1.userInfo();
            const PATH = process.env.PATH;
            const CERTS_PATH = home + '/.nix-profile/etc/ssl/certs/ca-bundle.crt';
            // Workaround a segfault: https://github.com/NixOS/nix/issues/2733
            yield exec.exec("sudo", ["mkdir", "-p", "/etc/nix"]);
            yield exec.exec("sudo", ["sh", "-c", "echo http2 = false >> /etc/nix/nix.conf"]);
            // Set jobs to number of cores
            yield exec.exec("sudo", ["sh", "-c", "echo max-jobs = auto >> /etc/nix/nix.conf"]);
            // TODO: retry due to all the things that go wrong
            const nixInstall = yield tc.downloadTool('https://nixos.org/nix/install');
            yield exec.exec("sh", [nixInstall]);
            core.exportVariable('PATH', `${PATH}:${home}/.nix-profile/bin`);
            core.exportVariable('NIX_PATH', `/nix/var/nix/profiles/per-user/${username}/channels`);
            // macOS needs certificates hints
            if (fs_1.existsSync(CERTS_PATH)) {
                core.exportVariable('NIX_SSL_CERT_FILE', CERTS_PATH);
            }
        }
        catch (error) {
            core.setFailed(`Action failed with error: ${error}`);
            throw (error);
        }
    });
}
run();
