import { NextResponse, type NextRequest } from "next/server";

// Optimistic auth check (frontend-only demo): the login page sets this cookie.
const SESSION_COOKIE = "dhanaos_session";

export function proxy(request: NextRequest) {
  const signedIn = request.cookies.get(SESSION_COOKIE)?.value === "1";
  const onLogin = request.nextUrl.pathname === "/login";
  if (!signedIn && !onLogin) return NextResponse.redirect(new URL("/login", request.url));
  if (signedIn && onLogin) return NextResponse.redirect(new URL("/", request.url));
  return NextResponse.next();
}

export const config = {
  // Everything except Next internals, static images and the favicon.
  matcher: ["/((?!_next/static|_next/image|images/|favicon.ico).*)"],
};
