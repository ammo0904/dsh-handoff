import fs from 'node:fs';
const CDP = 'http://127.0.0.1:9222';
const URL_ = 'http://127.0.0.1:8099/mock/mock.html';

const list = await (await fetch(CDP + '/json/list')).json();
const page = list.find((t) => t.type === 'page');
const ws = new WebSocket(page.webSocketDebuggerUrl);
let id = 0;
const pending = new Map();
const send = (method, params = {}) => new Promise((res, rej) => {
  const mid = ++id; pending.set(mid, { res, rej });
  ws.send(JSON.stringify({ id: mid, method, params }));
});
await new Promise((r, j) => { ws.onopen = r; ws.onerror = () => j(new Error('ws')); });
ws.onmessage = (ev) => {
  const m = JSON.parse(ev.data);
  if (m.id && pending.has(m.id)) {
    const { res, rej } = pending.get(m.id); pending.delete(m.id);
    m.error ? rej(new Error(JSON.stringify(m.error))) : res(m.result);
  }
};
const evalJs = async (expr) => {
  const r = await send('Runtime.evaluate', { expression: expr, awaitPromise: true, returnByValue: true });
  return r.result?.value;
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

await send('Page.enable');
await send('Page.navigate', { url: URL_ });
await sleep(2500);

const out = [];
out.push(['初始', await evalJs('document.getElementById("summary").textContent')]);
out.push(['統計', await evalJs('document.getElementById("stats").textContent')]);

// 1) 取消「只看可租」→ 應出現 12 台（含離線與已滿）
await evalJs('document.getElementById("f-rentable").click()');
await sleep(200);
out.push(['取消只看可租', await evalJs('document.getElementById("summary").textContent')]);
out.push(['離線卡是否顯示', await evalJs('!!document.querySelector(".card.off")')]);

// 2) 恢復，測 CUDA 13.2
await evalJs('document.getElementById("f-rentable").click()');
await evalJs('document.getElementById("f-cuda").value="13.2"; document.getElementById("f-cuda").dispatchEvent(new Event("input"))');
await sleep(200);
out.push(['CUDA=13.2', await evalJs('document.getElementById("summary").textContent')]);

// 3) 清 CUDA，測 CUDA=99 是否被視為未知（不應符合）
await evalJs('document.getElementById("f-cuda").value="99"; document.getElementById("f-cuda").dispatchEvent(new Event("input"))');
await sleep(200);
out.push(['CUDA=99（未知）', await evalJs('document.getElementById("summary").textContent')]);
await evalJs('document.getElementById("f-cuda").value=""; document.getElementById("f-cuda").dispatchEvent(new Event("input"))');

// 4) 區域複選：只選 西北B区
await evalJs(`(() => {
  document.getElementById('region-toggle').click();
  const labels = [...document.querySelectorAll('#region-menu label')];
  const hit = labels.find(l => l.textContent.includes('西北B区'));
  if (hit) hit.querySelector('input').click();
})()`);
await sleep(250);
out.push(['區域=西北B区', await evalJs('document.getElementById("summary").textContent')]);
out.push(['篩選鈕文字', await evalJs('document.getElementById("region-toggle").textContent')]);

// 5) 建立主機對話框
await evalJs(`(() => { const b = document.querySelector('[data-open]'); if (b) b.click(); })()`);
await sleep(300);
out.push(['對話框開啟', await evalJs('!document.getElementById("dialog").classList.contains("hidden")')]);
out.push(['對話框內容', await evalJs('document.getElementById("dialog-body").innerText.replace(/\\n/g," | ").slice(0,120)')]);
await evalJs('document.getElementById("dlg-ok").click()');
await sleep(300);
out.push(['按下確認後的紀錄', await evalJs('document.getElementById("log").innerText.split("\\n")[0]')]);

// 6) 倒數有沒有在跑
const c1 = await evalJs('document.getElementById("countdown").textContent');
await sleep(2200);
const c2 = await evalJs('document.getElementById("countdown").textContent');
out.push(['倒數', `${c1} -> ${c2}`]);

console.log(out.map(([k, v]) => `${k}: ${v}`).join('\n'));
const shot = await send('Page.captureScreenshot', { format: 'png' });
fs.writeFileSync('/root/mock2.png', Buffer.from(shot.data, 'base64'));
ws.close();
process.exit(0);
