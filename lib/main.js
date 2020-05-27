"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const child_process_1 = require("child_process");
child_process_1.execFileSync(`${__dirname}/install-nix.sh`, { stdio: 'inherit' });
