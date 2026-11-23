import { NextRequest, NextResponse } from "next/server";

function hostOnly(value: string) {
  return value.toLowerCase().split(":")[0];
}

export function middleware(request: NextRequest) {
  const host = hostOnly(request.headers.get("host") || "");
  const appUrlHost = process.env.NEXT_PUBLIC_APP_URL ? hostOnly(new URL(process.env.NEXT_PUBLIC_APP_URL).host) : "";
  const configuredHosts = (process.env.APP_HOSTNAMES || "").split(",").map((item) => hostOnly(item.trim())).filter(Boolean);
  const knownHosts = new Set([appUrlHost, ...configuredHosts, "localhost", "127.0.0.1"]);

  if (!host || knownHosts.has(host) || host.endsWith(".onrender.com") || host.endsWith(".vercel.app")) {
    return NextResponse.next();
  }

  const path = request.nextUrl.pathname;
  if (path.startsWith("/_next/") || path.startsWith("/api/") || path === "/favicon.ico" || path === "/robots.txt") {
    return NextResponse.next();
  }

  const url = request.nextUrl.clone();
  url.pathname = `/domain/${encodeURIComponent(host)}${path}`;
  return NextResponse.rewrite(url);
}

export const config = {
  matcher: ["/((?!_next/static|_next/image).*)"],
};
