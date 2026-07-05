const UPSTREAM = "https://raw.githubusercontent.com/coodyapp/fss/main/install.sh";

export default {
  async fetch(request) {
    const { pathname } = new URL(request.url);
    if (pathname !== "/install.sh") {
      return new Response("Not found\n", { status: 404 });
    }

    const upstream = await fetch(UPSTREAM, {
      cf: { cacheTtl: 300, cacheEverything: true },
    });
    if (!upstream.ok) {
      return new Response("install.sh is temporarily unavailable\n", { status: 502 });
    }

    return new Response(upstream.body, {
      status: 200,
      headers: {
        "content-type": "text/x-shellscript; charset=utf-8",
        "cache-control": "public, max-age=300",
      },
    });
  },
};
