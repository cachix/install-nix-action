import { execFileSync } from 'child_process';
import { exit } from 'process';
import { createConnection } from 'net';

async function awaitSocket() {
  const daemonSocket = createConnection({ path: '/nix/var/nix/daemon-socket/socket' });
  daemonSocket.on('error', async () => {
    console.log('Waiting for daemon socket to be available, reconnecting...');
    await new Promise(resolve => setTimeout(resolve, 500));
    await awaitSocket();
  });
  daemonSocket.on('connect', () => {
    exit(0);
  });
}

execFileSync(`${__dirname}/install-nix.sh`, { stdio: 'inherit' });

// nc doesn't work correctly on macOS :(
awaitSocket();