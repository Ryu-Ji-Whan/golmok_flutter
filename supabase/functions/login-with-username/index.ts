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

  const url = Deno.env.get("SUPABASE_URL")!;
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false },
  });

  // 아이디 → 계정
  const { data: row } = await admin.from("accounts").select("user_id").eq("username", username).maybeSingle();
  if (!row) return reply({ ok: false, error: "invalid_login" }); // 아이디가 없어도 같은 답 (아이디 존재 여부를 숨김)

  const { data: found } = await admin.auth.admin.getUserById(row.user_id);
  const email = found?.user?.email;
  if (!email) return reply({ ok: false, error: "invalid_login" });

  // 그 이메일로 로그인
  const anon = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, { auth: { persistSession: false } });
  const { data, error } = await anon.auth.signInWithPassword({ email, password });
  if (error || !data.session) {
    const m = (error?.message ?? "").toLowerCase();
    if (m.includes("not confirmed")) return reply({ ok: false, error: "email_not_confirmed" });
    if (m.includes("rate")) return reply({ ok: false, error: "too_many" });
    return reply({ ok: false, error: "invalid_login" });
  }
  return reply({ ok: true, refresh_token: data.session.refresh_token });
});
