import type { Metadata } from "next";
import { Hanken_Grotesk, JetBrains_Mono } from "next/font/google";
import "./globals.css";

const hanken = Hanken_Grotesk({ variable: "--font-hanken", subsets: ["latin"], weight: ["400", "500", "600", "700"] });
const jetbrains = JetBrains_Mono({ variable: "--font-jetbrains", subsets: ["latin"], weight: ["400", "500", "700"] });

export const metadata: Metadata = {
  title: { default: "DhanaOS Admin", template: "%s · DhanaOS Admin" },
  description: "Admin panel for the DhanaOS jewelry production app.",
  icons: { icon: "/images/logo.png" },
};

// Applies the saved theme before first paint (no light→dark flash).
const themeScript = `try{var s=JSON.parse(localStorage.getItem("dhanaos-admin-v1")||"{}");if(s.state&&s.state.settings&&s.state.settings.theme==="dark")document.documentElement.classList.add("dark")}catch(e){}`;

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en" className={`${hanken.variable} ${jetbrains.variable} h-full antialiased`} suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeScript }} />
      </head>
      <body className="min-h-full bg-bg font-sans text-fg">{children}</body>
    </html>
  );
}
