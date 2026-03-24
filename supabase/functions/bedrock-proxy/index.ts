import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { SignatureV4 } from "https://esm.sh/@aws-sdk/signature-v4";
import { Sha256 } from "https://esm.sh/@aws-crypto/sha256-js";
import { HttpRequest } from "https://esm.sh/@aws-sdk/protocol-http";

const AWS_ACCESS_KEY = Deno.env.get("AWS_ACCESS_KEY_ID") || "";
const AWS_SECRET_KEY = Deno.env.get("AWS_SECRET_ACCESS_KEY") || "";
const AWS_REGION = Deno.env.get("AWS_REGION") || "us-east-1";

serve(async (req) => {
  // CORS Headers
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': '*' } });
  }

  try {
    const { prompt, modelId = "anthropic.claude-3-haiku-20240307-v1:0" } = await req.json();

    if (!prompt) {
      return new Response(JSON.stringify({ error: "Prompt is required" }), { status: 400 });
    }

    const endpoint = `https://bedrock-runtime.${AWS_REGION}.amazonaws.com/model/${modelId}/invoke`;
    const url = new URL(endpoint);

    let payload: any;
    if (modelId.includes('anthropic')) {
      payload = {
        anthropic_version: "bedrock-2023-05-31",
        max_tokens: 1024,
        messages: [{ role: "user", content: [{ type: "text", text: prompt }] }]
      };
    } else if (modelId.includes('meta')) {
      payload = { prompt, max_gen_len: 1024, temperature: 0.5 };
    } else if (modelId.includes('mistral')) {
      payload = { prompt: `<s>[INST] ${prompt} [/INST]`, max_tokens: 1024 };
    } else {
      payload = { prompt };
    }

    const body = JSON.stringify(payload);

    const signer = new SignatureV4({
      credentials: { accessKeyId: AWS_ACCESS_KEY, secretAccessKey: AWS_SECRET_KEY },
      region: AWS_REGION,
      service: "bedrock",
      sha256: Sha256,
    });

    const request = new HttpRequest({
      method: "POST",
      protocol: "https:",
      hostname: url.hostname,
      path: url.pathname,
      headers: {
        "Content-Type": "application/json",
        "Host": url.hostname,
      },
      body,
    });

    const signed = await signer.sign(request);
    
    const response = await fetch(endpoint, {
      method: "POST",
      headers: signed.headers,
      body,
    });

    const data = await response.json();

    if (!response.ok) {
      return new Response(JSON.stringify({ error: "Bedrock error", detail: data }), { status: response.status });
    }

    let result = "";
    if (modelId.includes('anthropic')) {
      result = data.content?.[0]?.text || "";
    } else if (modelId.includes('meta')) {
      result = data.generation || "";
    } else if (modelId.includes('mistral')) {
      result = data.outputs?.[0]?.text || "";
    } else {
      result = JSON.stringify(data);
    }

    return new Response(JSON.stringify({ result }), {
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
})
