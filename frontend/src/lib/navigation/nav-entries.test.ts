import { describe, expect, it, vi } from "vitest";
import { navEntries } from "./nav-entries";

vi.mock("$app/paths", () => ({ resolve: () => "/app/" }));

const labels = (user: { email: string } | null) =>
  navEntries(user).map((entry) => entry.label);

describe("navEntries", () => {
  it("lists the entries in order with a session", () => {
    expect(labels({ email: "a@b.c" })).toEqual([
      "Catálogo",
      "Minha pasta",
      "Baralhos",
      "Sair",
    ]);
  });

  it("lists the entries in order without a session", () => {
    expect(labels(null)).toEqual(["Catálogo", "Entrar", "Criar conta"]);
  });

  it("points the Hotwire destinations at their paths with reload", () => {
    const entries = navEntries({ email: "a@b.c" });
    expect(entries.slice(0, 3)).toEqual([
      { kind: "link", label: "Catálogo", href: "/catalog", reload: true },
      { kind: "link", label: "Minha pasta", href: "/progress", reload: true },
      { kind: "link", label: "Baralhos", href: "/decks", reload: true },
    ]);
  });

  it("points Entrar and Criar conta at app routes without reload", () => {
    expect(navEntries(null).slice(1)).toEqual([
      { kind: "link", label: "Entrar", href: "/app/entrar", reload: false },
      {
        kind: "link",
        label: "Criar conta",
        href: "/app/criar-conta",
        reload: false,
      },
    ]);
  });

  it("makes Sair an action, not a link", () => {
    expect(navEntries({ email: "a@b.c" }).at(-1)).toEqual({
      kind: "action",
      label: "Sair",
    });
  });
});
