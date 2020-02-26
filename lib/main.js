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
Object.defineProperty(exports, "__esModule", { value: true });
const child_process_1 = require("child_process");
const process_1 = require("process");
const net_1 = require("net");
function awaitSocket() {
    return __awaiter(this, void 0, void 0, function* () {
        const daemonSocket = net_1.createConnection({ path: '/nix/var/nix/daemon-socket/socket' });
        daemonSocket.on('error', () => __awaiter(this, void 0, void 0, function* () {
            console.log('Waiting for daemon socket to be available, reconnecting...');
            yield new Promise(resolve => setTimeout(resolve, 500));
            yield awaitSocket();
        }));
        daemonSocket.on('connect', () => {
            process_1.exit(0);
        });
    });
}
child_process_1.execFileSync(`${__dirname}/install-nix.sh`, { stdio: 'inherit' });
// nc doesn't work correctly on macOS :(
awaitSocket();
