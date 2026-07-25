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
      const authHeader = req.headers.get("Authorization");
      if (!authHeader) return json(401, { error: "Missing Authorization" });

      const userClient = createClient(supabaseUrl, anonKey, {
        global: { headers: { Authorization: authHeader } },
      });
      const { data: userData, error: userError } = await userClient.auth
        .getUser();
      if (userError || !userData.user) {
        return json(401, { error: "Unauthorized" });
      }

      const code = String(Math.floor(100000 + Math.random() * 900000));
      const codeHash = await sha256Hex(code);
      const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

      // Invalidate prior unused codes for this user.
      await admin
        .from("watch_pairing_codes")
        .delete()
        .eq("user_id", userData.user.id)
        .is("consumed_at", null);

      const { error: insertError } = await admin
        .from("watch_pairing_codes")
        .insert({
          user_id: userData.user.id,
          code_hash: codeHash,
          expires_at: expiresAt,
        });
      if (insertError) {
        return json(500, { error: insertError.message });
      }

      return json(200, { code, expires_at: expiresAt });
    }

    if (action === "redeem") {
      const code = String(body.code ?? "").trim();
      if (!/^\d{6}$/.test(code)) {
        return json(400, { error: "Invalid code" });
      }
      const codeHash = await sha256Hex(code);
      const { data: row, error: findError } = await admin
        .from("watch_pairing_codes")
        .select("*")
        .eq("code_hash", codeHash)
        .is("consumed_at", null)
        .maybeSingle();
      if (findError) return json(500, { error: findError.message });
      if (!row) return json(404, { error: "Code not found or already used" });
      if (new Date(row.expires_at).getTime() < Date.now()) {
        return json(410, { error: "Code expired" });
      }

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
        // Retry with magiclink type for GoTrue version differences.
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
        await admin
          .from("watch_pairing_codes")
          .update({ consumed_at: new Date().toISOString() })
          .eq("id", row.id);
        return json(200, {
          access_token: retry.data.session.access_token,
          refresh_token: retry.data.session.refresh_token,
          expires_in: retry.data.session.expires_in,
          user: retry.data.user,
        });
      }

      await admin
        .from("watch_pairing_codes")
        .update({ consumed_at: new Date().toISOString() })
        .eq("id", row.id);

      return json(200, {
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
