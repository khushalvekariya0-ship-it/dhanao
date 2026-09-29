"use client";

import { X } from "lucide-react";
import Image from "next/image";
import Link from "next/link";
import { twMerge } from "tailwind-merge";
import {
  useEffect,
  type ButtonHTMLAttributes,
  type InputHTMLAttributes,
  type ReactNode,
  type SelectHTMLAttributes,
  type TextareaHTMLAttributes,
} from "react";

import { initials } from "@/lib/format";
import { stageInfo } from "@/lib/stages";
import type { Priority, StageKey } from "@/lib/types";

/** Joins classes; later ones win over conflicting earlier ones (e.g. a passed `px-3` beats the default `px-4`). */
export const cn = (...c: (string | false | null | undefined)[]) => twMerge(c.filter(Boolean).join(" "));

// ---------------------------------------------------------------------------
// Buttons

type ButtonVariant = "primary" | "secondary" | "ghost" | "danger" | "accent";

const BUTTON: Record<ButtonVariant, string> = {
  primary: "bg-action text-on-action hover:opacity-90",
  accent: "bg-accent text-on-accent hover:opacity-90",
  secondary: "border border-border-strong bg-surface text-fg hover:bg-surface-low",
  ghost: "text-fg-muted hover:bg-surface-high hover:text-fg",
  danger: "border border-danger/40 bg-danger-soft text-danger hover:bg-danger hover:text-white",
};

export function Button({
  variant = "primary",
  size = "md",
  icon,
  className,
  children,
  ...rest
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: ButtonVariant; size?: "sm" | "md"; icon?: ReactNode }) {
  return (
    <button
      type="button"
      className={cn(
        "inline-flex items-center justify-center gap-2 rounded-lg font-semibold whitespace-nowrap transition disabled:cursor-not-allowed disabled:opacity-40",
        size === "sm" ? "h-8 px-3 text-xs" : "h-10 px-4 text-sm",
        BUTTON[variant],
        className,
      )}
      {...rest}
    >
      {icon}
      {children}
    </button>
  );
}

/** Same styles as Button, for navigation. */
export function ButtonLink({
  href,
  variant = "secondary",
  size = "md",
  icon,
  className,
  children,
}: {
  href: string;
  variant?: ButtonVariant;
  size?: "sm" | "md";
  icon?: ReactNode;
  className?: string;
  children?: ReactNode;
}) {
  return (
    <Link
      href={href}
      className={cn(
        "inline-flex items-center justify-center gap-2 rounded-lg font-semibold whitespace-nowrap transition",
        size === "sm" ? "h-8 px-3 text-xs" : "h-10 px-4 text-sm",
        BUTTON[variant],
        className,
      )}
    >
      {icon}
      {children}
    </Link>
  );
}

export function IconButton({
  label,
  className,
  children,
  ...rest
}: ButtonHTMLAttributes<HTMLButtonElement> & { label: string }) {
  return (
    <button
      type="button"
      aria-label={label}
      title={label}
      className={cn(
        "inline-flex size-9 items-center justify-center rounded-lg text-fg-muted transition hover:bg-surface-high hover:text-fg",
        className,
      )}
      {...rest}
    >
      {children}
    </button>
  );
}

// ---------------------------------------------------------------------------
// Surfaces & text

export function Card({ className, children }: { className?: string; children: ReactNode }) {
  return <div className={cn("rounded-xl border border-border bg-surface", className)}>{children}</div>;
}

export function CardHeader({
  title,
  icon,
  action,
  subtitle,
}: {
  title: ReactNode;
  icon?: ReactNode;
  action?: ReactNode;
  subtitle?: ReactNode;
}) {
  return (
    <div className="flex items-start gap-3 border-b border-border px-5 py-4">
      {icon && <span className="mt-0.5 text-accent">{icon}</span>}
      <div className="min-w-0 flex-1">
        <h2 className="text-base font-semibold">{title}</h2>
        {subtitle && <p className="mt-0.5 text-sm text-fg-muted">{subtitle}</p>}
      </div>
      {action}
    </div>
  );
}

export function PageHeader({
  title,
  subtitle,
  actions,
  eyebrow,
}: {
  title: ReactNode;
  subtitle?: ReactNode;
  actions?: ReactNode;
  eyebrow?: ReactNode;
}) {
  return (
    <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
      <div className="min-w-0">
        {eyebrow && <div className="label-caps mb-1">{eyebrow}</div>}
        <h1 className="text-3xl font-semibold tracking-tight">{title}</h1>
        {subtitle && <p className="mt-1 text-fg-muted">{subtitle}</p>}
      </div>
      {actions && <div className="flex flex-wrap items-center gap-2">{actions}</div>}
    </div>
  );
}

