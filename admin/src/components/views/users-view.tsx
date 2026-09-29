"use client";

import { Check, Eye, EyeOff, Info, KeyRound, Minus, Pencil, RefreshCw, Search, ShieldCheck, Trash2, UserPlus, Users } from "lucide-react";
import { useMemo, useState, type FormEvent, type ReactNode } from "react";

import { useToast } from "@/components/toast";
import {
  Avatar,
  Badge,
  Button,
  Card,
  CardHeader,
  cn,
  ConfirmModal,
  EmptyState,
  Field,
  IconButton,
  Input,
  Modal,
  PageHeader,
  Select,
  Table,
  TD,
  TH,
  Toggle,
  type Tone,
} from "@/components/ui";
import { ago } from "@/lib/format";
import { newId, useStore } from "@/lib/store";
import { USER_ROLES, type AppUser, type UserRole } from "@/lib/types";

const PANEL_ROLES: UserRole[] = ["Admin", "Manufacturing Engineer"];
const canUsePanel = (r: UserRole) => PANEL_ROLES.includes(r);

const ROLE_TONE: Partial<Record<UserRole, Tone>> = { Admin: "accent", "Manufacturing Engineer": "gold" };

const AREAS = ["Dashboard", "Jobs", "Process stages", "Production board", "Partners", "Inventory", "Users", "Settings"] as const;
type Area = (typeof AREAS)[number];
type Access = "full" | "own";

const grant = (areas: readonly Area[], level: Access = "full") =>
  Object.fromEntries(areas.map((a) => [a, level])) as Partial<Record<Area, Access>>;

/** Default access per role (read-only reference). */
const ACCESS: Record<UserRole, Partial<Record<Area, Access>>> = {
  Admin: grant(AREAS),
  "Manufacturing Engineer": grant(AREAS.filter((a) => a !== "Users" && a !== "Settings")),
  "CAD Designer": grant(["Jobs", "Process stages"]),
  Caster: grant(["Process stages", "Production board"]),
  Setter: grant(["Process stages", "Production board"]),
  "QC Specialist": grant(["Process stages", "Production board"]),
  Logistics: grant(["Jobs", "Process stages"]),
  Retailer: grant(["Jobs"], "own"),
};

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PW_CHARS = "abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789";
/** Only called from event handlers. */
const generatePassword = () => Array.from({ length: 10 }, () => PW_CHARS[Math.floor(Math.random() * PW_CHARS.length)]).join("");
const invalidCls = (error?: string) => (error ? "border-danger focus:border-danger focus:ring-danger/20" : undefined);

