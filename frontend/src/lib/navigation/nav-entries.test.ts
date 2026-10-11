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

  it("points Catálogo at /app without reload, with and without a session", () => {
    const catalog = {
      kind: "link",
      label: "Catálogo",
      href: "/app",
      reload: false,
    };
    expect(navEntries({ email: "a@b.c" })[0]).toEqual(catalog);
    expect(navEntries(null)[0]).toEqual(catalog);
  });

  it("points Minha pasta at the app route without reload", () => {
    expect(navEntries({ email: "a@b.c" })[1]).toEqual({
      kind: "link",
      label: "Minha pasta",
      href: "/app/pasta",
      reload: false,
    });
  });

  it("points Baralhos at its Hotwire path with reload", () => {
    expect(navEntries({ email: "a@b.c" })[2]).toEqual({
      kind: "link",
      label: "Baralhos",
      href: "/decks",
      reload: true,
    });
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
