export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR">
      <body style={{ fontFamily: "system-ui, sans-serif", margin: "2rem", maxWidth: 720 }}>
        {children}
      </body>
    </html>
  );
}
