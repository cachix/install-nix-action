import { execFileSync } from 'child_process';

execFileSync(`${__dirname}/install-nix.sh`, { stdio: 'inherit' });
