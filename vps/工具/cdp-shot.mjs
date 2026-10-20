import fs from 'node:fs';

const CDP = 'http://127.0.0.1:9222';
const target = process.argv[2] || 'https://example.com';
const out = process.argv[3] || '/root/shot.png';

async function main() {
  const list = await (await fetch(CDP + '/json/list')).json();
  const page = list.find((t) => t.type === 'page');
  if (!page) throw new Error('no page target');
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  let id = 0;
  const pending = new Map();
  const send = (method, params = {}) => new Promise((resolve, reject) => {
    const mid = ++id;
    pending.set(mid, { resolve, reject });
    ws.send(JSON.stringify({ id: mid, method, params }));
  });
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = () => rej(new Error('ws error')); });
  ws.onmessage = (ev) => {
    const msg = JSON.parse(ev.data);
    if (msg.id && pending.has(msg.id)) {
      const { resolve, reject } = pending.get(msg.id);
      pending.delete(msg.id);
      if (msg.error) reject(new Error(JSON.stringify(msg.error)));
      else resolve(msg.result);
    }
  };
  await send('Page.enable');
  await send('Emulation.setDeviceMetricsOverride', { width: 1600, height: 900, deviceScaleFactor: 1, mobile: false });
  await send('Page.navigate', { url: target });
  await new Promise((r) => setTimeout(r, 5000));
  const shot = await send('Page.captureScreenshot', { format: 'png' });
  fs.writeFileSync(out, Buffer.from(shot.data, 'base64'));
  const title = await send('Runtime.evaluate', { expression: 'document.title' });
  const url = await send('Runtime.evaluate', { expression: 'location.href' });
  console.log('title =', title.result.value);
  console.log('url   =', url.result.value);
  console.log('saved =', out, fs.statSync(out).size, 'bytes');
  ws.close();
}
main().catch((e) => { console.error('FAIL', e.message); process.exit(1); });
