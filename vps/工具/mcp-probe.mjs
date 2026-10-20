import { spawn } from 'node:child_process';

const args = ['--cdp-endpoint', 'http://127.0.0.1:9222', '--caps', 'vision,pdf,devtools', '--allow-unrestricted-file-access'];
const child = spawn('/usr/bin/playwright-mcp', args, { stdio: ['pipe', 'pipe', 'pipe'] });
let buf = '';
const results = [];
child.stdout.on('data', (d) => {
  buf += d.toString();
  let idx;
  while ((idx = buf.indexOf('\n')) >= 0) {
    const line = buf.slice(0, idx).trim();
    buf = buf.slice(idx + 1);
    if (!line) continue;
    try {
      const msg = JSON.parse(line);
      if (msg.id) results.push(msg);
    } catch { /* ignore non-JSON */ }
  }
});
child.stderr.on('data', (d) => process.stderr.write('ERR ' + d.toString().slice(0, 300)));

function send(obj) { child.stdin.write(JSON.stringify(obj) + '\n'); }

const waitFor = (id, ms = 30000) => new Promise((resolve, reject) => {
  const t0 = Date.now();
  const tick = () => {
    const hit = results.find((r) => r.id === id);
    if (hit) return resolve(hit);
    if (Date.now() - t0 > ms) return reject(new Error('timeout waiting id ' + id));
    setTimeout(tick, 200);
  };
  tick();
});

send({ jsonrpc: '2.0', id: 1, method: 'initialize', params: { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 'probe', version: '1.0.0' } } });
const init = await waitFor(1);
console.log('initialize ok:', JSON.stringify(init.result?.serverInfo ?? {}).slice(0, 120));
send({ jsonrpc: '2.0', method: 'notifications/initialized' });
send({ jsonrpc: '2.0', id: 2, method: 'tools/list', params: {} });
const list = await waitFor(2);
const tools = (list.result?.tools ?? []).map((t) => t.name);
console.log('tools:', tools.length);
console.log(tools.join(', '));
child.kill();
process.exit(0);