export function UsersView() {
  const users = useStore((s) => s.users);
  const session = useStore((s) => s.session);
  const saveUser = useStore((s) => s.saveUser);
  const deleteUser = useStore((s) => s.deleteUser);
  const toast = useToast();

  const [q, setQ] = useState("");
  const [role, setRole] = useState<UserRole | "">("");
  const [editing, setEditing] = useState<AppUser | "new" | null>(null);
  const [resetting, setResetting] = useState<{ user: AppUser; password: string } | null>(null);
  const [deleting, setDeleting] = useState<AppUser | null>(null);

  const perRole = useMemo(
    () =>
      Object.fromEntries(
        USER_ROLES.map((r) => {
          const list = users.filter((u) => u.role === r);
          return [r, { total: list.length, active: list.filter((u) => u.active).length }];
        }),
      ) as Record<UserRole, { total: number; active: number }>,
    [users],
  );

  const shown = useMemo(() => {
    const t = q.trim().toLowerCase();
    return users.filter((u) => (!role || u.role === role) && (!t || [u.name, u.email, u.role].some((v) => v.toLowerCase().includes(t))));
  }, [users, q, role]);

  const setActive = (u: AppUser, active: boolean) => {
    saveUser({ ...u, active });
    toast(active ? `${u.name} reactivated` : `${u.name} deactivated`);
  };

  return (
    <>
      <PageHeader
        eyebrow="Access"
        title="Users & Roles"
        subtitle="Everyone who signs in to DhanaOS — on the mobile app or this panel."
        actions={
          <Button icon={<UserPlus size={16} />} onClick={() => setEditing("new")}>
            Invite User
          </Button>
        }
      />

      {/* Stats per role — click to filter */}
      <div className="mb-6 grid grid-cols-2 gap-3 sm:grid-cols-4 2xl:grid-cols-8">
        {USER_ROLES.map((r) => {
          const s = perRole[r];
          const on = role === r;
          return (
            <button
              key={r}
              type="button"
              aria-pressed={on}
              onClick={() => setRole(on ? "" : r)}
              className={cn(
                "flex flex-col rounded-xl border bg-surface p-4 text-left transition",
                on ? "border-accent ring-2 ring-accent/20" : "border-border hover:border-border-strong",
              )}
            >
              <span className="flex items-start justify-between gap-2">
                <span className="label-caps leading-tight">{r}</span>
                {canUsePanel(r) && <ShieldCheck size={14} className="shrink-0 text-accent" aria-label="Admin panel access" />}
              </span>
              <span className="mt-auto pt-3 text-2xl font-semibold tracking-tight">{s.total}</span>
              <span className="text-xs text-fg-muted">
                {s.total === 0 ? "No users" : s.active === s.total ? "All active" : `${s.active} active`}
              </span>
            </button>
          );
        })}
      </div>

      <Card className="mb-8 overflow-hidden">
        <div className="flex flex-col gap-3 border-b border-border px-5 py-4 sm:flex-row sm:items-center">
          <h2 className="flex items-center gap-2 text-base font-semibold">
            <Users size={18} className="text-accent" /> People
            <span className="font-mono text-xs font-normal text-fg-faint">{shown.length}</span>
          </h2>
          <div className="flex flex-1 flex-col gap-2 sm:flex-row sm:justify-end">
            <div className="relative sm:w-64">
              <Search size={16} className="absolute top-1/2 left-3 -translate-y-1/2 text-fg-faint" />
              <Input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search name or email" className="pl-9" />
            </div>
            <Select value={role} onChange={(e) => setRole(e.target.value as UserRole | "")} className="sm:w-56" aria-label="Filter by role">
              <option value="">All roles</option>
              {USER_ROLES.map((r) => (
                <option key={r} value={r}>
                  {r}
                </option>
              ))}
            </Select>
          </div>
        </div>
        {shown.length === 0 ? (
          <EmptyState
            icon={<Users size={30} />}
            title="No users match"
            message="Try another search or role."
            action={
              <Button
                variant="secondary"
                onClick={() => {
                  setQ("");
                  setRole("");
                }}
              >
                Clear filters
              </Button>
            }
          />
        ) : (
          <Table>
            <thead>
              <tr>
                <TH>User</TH>
                <TH>Role</TH>
                <TH>Status</TH>
                <TH>Last active</TH>
                <TH className="text-right">Actions</TH>
              </tr>
            </thead>
            <tbody>
              {shown.map((u) => {
                const self = u.id === session?.userId;
                return (
                  <tr key={u.id} className="transition hover:bg-surface-low">
                    <TD>
                      <div className="flex items-center gap-3">
                        <Avatar name={u.name} src={u.avatar} size={36} dark />
                        <div className="min-w-0">
                          <div className="flex items-center gap-2 font-semibold whitespace-nowrap">
                            {u.name}
                            {self && <Badge tone="accent">You</Badge>}
                          </div>
                          <div className="text-xs whitespace-nowrap text-fg-muted">{u.email}</div>
                        </div>
                      </div>
                    </TD>
                    <TD>
                      <div className="flex items-center gap-1.5">
                        <Badge tone={ROLE_TONE[u.role] ?? "neutral"} mono={false}>
                          {u.role}
                        </Badge>
                        {canUsePanel(u.role) && <ShieldCheck size={14} className="text-accent" aria-label="Admin panel access" />}
                      </div>
                    </TD>
                    <TD>
                      <Locked locked={self} reason="You can't deactivate your own account">
                        <div className="flex items-center gap-2.5">
                          <Toggle checked={u.active} onChange={(v) => setActive(u, v)} label={`${u.name} active`} />
                          <span className={cn("text-sm font-semibold whitespace-nowrap", u.active ? "text-success" : "text-fg-faint")}>
                            {u.active ? "Active" : "Deactivated"}
                          </span>
                        </div>
                      </Locked>
                    </TD>
                    <TD className="whitespace-nowrap text-fg-muted">
                      {u.lastActive ? ago(u.lastActive) : <span className="text-fg-faint">Never</span>}
                    </TD>
                    <TD>
                      <div className="flex justify-end">
                        <IconButton label={`Edit ${u.name}`} onClick={() => setEditing(u)}>
                          <Pencil size={15} />
                        </IconButton>
                        <IconButton
                          label={`Reset password for ${u.name}`}
                          onClick={() => setResetting({ user: u, password: generatePassword() })}
                        >
                          <KeyRound size={15} />
                        </IconButton>
                        <Locked locked={self} reason="You can't delete your own account">
                          <IconButton label={`Delete ${u.name}`} className="hover:text-danger" onClick={() => setDeleting(u)}>
                            <Trash2 size={15} />
                          </IconButton>
                        </Locked>
                      </div>
                    </TD>
                  </tr>
                );
              })}
            </tbody>
          </Table>
        )}
      </Card>

      <PermissionsCard counts={perRole} />

      {editing && (
        <UserForm key={editing === "new" ? "new" : editing.id} user={editing === "new" ? null : editing} onClose={() => setEditing(null)} />
      )}
      {resetting && (
        <ResetPasswordModal key={resetting.user.id} user={resetting.user} initial={resetting.password} onClose={() => setResetting(null)} />
      )}
      <ConfirmModal
        open={!!deleting}
        onClose={() => setDeleting(null)}
        danger
        title="Delete user?"
        confirmLabel="Delete user"
        message={
          <>
            <strong className="text-fg">{deleting?.name}</strong> ({deleting?.email}) will lose access to DhanaOS
            {deleting && canUsePanel(deleting.role) ? ", including this admin panel" : ""}. This can&apos;t be undone.
          </>
        }
        onConfirm={() => {
          if (!deleting) return;
          deleteUser(deleting.id);
          toast(`${deleting.name} deleted`);
        }}
      />
    </>
  );
}