export function StatCard({
  label,
  value,
  hint,
  tone = "neutral",
  icon,
  href,
}: {
  label: string;
  value: ReactNode;
  hint?: ReactNode;
  tone?: Tone;
  icon?: ReactNode;
  href?: string;
}) {
  const body = (
    <Card className={cn("p-5", href && "transition hover:border-border-strong")}>
      <div className="flex items-center gap-2">
        {icon && <span className="text-fg-faint">{icon}</span>}
        <span className="label-caps">{label}</span>
      </div>
      <div className={cn("mt-3 text-3xl font-semibold tracking-tight", TONE_TEXT[tone])}>{value}</div>
      {hint && <div className="mt-1 text-sm text-fg-muted">{hint}</div>}
    </Card>
  );
  return href ? <Link href={href}>{body}</Link> : body;
}

export function EmptyState({ icon, title, message, action }: { icon?: ReactNode; title: string; message?: string; action?: ReactNode }) {
  return (
    <div className="flex flex-col items-center justify-center px-6 py-14 text-center">
      {icon && <div className="mb-3 text-fg-faint">{icon}</div>}
      <p className="font-semibold">{title}</p>
      {message && <p className="mt-1 max-w-sm text-sm text-fg-muted">{message}</p>}
      {action && <div className="mt-4">{action}</div>}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Badges

export type Tone = "neutral" | "accent" | "success" | "warning" | "danger" | "gold" | "info";

const TONE_TEXT: Record<Tone, string> = {
  neutral: "text-fg",
  accent: "text-accent",
  success: "text-success",
  warning: "text-warning",
  danger: "text-danger",
  gold: "text-gold",
  info: "text-info",
};

const TONE_BADGE: Record<Tone, string> = {
  neutral: "border-border-strong bg-surface-low text-fg-muted",
  accent: "border-accent/40 bg-accent-soft text-accent",
  success: "border-success/40 bg-success-soft text-success",
  warning: "border-warning/40 bg-warning-soft text-warning",
  danger: "border-danger/40 bg-danger-soft text-danger",
  gold: "border-gold/40 bg-gold-soft text-gold",
  info: "border-info/40 bg-info/10 text-info",
};

export function Badge({
  tone = "neutral",
  dot,
  mono = true,
  className,
  children,
}: {
  tone?: Tone;
  dot?: boolean;
  mono?: boolean;
  className?: string;
  children: ReactNode;
}) {
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1.5 rounded border px-2 py-0.5 whitespace-nowrap",
        mono ? "font-mono text-[10px] font-bold tracking-wider uppercase" : "text-xs font-semibold",
        TONE_BADGE[tone],
        className,
      )}
    >
      {dot && <span className="size-1.5 rounded-full bg-current" />}
      {children}
    </span>
  );
}

/** Stage chip in the stage's status color. */
export function StageBadge({ stage, full }: { stage: StageKey; full?: boolean }) {
  const s = stageInfo(stage);
  return (
    <span
      className="inline-flex items-center gap-1.5 rounded border px-2 py-0.5 font-mono text-[10px] font-bold tracking-wider whitespace-nowrap uppercase"
      style={{ color: s.color, borderColor: `${s.color}66`, background: `${s.color}1a` }}
    >
      <span className="size-1.5 rounded-full" style={{ background: s.color }} />
      {full ? s.label : s.short}
    </span>
  );
}

const PRIORITY: Record<Priority, { label: string; tone: Tone }> = {
  standard: { label: "Standard", tone: "neutral" },
  high: { label: "High Priority", tone: "danger" },
  rush: { label: "Rush", tone: "warning" },
  critical: { label: "Critical", tone: "danger" },
};

export const priorityLabel = (p: Priority) => PRIORITY[p].label;

export function PriorityBadge({ priority }: { priority: Priority }) {
  return (
    <Badge tone={PRIORITY[priority].tone} mono={false}>
      {PRIORITY[priority].label}
    </Badge>
  );
}

// ---------------------------------------------------------------------------
// Media

export function Avatar({ name, src, size = 36, dark }: { name: string; src?: string | null; size?: number; dark?: boolean }) {
  if (src) {
    return (
      <Image
        src={src.startsWith("data:") || src.startsWith("/") ? src : `/images/${src}`}
        alt={name}
        width={size}
        height={size}
        className="shrink-0 rounded-full object-cover"
        style={{ width: size, height: size }}
        unoptimized={src.startsWith("data:")}
      />
    );
  }
  return (
    <span
      className={cn(
        "inline-flex shrink-0 items-center justify-center rounded-full font-semibold",
        dark ? "bg-nav-active text-on-nav-active" : "bg-surface-highest text-fg-muted",
      )}
      style={{ width: size, height: size, fontSize: size * 0.36 }}
    >
      {initials(name)}
    </span>
  );
}

