import { resolve } from "$app/paths";
import type { SessionUser } from "../api/types";

export type NavEntry =
  | { kind: "link"; label: string; href: string; reload: boolean }
  | { kind: "action"; label: string };

// `resolve('/entrar')` só tipa quando a rota existir (T16/T17); o prefixo vem de `resolve('/')`.
export const appPath = (path: string) => `${resolve("/")}${path.replace(/^\//, "")}`;

const inApp = (label: string, path: string): NavEntry => ({
  kind: "link",
  label,
  href: appPath(path),
  reload: false,
});

export function navEntries(user: SessionUser | null): NavEntry[] {
  const catalog = inApp("Catálogo", "");
  if (!user)
    return [
      catalog,
      inApp("Entrar", "/entrar"),
      inApp("Criar conta", "/criar-conta"),
    ];
  return [
    catalog,
    inApp("Minha pasta", "/pasta"),
    inApp("Baralhos", "/baralhos"),
    { kind: "action", label: "Sair" },
  ];
}
