import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(hash)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function isProjectAnonKey(req: Request): boolean {
  const apikey = req.headers.get("apikey") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  return apikey.length > 0 && anonKey.length > 0 && apikey === anonKey;
}

function decodeJwtPayload(token: string): Record<string, unknown> | null {
  try {
    const parts = token.split(".");
    if (parts.length < 2) return null;
    const b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const pad = b64 + "=".repeat((4 - (b64.length % 4)) % 4);
    return JSON.parse(atob(pad)) as Record<string, unknown>;
  } catch {
    return null;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !anonKey || !serviceKey) {
      return json(500, { error: "Missing Supabase env" });
    }

    const admin = createClient(supabaseUrl, serviceKey);
    const body = await req.json();
    const action = String(body.action ?? "").trim().toLowerCase();

    if (action === "create") {
      // Floor apps create codes with the project anon key — no user sign-in.
      if (!isProjectAnonKey(req)) {
        return json(401, { error: "Missing or invalid apikey" });
      }

      const authHeader = req.headers.get("Authorization") ?? "";
      const token = authHeader.startsWith("Bearer ")
        ? authHeader.replace(/^Bearer\s+/i, "").trim()
        : "";
      let userId: string | null = null;
      if (token && decodeJwtPayload(token)?.role !== "anon") {
        const { data: userData } = await admin.auth.getUser(token);
        userId = userData?.user?.id ?? null;
      }

      const code = String(Math.floor(100000 + Math.random() * 900000));
      const codeHash = await sha256Hex(code);
      const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

      if (userId) {
        const { error: replaceError } = await admin.rpc(
          "replace_watch_pairing_code",
          {
            p_user_id: userId,
            p_code_hash: codeHash,
            p_expires_at: expiresAt,
          },
        );
        if (replaceError) {
          return json(500, { error: replaceError.message });
        }
      } else {
        const { error: replaceError } = await admin.rpc(
          "replace_floor_watch_pairing_code",
          {
            p_code_hash: codeHash,
            p_expires_at: expiresAt,
          },
        );
        if (replaceError) {
          return json(500, { error: replaceError.message });
        }
      }

      return json(200, { code, expires_at: expiresAt });
    }

    if (action === "redeem") {
      if (!isProjectAnonKey(req)) {
        return json(401, { error: "Missing or invalid apikey" });
      }

      const code = String(body.code ?? "").trim();
      if (!/^\d{6}$/.test(code)) {
        return json(400, { error: "Invalid code" });
      }
      const codeHash = await sha256Hex(code);

      const { data: row, error: claimError } = await admin.rpc(
        "claim_watch_pairing_code",
        { p_code_hash: codeHash },
      );
      if (claimError) return json(500, { error: claimError.message });
      if (!row) {
        return json(404, { error: "Code not found, expired, or already used" });
      }

      // Floor codes (null user_id): mark paired — Wear uses anon access like the phone.
      if (!row.user_id) {
        return json(200, { paired: true, floor: true });
      }

      // Legacy user-bound codes: mint a session for the creating account.
      const { data: userData, error: getUserError } = await admin.auth.admin
        .getUserById(row.user_id);
      if (getUserError || !userData.user?.email) {
        return json(500, { error: "User lookup failed" });
      }

      const { data: linkData, error: linkError } = await admin.auth.admin
        .generateLink({
          type: "magiclink",
          email: userData.user.email,
        });
      if (linkError || !linkData?.properties?.hashed_token) {
        return json(500, {
          error: linkError?.message ?? "Failed to generate session link",
        });
      }

      const { data: otpData, error: otpError } = await admin.auth.verifyOtp({
        token_hash: linkData.properties.hashed_token,
        type: "email",
      });
      if (otpError || !otpData.session) {
        const retry = await admin.auth.verifyOtp({
          token_hash: linkData.properties.hashed_token,
          type: "magiclink",
        });
        if (retry.error || !retry.data.session) {
          return json(500, {
            error: otpError?.message ??
              retry.error?.message ??
              "Failed to create session",
          });
        }
        return json(200, {
          paired: true,
          access_token: retry.data.session.access_token,
          refresh_token: retry.data.session.refresh_token,
          expires_in: retry.data.session.expires_in,
          user: retry.data.user,
        });
      }

      return json(200, {
        paired: true,
        access_token: otpData.session.access_token,
        refresh_token: otpData.session.refresh_token,
        expires_in: otpData.session.expires_in,
        user: otpData.user,
      });
    }

    return json(400, { error: "Unknown action" });
  } catch (e) {
    return json(500, { error: String(e) });
  }
});