/** Rounded thumbnail from /images/<name>, a data: URL, or a placeholder. */
export function Thumb({ src, alt, className }: { src?: string | null; alt: string; className?: string }) {
  if (!src) {
    return (
      <div className={cn("flex items-center justify-center rounded-lg bg-surface-high text-fg-faint", className)}>
        <span className="font-mono text-[10px]">NO IMG</span>
      </div>
    );
  }
  const url = src.startsWith("data:") || src.startsWith("/") ? src : `/images/${src}`;
  return (
    // eslint-disable-next-line @next/next/no-img-element -- data: URLs and tiny thumbs
    <img src={url} alt={alt} className={cn("rounded-lg object-cover", className)} />
  );
}

export function ProgressBar({ value, tone = "accent", className }: { value: number; tone?: Tone; className?: string }) {
  const bg: Record<Tone, string> = {
    neutral: "bg-fg-muted",
    accent: "bg-accent",
    success: "bg-success",
    warning: "bg-warning",
    danger: "bg-danger",
    gold: "bg-gold",
    info: "bg-info",
  };
  return (
    <div className={cn("h-1.5 overflow-hidden rounded-full bg-surface-highest", className)}>
      <div className={cn("h-full rounded-full", bg[tone])} style={{ width: `${Math.round(Math.min(1, Math.max(0, value)) * 100)}%` }} />
    </div>
  );
}

// ---------------------------------------------------------------------------
// Forms

const FIELD =
  "w-full rounded-lg border border-border bg-surface px-3 py-2 text-sm text-fg outline-none transition placeholder:text-fg-faint focus:border-accent focus:ring-2 focus:ring-accent/20 disabled:opacity-60";

export function Field({ label, hint, children, className }: { label: string; hint?: ReactNode; children: ReactNode; className?: string }) {
  return (
    <label className={cn("block", className)}>
      <span className="label-caps mb-1.5 block">{label}</span>
      {children}
      {hint && <span className="mt-1 block text-xs text-fg-faint">{hint}</span>}
    </label>
  );
}

export function Input({ className, ...rest }: InputHTMLAttributes<HTMLInputElement>) {
  return <input className={cn(FIELD, "h-10", className)} {...rest} />;
}

export function Textarea({ className, ...rest }: TextareaHTMLAttributes<HTMLTextAreaElement>) {
  return <textarea className={cn(FIELD, "min-h-24", className)} {...rest} />;
}

export function Select({ className, children, ...rest }: SelectHTMLAttributes<HTMLSelectElement>) {
  return (
    <select className={cn(FIELD, "h-10 pr-8", className)} {...rest}>
      {children}
    </select>
  );
}

export function Toggle({ checked, onChange, label }: { checked: boolean; onChange: (v: boolean) => void; label?: string }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      onClick={() => onChange(!checked)}
      className={cn("relative h-6 w-11 shrink-0 rounded-full transition", checked ? "bg-accent" : "bg-surface-highest")}
    >
      <span
        className={cn("absolute top-0.5 size-5 rounded-full bg-white shadow transition-all", checked ? "left-[22px]" : "left-0.5")}
      />
    </button>
  );
}

