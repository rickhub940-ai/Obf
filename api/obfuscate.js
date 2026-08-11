export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({
      error: "Method Not Allowed"
    });
  }

  try {
    const { code, preset = "Minify" } = req.body || {};

    if (typeof code !== "string" || !code.trim()) {
      return res.status(400).json({
        error: "Missing Lua code"
      });
    }

    const runtime = process.env.PROMETHEUS_URL;

    if (!runtime) {
      return res.status(500).json({
        error: "PROMETHEUS_URL is not configured"
      });
    }

    const response = await fetch(runtime, {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        code,
        preset
      })
    });

    const data = await response.json();

    if (!response.ok) {
      return res.status(response.status).json(data);
    }

    return res.status(200).json(data);

  } catch (error) {
    return res.status(500).json({
      error: error.message
    });
  }
      }
