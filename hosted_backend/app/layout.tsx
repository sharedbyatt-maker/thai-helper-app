import type { Metadata } from 'next';
export const metadata: Metadata = { title: 'ဘတ်ဈေး', description: 'ထိုင်းဘတ် နှင့် မြန်မာကျပ် ငွေလဲနှုန်း' };
export default function RootLayout({children}: {children: React.ReactNode}) {
 return <html lang="my"><body style={{fontFamily:'system-ui,sans-serif',margin:0}}>{children}</body></html>;
}
