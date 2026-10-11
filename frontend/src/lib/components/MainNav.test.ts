import "@testing-library/jest-dom/vitest";
import { cleanup, fireEvent, render, screen } from "@testing-library/svelte";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { ApiError } from "../api/errors";
import { session } from "../session.svelte";
import { toasts } from "../toasts.svelte";
import MainNav from "./MainNav.svelte";

const mocks = vi.hoisted(() => ({ pathname: "/app/entrar", signOut: vi.fn() }));

vi.mock("$app/paths", () => ({ resolve: () => "/app/" }));
vi.mock("$app/state", () => ({
  page: {
    get url() {
      return new URL(`http://localhost${mocks.pathname}`);
    },
  },
}));
vi.mock("../session.svelte", async (importOriginal) => ({
  ...(await importOriginal<typeof import("../session.svelte")>()),
  signOut: mocks.signOut,
}));

describe("MainNav", () => {
  beforeEach(() => {
    mocks.pathname = "/app/entrar";
    mocks.signOut.mockReset();
    session.user = null;
    toasts.length = 0;
  });
  afterEach(cleanup);

  it("is the Principal navigation landmark", () => {
    render(MainNav);
    expect(
      screen.getByRole("navigation", { name: "Principal" }),
    ).toBeInTheDocument();
  });

  it("marks only the entry of the current route", () => {
    render(MainNav);
    const current = screen
      .getAllByRole("link")
      .filter((link) => link.hasAttribute("aria-current"));
    expect(current).toHaveLength(1);
    expect(current[0]).toHaveTextContent("Entrar");
    expect(current[0]).toHaveAttribute("aria-current", "page");
  });

  it("ignores a trailing slash when marking the current route", () => {
    mocks.pathname = "/app/entrar/";
    render(MainNav);
    expect(screen.getByRole("link", { name: "Entrar" })).toHaveAttribute(
      "aria-current",
      "page",
    );
  });

  it.each(["/app", "/app?colors%5B%5D=Red"])(
    "marks only Catálogo as current at %s",
    (path) => {
      mocks.pathname = path;
      render(MainNav);
      const current = screen
        .getAllByRole("link")
        .filter((link) => link.hasAttribute("aria-current"));
      expect(current).toHaveLength(1);
      expect(current[0]).toHaveTextContent("Catálogo");
      expect(current[0]).toHaveAttribute("aria-current", "page");
    },
  );

  it("never marks Hotwire entries as current", () => {
    session.user = { email: "a@b.c" };
    mocks.pathname = "/progress";
    render(MainNav);
    expect(
      screen.getByRole("link", { name: "Minha pasta" }),
    ).not.toHaveAttribute("aria-current");
  });

  it("reloads the page on Hotwire links only", () => {
    session.user = { email: "a@b.c" };
    render(MainNav);
    expect(screen.getByRole("link", { name: "Minha pasta" })).toHaveAttribute(
      "data-sveltekit-reload",
    );
    expect(screen.getByRole("link", { name: "Catálogo" })).not.toHaveAttribute(
      "data-sveltekit-reload",
    );
    expect(screen.getByRole("link", { name: "Baralhos" })).toHaveAttribute(
      "data-sveltekit-reload",
    );
  });

  it("renders Sair as a button that calls signOut", async () => {
    session.user = { email: "a@b.c" };
    render(MainNav);
    expect(screen.queryByRole("link", { name: "Sair" })).toBeNull();
    await fireEvent.click(screen.getByRole("button", { name: "Sair" }));
    expect(mocks.signOut).toHaveBeenCalledOnce();
  });

  it("reports a signOut ApiError as an error toast", async () => {
    session.user = { email: "a@b.c" };
    mocks.signOut.mockRejectedValue(
      new ApiError(500, "internal_error", "Falhou.", {}),
    );
    render(MainNav);
    await fireEvent.click(screen.getByRole("button", { name: "Sair" }));
    await vi.waitFor(() =>
      expect(toasts.map((t) => t.message)).toEqual(["Falhou."]),
    );
  });
});
