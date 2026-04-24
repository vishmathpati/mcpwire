import Link from "next/link";

type NavLink = { label: string; href: string };

export function DocsPageNav({ prev, next }: { prev?: NavLink; next?: NavLink }) {
  return (
    <div className="docs-pagination">
      {prev ? (
        <Link className="docs-page-link" href={prev.href}>
          <div className="label">← Previous</div>
          <div className="title">{prev.label}</div>
        </Link>
      ) : <div />}
      {next ? (
        <Link className="docs-page-link next" href={next.href}>
          <div className="label">Next →</div>
          <div className="title">{next.label}</div>
        </Link>
      ) : <div />}
    </div>
  );
}
