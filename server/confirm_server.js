// ============================================================
// confirm_server.js
// MEAL:ON 결제 승인 서버 (토스페이먼츠)
//
// 앱(브라우저)은 시크릿 키를 가질 수 없어서, "결제 승인"은 이 서버가 대신 해요.
//   앱 → POST /confirm {paymentKey, orderId, amount}
//   서버 → 토스 API(/v1/payments/confirm) 에 시크릿 키로 승인 요청
//   서버 → 앱에 결과 돌려줌
//
// 켜는 법 (Node.js 18 이상):
//   cd server
//   npm start                       ← 테스트 시크릿 키로 켜짐 (기본값)
//
// 실제 결제로 바꿀 때:
//   TOSS_SECRET_KEY=live_sk_xxxx npm start
//   (또는 Firebase Functions 등에 올리고 lib/config/payment_config.dart 의
//    kPaymentServerUrl 을 그 주소로 바꾸기)
//
// 외부 라이브러리 없이 Node 기본 기능(http, fetch)만 써요.
// ============================================================

const http = require('http');

// 토스 개발자센터가 공개한 "문서용 테스트 시크릿 키" (돈 안 빠져나감)
// 내 계정 키로 바꾸려면 환경변수 TOSS_SECRET_KEY 로 넣어요. 코드에 실제 키를 적지 마세요!
const SECRET_KEY = process.env.TOSS_SECRET_KEY || 'test_sk_zXLkKEypNArWmo50nX3lmeaxYG5R';
const PORT = Number(process.env.PORT) || 3000;
// 토스 API 주소 (테스트할 때 가짜 서버로 바꿔 끼울 수 있게 환경변수로)
const TOSS_API_URL = process.env.TOSS_API_URL || 'https://api.tosspayments.com';

// 시크릿 키 뒤에 ':' 붙여서 base64 → 토스 API 인증 헤더
const AUTH = 'Basic ' + Buffer.from(SECRET_KEY + ':').toString('base64');

// 예약금 1명당 금액 (앱의 kDepositPerPerson 과 같게). 승인 전에 금액이 이상한지 확인용
const DEPOSIT_PER_PERSON = 2000;
const MAX_PEOPLE = 20;

/** 토스 결제 승인 API 호출 */
async function confirmWithToss({ paymentKey, orderId, amount }) {
  const res = await fetch(`${TOSS_API_URL}/v1/payments/confirm`, {
    method: 'POST',
    headers: { Authorization: AUTH, 'Content-Type': 'application/json' },
    body: JSON.stringify({ paymentKey, orderId, amount }),
  });
  const text = await res.text();
  let body;
  try { body = JSON.parse(text); } catch { body = { code: 'BAD_RESPONSE', message: text.slice(0, 200) }; }
  return { ok: res.ok, body };
}

/** 요청 본문(JSON) 읽기 */
function readJson(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', (chunk) => {
      data += chunk;
      if (data.length > 10_000) reject(new Error('too large'));
    });
    req.on('end', () => {
      try { resolve(data ? JSON.parse(data) : {}); } catch (e) { reject(e); }
    });
    req.on('error', reject);
  });
}

function send(res, status, obj) {
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    // 브라우저(앱)가 다른 주소(localhost:8080)에서 요청해도 받아주기 (CORS)
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  });
  res.end(JSON.stringify(obj));
}

const server = http.createServer(async (req, res) => {
  // 브라우저가 POST 전에 먼저 보내는 확인 요청(preflight)
  if (req.method === 'OPTIONS') return send(res, 204, {});

  if (req.method === 'GET' && (req.url === '/' || req.url === '/health')) {
    return send(res, 200, {
      ok: true,
      service: 'MEAL:ON payment confirm server',
      mode: SECRET_KEY.startsWith('live_') ? 'live' : 'test',
    });
  }

  if (req.method === 'POST' && req.url === '/confirm') {
    let params;
    try {
      params = await readJson(req);
    } catch {
      return send(res, 400, { ok: false, message: '요청 내용을 읽을 수 없어요' });
    }
    const { paymentKey, orderId } = params;
    const amount = Number(params.amount);

    if (typeof paymentKey !== 'string' || typeof orderId !== 'string' || !Number.isInteger(amount)) {
      return send(res, 400, { ok: false, message: 'paymentKey, orderId, amount 가 필요해요' });
    }
    // 예약금으로 나올 수 없는 금액이면 승인하지 않아요
    if (amount < DEPOSIT_PER_PERSON || amount > DEPOSIT_PER_PERSON * MAX_PEOPLE || amount % DEPOSIT_PER_PERSON !== 0) {
      return send(res, 400, { ok: false, message: `예약금 금액이 이상해요: ${amount}원` });
    }

    try {
      const { ok, body } = await confirmWithToss({ paymentKey, orderId, amount });
      if (!ok) {
        console.log(`[confirm] 실패 ${orderId}: ${body.code} ${body.message}`);
        return send(res, 400, { ok: false, code: body.code, message: body.message || '결제 승인 실패' });
      }
      console.log(`[confirm] 성공 ${orderId}: ${body.totalAmount}원 (${body.method})`);
      // 여기서 나중에 Firebase 등 진짜 DB에 예약을 저장하면 돼요.
      return send(res, 200, {
        ok: true,
        payment: {
          paymentKey: body.paymentKey,
          orderId: body.orderId,
          totalAmount: body.totalAmount,
          method: body.method,
          approvedAt: body.approvedAt,
          status: body.status,
        },
      });
    } catch (e) {
      console.error('[confirm] 토스 API 연결 오류', e);
      return send(res, 502, { ok: false, message: '토스페이먼츠 서버에 연결하지 못했어요' });
    }
  }

  send(res, 404, { ok: false, message: 'not found' });
});

server.listen(PORT, () => {
  console.log(`MEAL:ON 결제 승인 서버 켜짐 → http://localhost:${PORT}`);
  console.log(`키 모드: ${SECRET_KEY.startsWith('live_') ? '실제 결제(live)' : '테스트(test) — 돈 안 빠져나감'}`);
});
