// Supabase Edge Function: kenali makanan dari foto lewat OpenRouter Vision.
//
// Kunci OpenRouter disimpan di server sebagai secret, jadi TIDAK ikut ke APK:
//   supabase secrets set OPENROUTER_API_KEY=sk-or-... --project-ref <ref>
//   supabase functions deploy recognize-food --project-ref <ref>
//
// Request : POST { "image": "<JPEG base64>" } dengan header Authorization pengguna login.
// Response: { label, confidence, calories, protein_g, ..., alternatives: [...], model }
import { createClient } from "npm:@supabase/supabase-js@2";

const PROMPT = `Anda adalah pakar kuliner dan gizi terkemuka di Indonesia.
Tugas:
1. Identifikasi makanan atau minuman utama pada foto ini.
2. Estimasi kandungan nutrisi rata-rata per 1 porsi saji standar.

ATURAN WAJIB:
- Gunakan penamaan makanan/minuman khas Indonesia sehari-hari!
  Contoh: jika roti dipanggang/dibakar, sebut "Roti Bakar" (DILARANG menyebut "Panini" atau "Toast").
  Jika kopi susu dingin, sebut "Es Kopi" (DILARANG menyebut "Iced Coffee" atau "Latte").
  Gunakan istilah umum seperti: "Nasi Goreng", "Soto Ayam", "Rendang", "Gado-Gado", "Pisang Goreng", "Sayur Bening Bayam", "Bakso", "Ayam Goreng", dll.
- Jika foto tidak berisi makanan atau minuman, isi label "Tidak ada makanan atau minuman yang teridentifikasi" dan calories 0.
- Balas HANYA dalam format JSON murni (tanpa tanda kutip \`\`\` atau teks pengantar apapun):
{
  "label": "Nama Makanan",
  "confidence": 0.95,
  "calories": 280,
  "protein_g": 6.5,
  "fat_g": 9.0,
  "carbs_g": 42.0,
  "sugar_g": 12.0,
  "sodium_mg": 320,
  "fiber_g": 2.5,
  "alternatives": [
    {"label": "Kemungkinan Lain 1", "confidence": 0.70},
    {"label": "Kemungkinan Lain 2", "confidence": 0.50}
  ]
}
Catatan nilai gizi: calories (kkal), protein_g (gram), fat_g (gram), carbs_g (gram), sugar_g (gram), sodium_mg (miligram), fiber_g (gram).`;

// Model utama dulu, lalu model gratis sebagai cadangan bila gagal/rate limit.
const MODELS = [
  Deno.env.get("OPENROUTER_MODEL") ?? "qwen/qwen-2.5-vl-72b-instruct",
  "inclusionai/ling-3.0-flash-vl:free",
];

const MAX_BASE64_LENGTH = 2_000_000; // ±1,5 MB JPEG; aplikasi sudah mengecilkan ke 768 px

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Gunakan POST" }, 405);

  // Hanya pengguna yang sudah login yang boleh memakai kuota AI.
  const authHeader = req.headers.get("Authorization") ?? "";
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return json({ error: "Silakan masuk terlebih dahulu" }, 401);

  const apiKey = Deno.env.get("OPENROUTER_API_KEY");
  if (!apiKey) return json({ error: "OPENROUTER_API_KEY belum diset di Supabase" }, 500);

  let image: unknown;
  try {
    ({ image } = await req.json());
  } catch {
    return json({ error: "Body harus JSON" }, 400);
  }
  if (typeof image !== "string" || image.length < 100) {
    return json({ error: 'Field "image" (JPEG base64) wajib diisi' }, 400);
  }
  if (image.length > MAX_BASE64_LENGTH) return json({ error: "Foto terlalu besar" }, 413);

  let lastError = "";
  for (const model of MODELS) {
    try {
      const res = await fetch("https://openrouter.ai/api/v1/chat/completions", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
          "HTTP-Referer": "https://github.com/nfgcode/racik_app",
          "X-Title": "Racik Food Scanner",
        },
        body: JSON.stringify({
          model,
          max_tokens: 350,
          temperature: 0.1,
          messages: [{
            role: "user",
            content: [
              { type: "text", text: PROMPT },
              { type: "image_url", image_url: { url: `data:image/jpeg;base64,${image}` } },
            ],
          }],
        }),
      });
      if (!res.ok) {
        lastError = `OpenRouter ${res.status}: ${await res.text()}`;
        continue;
      }
      const data = await res.json();
      const content: string = data?.choices?.[0]?.message?.content ?? "";
      // Ambil bagian JSON (antara kurung kurawal pertama dan terakhir).
      const match = content.match(/\{[\s\S]*\}/);
      const parsed = JSON.parse(match ? match[0] : content);
      return json({ ...parsed, model });
    } catch (e) {
      lastError = String(e);
    }
  }
  console.error("recognize-food gagal:", lastError);
  return json({ error: "AI belum bisa mengenali foto. Coba lagi sebentar lagi." }, 502);
});
