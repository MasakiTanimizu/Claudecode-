import type { Metadata } from "next";
import Link from "next/link";
import "./globals.css";

export const metadata: Metadata = {
  title: "近畿釣果ニュースAI",
  description: "兵庫・大阪・和歌山の釣果情報をAIが分析する釣りコンシェルジュアプリ",
};

const navItems = [
  { href: "/", label: "ホーム" },
  { href: "/fishing-reports", label: "釣果情報" },
  { href: "/fishing-reports/new", label: "釣果を登録" },
  { href: "/fish-species", label: "魚種" },
  { href: "/fishing-spots", label: "釣り場" },
];

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="ja">
      <body className="min-h-screen bg-slate-50 text-slate-900">
        <header className="sticky top-0 z-10 border-b border-slate-200 bg-white/90 backdrop-blur">
          <div className="mx-auto flex max-w-3xl items-center justify-between px-4 py-3">
            <Link href="/" className="font-bold text-ocean-700">
              近畿釣果ニュースAI
            </Link>
            <nav className="flex gap-3 overflow-x-auto text-sm text-slate-600">
              {navItems.map((item) => (
                <Link
                  key={item.href}
                  href={item.href}
                  className="whitespace-nowrap hover:text-ocean-600"
                >
                  {item.label}
                </Link>
              ))}
            </nav>
          </div>
        </header>
        <main className="mx-auto max-w-3xl px-4 py-6">{children}</main>
        <footer className="mx-auto max-w-3xl px-4 py-8 text-xs text-slate-400">
          本アプリのAI予測・AI推定は実測値を保証するものではありません。
        </footer>
      </body>
    </html>
  );
}
