// 골목대장: 아이디 + 비밀번호로 로그인 (Supabase Edge Function)
//
// 대시보드 → Edge Functions → Deploy a new function → Via Editor
//   이름: login-with-username
//   이 파일 전체를 붙여 넣고 Deploy
//   그 다음 함수 설정(Details)에서 "Verify JWT"(JWT 확인)를 끈다
//   (앱이 쓰는 sb_publishable_ 키는 JWT가 아니라서, 켜 두면 앱 요청이 막힌다)
//
// 하는 일: 아이디로 계정을 찾아 그 계정의 이메일로 대신 로그인하고, 로그인 토큰만 앱에 돌려준다.
// 이메일 주소는 앱에 보내지 않는다. 항상 200으로 답하고 결과는 { ok, error } 로 알린다.

import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// 키 묶음 환경 변수에서 첫 번째 키를 꺼낸다 ({"default":"sb_..."} 모양이거나 그냥 문자열)
function firstKey(raw: string | undefined): string {
  if (!raw) return "";
  try {
    const v = JSON.parse(raw);
    if (typeof v === "string") return v;
    if (Array.isArray(v)) return String(v[0] ?? "");
    if (v && typeof v === "object") return String(v.default ?? Object.values(v)[0] ?? "");
  } catch {
    return raw;
  }
  return "";
}

const reply = (body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), { headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  let username = "", password = "";
  try {
    const body = await req.json();
    username = String(body.username ?? "").trim().toLowerCase();
    password = String(body.password ?? "");
  } catch {
    return reply({ ok: false, error: "bad_request" });
  }
  if (!/^[a-z0-9_]{4,20}$/.test(username) || password.length < 6) {
    return reply({ ok: false, error: "invalid_login" });
  }

  // 프로젝트마다 예전 키(SUPABASE_SERVICE_ROLE_KEY / SUPABASE_ANON_KEY) 또는
  // 새 키(SUPABASE_SECRET_KEYS / SUPABASE_PUBLISHABLE_KEYS, JSON 묶음)가 들어 있다. 있는 것을 쓴다.
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const secretKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || firstKey(Deno.env.get("SUPABASE_SECRET_KEYS"));
  const publicKey = Deno.env.get("SUPABASE_ANON_KEY") || firstKey(Deno.env.get("SUPABASE_PUBLISHABLE_KEYS"));
  if (!url || !secretKey || !publicKey) return reply({ ok: false, error: "server_config" });

  const admin = createClient(url, secretKey, { auth: { persistSession: false } });

  // 아이디 → 계정
  const { data: row } = await admin.from("accounts").select("user_id").eq("username", username).maybeSingle();
  if (!row) return reply({ ok: false, error: "invalid_login" }); // 아이디가 없어도 같은 답 (아이디 존재 여부를 숨김)

  const { data: found } = await admin.auth.admin.getUserById(row.user_id);
  const email = found?.user?.email;
  if (!email) return reply({ ok: false, error: "invalid_login" });

  // 그 이메일로 로그인
  const anon = createClient(url, publicKey, { auth: { persistSession: false } });
  const { data, error } = await anon.auth.signInWithPassword({ email, password });
  if (error || !data.session) {
    const m = (error?.message ?? "").toLowerCase();
    if (m.includes("not confirmed")) return reply({ ok: false, error: "email_not_confirmed" });
    if (m.includes("rate")) return reply({ ok: false, error: "too_many" });
    return reply({ ok: false, error: "invalid_login" });
  }
  return reply({ ok: true, refresh_token: data.session.refresh_token });
});