/** Disables its children and explains why on hover. */
function Locked({ locked, reason, children }: { locked: boolean; reason: string; children: ReactNode }) {
  if (!locked) return <>{children}</>;
  return (
    <span title={reason} className="inline-flex cursor-not-allowed">
      <span aria-disabled className="pointer-events-none opacity-40">
        {children}
      </span>
    </span>
  );
}

// ---------------------------------------------------------------------------
// Roles & permissions matrix

// `!` wins over the TH/TD defaults (px-4, nowrap) so all columns fit on desktop.
const MATRIX_COL = "w-[84px] px-2! text-center whitespace-normal!";

function PermissionsCard({ counts }: { counts: Record<UserRole, { total: number }> }) {
  return (
    <Card>
      <CardHeader
        icon={<ShieldCheck size={18} />}
        title="Roles & permissions"
        subtitle="What each role can open in DhanaOS. These defaults are fixed and shown for reference."
      />
      <div className="flex items-start gap-3 border-b border-border bg-accent-soft/50 px-5 py-3 text-sm">
        <Info size={16} className="mt-0.5 shrink-0 text-accent" />
        <p>
          <span className="font-semibold">Only Admin and Manufacturing Engineer accounts can sign in to this admin panel.</span>{" "}
          <span className="text-fg-muted">Every other role works in the DhanaOS mobile app.</span>
        </p>
      </div>
      <Table>
        <thead>
          <tr>
            <TH>Role</TH>
            {["Admin panel", ...AREAS].map((a) => (
              <TH key={a} className={MATRIX_COL}>
                {a}
              </TH>
            ))}
          </tr>
        </thead>
        <tbody>
          {USER_ROLES.map((r) => (
            <tr key={r}>
              <TD className="whitespace-nowrap">
                <span className="font-semibold">{r}</span>
                <span className="ml-2 font-mono text-xs text-fg-faint">{counts[r].total}</span>
              </TD>
              <TD className={MATRIX_COL}>
                <AccessMark level={canUsePanel(r) ? "full" : undefined} />
              </TD>
              {AREAS.map((a) => (
                <TD key={a} className={MATRIX_COL}>
                  <AccessMark level={ACCESS[r][a]} />
                </TD>
              ))}
            </tr>
          ))}
        </tbody>
      </Table>
      <div className="flex flex-wrap items-center gap-x-5 gap-y-2 px-5 py-3 text-xs text-fg-muted">
        <span className="flex items-center gap-1.5">
          <AccessMark level="full" /> Full access
        </span>
        <span className="flex items-center gap-1.5">
          <AccessMark level="own" /> Own jobs only
        </span>
        <span className="flex items-center gap-1.5">
          <AccessMark /> No access
        </span>
      </div>
    </Card>
  );
}

