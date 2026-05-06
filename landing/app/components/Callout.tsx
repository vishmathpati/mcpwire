export function Callout({
  kind = "info",
  title,
  children,
}: {
  kind?: "info" | "warn" | "tip" | "danger";
  title?: string;
  children: React.ReactNode;
}) {
  const icon = { info: "ℹ", warn: "⚠", tip: "💡", danger: "⛔" }[kind];
  return (
    <div className={`callout callout-${kind}`}>
      <div className="callout-icon">{icon}</div>
      <div>
        {title ? <strong>{title}.</strong> : null} {children}
      </div>
    </div>
  );
}