export function Segmented<T extends string>({
  options,
  value,
  onChange,
  className,
}: {
  options: { value: T; label: ReactNode }[];
  value: T;
  onChange: (v: T) => void;
  className?: string;
}) {
  return (
    <div className={cn("inline-flex rounded-lg bg-surface-high p-1", className)}>
      {options.map((o) => (
        <button
          key={o.value}
          type="button"
          onClick={() => onChange(o.value)}
          className={cn(
            "rounded-md px-3 py-1.5 text-sm font-semibold transition",
            o.value === value ? "bg-surface text-fg shadow-sm" : "text-fg-faint hover:text-fg",
          )}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}

export function Tabs<T extends string>({
  tabs,
  value,
  onChange,
}: {
  tabs: { value: T; label: ReactNode; count?: number }[];
  value: T;
  onChange: (v: T) => void;
}) {
  return (
    <div className="flex gap-1 overflow-x-auto border-b border-border">
      {tabs.map((t) => (
        <button
          key={t.value}
          type="button"
          onClick={() => onChange(t.value)}
          className={cn(
            "-mb-px border-b-2 px-4 py-2.5 text-sm font-semibold whitespace-nowrap transition",
            t.value === value ? "border-accent text-fg" : "border-transparent text-fg-faint hover:text-fg",
          )}
        >
          {t.label}
          {t.count !== undefined && <span className="ml-1.5 font-mono text-xs text-fg-faint">{t.count}</span>}
        </button>
      ))}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Tables

export function Table({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <div className={cn("overflow-x-auto", className)}>
      <table className="w-full text-left text-sm">{children}</table>
    </div>
  );
}
export const TH = ({ children, className }: { children?: ReactNode; className?: string }) => (
  <th className={cn("label-caps border-b border-border bg-surface-low px-4 py-3 whitespace-nowrap", className)}>{children}</th>
);
export const TD = ({ children, className }: { children?: ReactNode; className?: string }) => (
  <td className={cn("border-b border-border px-4 py-3 align-middle", className)}>{children}</td>
);

// ---------------------------------------------------------------------------
// Overlays — every overlay has an explicit close (✕) button, Esc and backdrop click.

function useEscape(open: boolean, onClose: () => void) {
  useEffect(() => {
    if (!open) return;
    const h = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", h);
    return () => window.removeEventListener("keydown", h);
  }, [open, onClose]);
}

export function Modal({
  open,
  onClose,
  title,
  subtitle,
  children,
  footer,
  size = "md",
}: {
  open: boolean;
  onClose: () => void;
  title: ReactNode;
  subtitle?: ReactNode;
  children: ReactNode;
  footer?: ReactNode;
  size?: "sm" | "md" | "lg";
}) {
  useEscape(open, onClose);
  if (!open) return null;
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-black/50 backdrop-blur-sm" onClick={onClose} />
      <div
        role="dialog"
        aria-modal="true"
        className={cn(
          "relative flex max-h-[90vh] w-full flex-col rounded-2xl border border-border bg-surface shadow-2xl",
          size === "sm" ? "max-w-md" : size === "lg" ? "max-w-3xl" : "max-w-xl",
        )}
      >
        <div className="flex items-start gap-3 border-b border-border px-6 py-4">
          <div className="min-w-0 flex-1">
            <h2 className="text-lg font-semibold">{title}</h2>
            {subtitle && <p className="mt-0.5 text-sm text-fg-muted">{subtitle}</p>}
          </div>
          <IconButton label="Close" onClick={onClose}>
            <X size={18} />
          </IconButton>
        </div>
        <div className="overflow-y-auto px-6 py-5">{children}</div>
        {footer && <div className="flex justify-end gap-2 border-t border-border px-6 py-4">{footer}</div>}
      </div>
    </div>
  );
}

/** Right-side panel for details / edit forms. */
export function Drawer({
  open,
  onClose,
  title,
  subtitle,
  children,
  footer,
  width = 480,
}: {
  open: boolean;
  onClose: () => void;
  title: ReactNode;
  subtitle?: ReactNode;
  children: ReactNode;
  footer?: ReactNode;
  width?: number;
}) {
  useEscape(open, onClose);
  if (!open) return null;
  return (
    <div className="fixed inset-0 z-50">
      <div className="absolute inset-0 bg-black/40" onClick={onClose} />
      <aside
        role="dialog"
        aria-modal="true"
        className="absolute top-0 right-0 flex h-full w-full flex-col border-l border-border bg-bg shadow-2xl"
        style={{ maxWidth: width }}
      >
        <div className="flex items-start gap-3 border-b border-border bg-surface px-6 py-4">
          <div className="min-w-0 flex-1">
            <h2 className="text-lg font-semibold">{title}</h2>
            {subtitle && <div className="mt-0.5 text-sm text-fg-muted">{subtitle}</div>}
          </div>
          <IconButton label="Close" onClick={onClose}>
            <X size={18} />
          </IconButton>
        </div>
        <div className="flex-1 overflow-y-auto px-6 py-5">{children}</div>
        {footer && <div className="flex justify-end gap-2 border-t border-border bg-surface px-6 py-4">{footer}</div>}
      </aside>
    </div>
  );
}

export function ConfirmModal({
  open,
  onClose,
  onConfirm,
  title,
  message,
  confirmLabel = "Confirm",
  danger,
}: {
  open: boolean;
  onClose: () => void;
  onConfirm: () => void;
  title: string;
  message: ReactNode;
  confirmLabel?: string;
  danger?: boolean;
}) {
  return (
    <Modal
      open={open}
      onClose={onClose}
      title={title}
      size="sm"
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            Cancel
          </Button>
          <Button
            variant={danger ? "danger" : "primary"}
            onClick={() => {
              onConfirm();
              onClose();
            }}
          >
            {confirmLabel}
          </Button>
        </>
      }
    >
      <p className="text-sm text-fg-muted">{message}</p>
    </Modal>
  );
}