function AccessMark({ level }: { level?: Access }) {
  if (level === "full") {
    return (
      <span className="inline-flex size-6 items-center justify-center rounded-full bg-success-soft text-success" aria-label="Full access">
        <Check size={14} strokeWidth={3} />
      </span>
    );
  }
  if (level === "own") {
    return (
      <Badge tone="warning" className="px-1.5">
        Own
      </Badge>
    );
  }
  return (
    <span className="inline-flex size-6 items-center justify-center text-fg-faint" aria-label="No access">
      <Minus size={14} />
    </span>
  );
}

// ---------------------------------------------------------------------------
// Modals

function UserForm({ user, onClose }: { user: AppUser | null; onClose: () => void }) {
  const users = useStore((s) => s.users);
  const session = useStore((s) => s.session);
  const saveUser = useStore((s) => s.saveUser);
  const toast = useToast();
  const self = !!user && user.id === session?.userId;

  const [name, setName] = useState(user?.name ?? "");
  const [email, setEmail] = useState(user?.email ?? "");
  const [role, setRole] = useState<UserRole>(user?.role ?? "CAD Designer");
  const [password, setPassword] = useState("");
  const [showPw, setShowPw] = useState(!user);
  const [active, setActive] = useState(user?.active ?? true);
  const [tried, setTried] = useState(false);

  const errors: Partial<Record<"name" | "email" | "password", string>> = {};
  if (!name.trim()) errors.name = "Name is required.";
  if (!email.trim()) errors.email = "Email is required.";
  else if (!EMAIL.test(email.trim())) errors.email = "Enter a valid email address.";
  else if (users.some((u) => u.id !== user?.id && u.email.toLowerCase() === email.trim().toLowerCase()))
    errors.email = "Another user already has this email.";
  if (!user && !password) errors.password = "Set a password for the new user.";
  else if (password && password.length < 6) errors.password = "Use at least 6 characters.";
  const err = (k: keyof typeof errors) => (tried ? errors[k] : undefined);

  const submit = (e: FormEvent) => {
    e.preventDefault();
    setTried(true);
    if (Object.keys(errors).length) return;
    saveUser({
      id: user?.id ?? newId("u"),
      name: name.trim(),
      email: email.trim(),
      role: self ? user.role : role,
      password: password || user?.password || "",
      active: self ? true : active,
      avatar: user?.avatar ?? null,
      lastActive: user?.lastActive ?? null,
    });
    toast(user ? `${name.trim()} updated` : `${name.trim()} invited as ${role}`);
    onClose();
  };

  return (
    <Modal
      open
      onClose={onClose}
      title={user ? "Edit user" : "Invite user"}
      subtitle={user ? user.email : "Create an account and share the sign-in details."}
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" form="user-form">
            {user ? "Save changes" : "Invite user"}
          </Button>
        </>
      }
    >
      <form id="user-form" onSubmit={submit} noValidate className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <Field label="Full name *" hint={<Err>{err("name")}</Err>}>
          <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="Priya Mehta" autoFocus className={invalidCls(err("name"))} />
        </Field>
        <Field label="Email *" hint={<Err>{err("email")}</Err>}>
          <Input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="priya@company.com"
            autoComplete="off"
            className={invalidCls(err("email"))}
          />
        </Field>
        <Field
          label="Role"
          className="sm:col-span-2"
          hint={
            self
              ? "You can't change your own role."
              : canUsePanel(role)
                ? "Can sign in to this admin panel and the mobile app."
                : "Mobile app only — this role can't sign in to the admin panel."
          }
        >
          <Select value={self ? user.role : role} onChange={(e) => setRole(e.target.value as UserRole)} disabled={self}>
            {USER_ROLES.map((r) => (
              <option key={r} value={r}>
                {r}
              </option>
            ))}
          </Select>
        </Field>
        <Field
          label={user ? "New password" : "Password *"}
          className="sm:col-span-2"
          hint={err("password") ? <Err>{err("password")}</Err> : user ? "Leave blank to keep the current password." : "At least 6 characters."}
        >
          <div className="flex gap-2">
            <div className="relative flex-1">
              <Input
                type={showPw ? "text" : "password"}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder={user ? "••••••••" : "Min. 6 characters"}
                autoComplete="new-password"
                className={cn("pr-10 font-mono", invalidCls(err("password")))}
              />
              <button
                type="button"
                aria-label={showPw ? "Hide password" : "Show password"}
                onClick={() => setShowPw((v) => !v)}
                className="absolute top-1/2 right-3 -translate-y-1/2 text-fg-faint hover:text-fg"
              >
                {showPw ? <EyeOff size={16} /> : <Eye size={16} />}
              </button>
            </div>
            <Button
              variant="secondary"
              icon={<RefreshCw size={15} />}
              onClick={() => {
                setPassword(generatePassword());
                setShowPw(true);
              }}
            >
              Generate
            </Button>
          </div>
        </Field>
        <div className="flex items-center justify-between gap-4 rounded-lg border border-border px-4 py-3 sm:col-span-2">
          <div>
            <div className="text-sm font-semibold">Active</div>
            <div className="text-xs text-fg-muted">
              {self ? "You can't deactivate your own account." : "Deactivated users can't sign in anywhere."}
            </div>
          </div>
          <Locked locked={self} reason="You can't deactivate your own account">
            <Toggle checked={self || active} onChange={setActive} label="Active" />
          </Locked>
        </div>
      </form>
    </Modal>
  );
}

function ResetPasswordModal({ user, initial, onClose }: { user: AppUser; initial: string; onClose: () => void }) {
  const saveUser = useStore((s) => s.saveUser);
  const toast = useToast();
  const [password, setPassword] = useState(initial);
  const [tried, setTried] = useState(false);
  const error = password.length < 6 ? "Use at least 6 characters." : undefined;

  const submit = (e: FormEvent) => {
    e.preventDefault();
    setTried(true);
    if (error) return;
    saveUser({ ...user, password });
    toast(`Password reset for ${user.name}`);
    onClose();
  };

  return (
    <Modal
      open
      onClose={onClose}
      size="sm"
      title="Reset password"
      subtitle={`${user.name} · ${user.email}`}
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" form="reset-password" icon={<KeyRound size={15} />}>
            Reset password
          </Button>
        </>
      }
    >
      <form id="reset-password" onSubmit={submit} noValidate className="space-y-4">
        <Field label="New password" hint={tried && error ? <Err>{error}</Err> : "Generated for you — edit it if you like."}>
          <div className="flex gap-2">
            <Input
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoFocus
              className={cn("font-mono", invalidCls(tried ? error : undefined))}
            />
            <IconButton label="Generate another" className="size-10! border border-border-strong" onClick={() => setPassword(generatePassword())}>
              <RefreshCw size={16} />
            </IconButton>
          </div>
        </Field>
        <p className="text-sm text-fg-muted">
          Share it with {user.name} — the old password stops working right away.
          {canUsePanel(user.role) ? "" : " They sign in on the mobile app."}
        </p>
      </form>
    </Modal>
  );
}

function Err({ children }: { children?: string }) {
  return children ? <span className="text-danger">{children}</span> : null;
}
