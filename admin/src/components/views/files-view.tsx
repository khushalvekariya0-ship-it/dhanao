"use client";

import {
  CloudUpload,
  Download,
  Eye,
  FileAxis3d,
  FileHeadphone,
  FileImage,
  FileSpreadsheet,
  FileText,
  FolderOpen,
  LayoutGrid,
  List,
  Search,
  Trash,
  Upload,
  type LucideIcon,
} from "lucide-react";
import Link from "next/link";
import { useMemo, useState } from "react";

import { useToast } from "@/components/toast";
import {
  Badge,
  Button,
  ButtonLink,
  Card,
  cn,
  ConfirmModal,
  EmptyState,
  Field,
  IconButton,
  Input,
  Modal,
  PageHeader,
  Segmented,
  Select,
  Table,
  TD,
  TH,
  Thumb,
  type Tone,
} from "@/components/ui";
import { date, dateLong, time } from "@/lib/format";
import { useStore } from "@/lib/store";
import type { FileKind, Job, ProjectFile } from "@/lib/types";

interface Row {
  key: string;
  file: ProjectFile;
  /** index in job.files — what removeFile expects */
  index: number;
  job: Job;
}

type KindFilter = "all" | FileKind;

const KIND: Record<FileKind, { label: string; plural: string; icon: LucideIcon; tone: Tone; text: string; bg: string }> = {
  image: { label: "Image", plural: "Images", icon: FileImage, tone: "info", text: "text-info", bg: "bg-info/10" },
  cad: { label: "CAD", plural: "CAD", icon: FileAxis3d, tone: "accent", text: "text-accent", bg: "bg-accent-soft" },
  pdf: { label: "PDF", plural: "PDF", icon: FileText, tone: "danger", text: "text-danger", bg: "bg-danger-soft" },
  sheet: { label: "Sheet", plural: "Sheets", icon: FileSpreadsheet, tone: "success", text: "text-success", bg: "bg-success-soft" },
  audio: { label: "Audio", plural: "Audio", icon: FileHeadphone, tone: "gold", text: "text-gold", bg: "bg-gold-soft" },
};
const KINDS = Object.keys(KIND) as FileKind[];

const srcOf = (f: ProjectFile) => f.dataUrl || f.asset || null;
const urlOf = (f: ProjectFile) => {
  const s = srcOf(f);
  return !s ? null : s.startsWith("data:") || s.startsWith("/") ? s : `/images/${s}`;
};
const plural = (n: number, w: string) => `${n} ${w}${n === 1 ? "" : "s"}`;
const ext = (name: string) => (name.includes(".") ? name.split(".").pop()!.toUpperCase() : "FILE");

export function FilesView() {
  const jobs = useStore((s) => s.jobs);
  const removeFile = useStore((s) => s.removeFile);
  const toast = useToast();

  const [q, setQ] = useState("");
  const [kind, setKind] = useState<KindFilter>("all");
  const [view, setView] = useState<"grid" | "table">("grid");
  const [preview, setPreview] = useState<Row | null>(null);
  const [confirm, setConfirm] = useState<Row | null>(null);
  const [uploading, setUploading] = useState(false);

  const rows = useMemo<Row[]>(
    () =>
      jobs
        .flatMap((job) => job.files.map((file, index) => ({ key: `${job.id}:${index}:${file.name}`, file, index, job })))
        .sort((a, b) => Date.parse(b.file.date) - Date.parse(a.file.date)),
    [jobs],
  );

  const shown = useMemo(() => {
    const t = q.trim().toLowerCase();
    return rows.filter(
      (r) =>
        (kind === "all" || r.file.kind === kind) &&
        (!t || [r.file.name, r.job.id, r.job.title, r.file.uploadedBy].some((v) => v.toLowerCase().includes(t))),
    );
  }, [rows, q, kind]);

  const count = (k: FileKind) => rows.filter((r) => r.file.kind === k).length;

  return (
    <>
      <PageHeader
        title="Files"
        subtitle={`${plural(rows.length, "file")} across ${plural(new Set(rows.map((r) => r.job.id)).size, "job")}`}
        actions={
          <Button icon={<Upload size={16} />} onClick={() => setUploading(true)}>
            Upload
          </Button>
        }
      />

      <div className="mb-5 flex flex-wrap items-center gap-3">
        <div className="relative min-w-0 flex-1 sm:w-72 sm:flex-none">
          <Search size={16} className="absolute top-1/2 left-3 -translate-y-1/2 text-fg-faint" />
          <Input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search name, job or uploader" className="pl-9" />
        </div>
        <div className="order-last w-full overflow-x-auto sm:order-none sm:w-auto">
          <Segmented<KindFilter>
            value={kind}
            onChange={setKind}
            options={[
              { value: "all", label: <Count label="All" n={rows.length} /> },
              ...KINDS.map((k) => ({ value: k, label: <Count label={KIND[k].plural} n={count(k)} /> })),
            ]}
          />
        </div>
        <Segmented<"grid" | "table">
          className="ml-auto"
          value={view}
          onChange={setView}
          options={[
            { value: "grid", label: <LayoutGrid size={16} aria-label="Grid view" /> },
            { value: "table", label: <List size={16} aria-label="Table view" /> },
          ]}
        />
      </div>

      {rows.length === 0 ? (
        <Card>
          <EmptyState
            icon={<FolderOpen size={32} />}
            title="No files yet"
            message="Files uploaded to jobs, in the app or here, show up in this library."
            action={
              <Button icon={<Upload size={16} />} onClick={() => setUploading(true)}>
                Upload a file
              </Button>
            }
          />
        </Card>
      ) : shown.length === 0 ? (
        <Card>
          <EmptyState
            icon={<Search size={28} />}
            title="No files match"
            message="Try another search or file type."
            action={
              <Button
                variant="secondary"
                onClick={() => {
                  setQ("");
                  setKind("all");
                }}
              >
                Clear filters
              </Button>
            }
          />
        </Card>
      ) : view === "grid" ? (
        <div className="grid grid-cols-1 gap-4 min-[480px]:grid-cols-2 md:grid-cols-3 xl:grid-cols-4">
          {shown.map((r) => (
            <FileCard key={r.key} row={r} onPreview={() => setPreview(r)} onDelete={() => setConfirm(r)} />
          ))}
        </div>
      ) : (
        <Card className="overflow-hidden">
          <FileTable rows={shown} onPreview={setPreview} onDelete={setConfirm} />
        </Card>
      )}

      {preview && (
        <PreviewModal
          row={preview}
          onClose={() => setPreview(null)}
          onDelete={() => {
            setConfirm(preview);
            setPreview(null);
          }}
        />
      )}

      <ConfirmModal
        open={!!confirm}
        onClose={() => setConfirm(null)}
        danger
        title="Delete file?"
        confirmLabel="Delete"
        message={
          confirm && (
            <>
              <span className="font-semibold text-fg">{confirm.file.name}</span> will be removed from{" "}
              <span className="font-mono">{confirm.job.id}</span>. This can’t be undone.
            </>
          )
        }
        onConfirm={() => {
          if (!confirm) return;
          removeFile(confirm.job.id, confirm.index);
          setPreview(null);
          toast(`Deleted ${confirm.file.name}`);
        }}
      />

      {uploading && <UploadModal jobs={jobs} onClose={() => setUploading(false)} />}
    </>
  );
}

function Count({ label, n }: { label: string; n: number }) {
  return (
    <span className="whitespace-nowrap">
      {label} <span className="font-mono text-xs opacity-60">{n}</span>
    </span>
  );
}

/** Image thumbnail, or the file-type icon for everything else. */
function FilePreview({ file, className, iconSize = 36 }: { file: ProjectFile; className?: string; iconSize?: number }) {
  const src = srcOf(file);
  if (src) return <Thumb src={src} alt={file.name} className={className} />;
  const k = KIND[file.kind] ?? KIND.pdf;
  if (iconSize < 28) {
    return (
      <div className={cn("flex items-center justify-center rounded-lg", k.bg, k.text, className)}>
        <k.icon size={iconSize} strokeWidth={1.5} />
      </div>
    );
  }
  return (
    <div className={cn("flex flex-col items-center justify-center gap-2 rounded-lg bg-surface-low", className)}>
      <span className={cn("flex items-center justify-center rounded-2xl p-4", k.bg, k.text)}>
        <k.icon size={iconSize} strokeWidth={1.5} />
      </span>
      <span className="font-mono text-[11px] font-bold tracking-wider text-fg-faint">.{ext(file.name)}</span>
    </div>
  );
}

function FileCard({ row: r, onPreview, onDelete }: { row: Row; onPreview: () => void; onDelete: () => void }) {
  const k = KIND[r.file.kind] ?? KIND.pdf;
  const url = urlOf(r.file);
  return (
    <Card className="group flex flex-col p-2 transition hover:border-border-strong">
      <button type="button" onClick={onPreview} className="relative block overflow-hidden rounded-lg" aria-label={`Preview ${r.file.name}`}>
        <FilePreview file={r.file} className="aspect-[16/10] w-full transition group-hover:scale-[1.02] min-[480px]:aspect-[4/3]" iconSize={32} />
        <span className="absolute top-2 left-2">
          <Badge tone={k.tone} className="bg-surface/90 backdrop-blur">
            {k.label}
          </Badge>
        </span>
      </button>
      <div className="flex flex-1 flex-col px-2 pt-3 pb-1">
        <p className="truncate text-sm font-semibold" title={r.file.name}>
          {r.file.name}
        </p>
        <p className="mt-0.5 truncate text-xs text-fg-muted">
          <Link href={`/jobs/${r.job.id}`} className="font-mono text-accent hover:underline">
            {r.job.id}
          </Link>{" "}
          · {r.job.title}
        </p>
        <div className="mt-3 flex items-center gap-1 border-t border-border pt-2">
          <div className="min-w-0 flex-1 text-xs text-fg-faint">
            <div className="truncate">{r.file.uploadedBy}</div>
            <div className="font-mono">
              {date(r.file.date)} · {r.file.sizeLabel}
            </div>
          </div>
          <IconButton label="Preview" onClick={onPreview} className="size-8">
            <Eye size={16} />
          </IconButton>
          {url && (
            <a
              href={url}
              download={r.file.name}
              aria-label="Download"
              title="Download"
              className="inline-flex size-8 items-center justify-center rounded-lg text-fg-muted transition hover:bg-surface-high hover:text-fg"
            >
              <Download size={16} />
            </a>
          )}
          <IconButton label="Delete" onClick={onDelete} className="size-8 hover:bg-danger-soft hover:text-danger">
            <Trash size={16} />
          </IconButton>
        </div>
      </div>
    </Card>
  );
}

function FileTable({ rows, onPreview, onDelete }: { rows: Row[]; onPreview: (r: Row) => void; onDelete: (r: Row) => void }) {
  return (
    <Table>
      <thead>
        <tr>
          <TH>File</TH>
          <TH>Type</TH>
          <TH>Job</TH>
          <TH>Uploaded by</TH>
          <TH>Date</TH>
          <TH className="text-right">Size</TH>
          <TH className="text-right">
            <span className="sr-only">Actions</span>
          </TH>
        </tr>
      </thead>
      <tbody>
        {rows.map((r) => {
          const k = KIND[r.file.kind] ?? KIND.pdf;
          return (
            <tr key={r.key} className="transition hover:bg-surface-low">
              <TD>
                <button type="button" onClick={() => onPreview(r)} className="flex items-center gap-3 text-left">
                  <FilePreview file={r.file} className="size-10 shrink-0" iconSize={20} />
                  <span className="max-w-64 truncate font-semibold hover:underline">{r.file.name}</span>
                </button>
              </TD>
              <TD>
                <Badge tone={k.tone}>{k.label}</Badge>
              </TD>
              <TD>
                <Link href={`/jobs/${r.job.id}`} className="font-mono text-accent hover:underline">
                  {r.job.id}
                </Link>
                <div className="max-w-56 truncate text-xs text-fg-muted">{r.job.title}</div>
              </TD>
              <TD className="whitespace-nowrap text-fg-muted">{r.file.uploadedBy}</TD>
              <TD className="whitespace-nowrap">
                <div>{dateLong(r.file.date)}</div>
                <div className="font-mono text-xs text-fg-faint">{time(r.file.date)}</div>
              </TD>
              <TD className="text-right font-mono text-xs whitespace-nowrap text-fg-muted">{r.file.sizeLabel}</TD>
              <TD>
                <div className="flex justify-end gap-0.5">
                  <IconButton label="Preview" onClick={() => onPreview(r)} className="size-8">
                    <Eye size={16} />
                  </IconButton>
                  <IconButton label="Delete" onClick={() => onDelete(r)} className="size-8 hover:bg-danger-soft hover:text-danger">
                    <Trash size={16} />
                  </IconButton>
                </div>
              </TD>
            </tr>
          );
        })}
      </tbody>
    </Table>
  );
}

function PreviewModal({ row: r, onClose, onDelete }: { row: Row; onClose: () => void; onDelete: () => void }) {
  const k = KIND[r.file.kind] ?? KIND.pdf;
  const url = urlOf(r.file);
  return (
    <Modal
      open
      onClose={onClose}
      size="lg"
      title={<span className="break-all">{r.file.name}</span>}
      subtitle={
        <>
          {k.label} · <span className="font-mono">{r.job.id}</span> · {r.job.title}
        </>
      }
      footer={
        <>
          <Button variant="danger" icon={<Trash size={15} />} onClick={onDelete} className="mr-auto">
            Delete
          </Button>
          <ButtonLink href={`/jobs/${r.job.id}`}>Open job</ButtonLink>
          {url && (
            <a
              href={url}
              download={r.file.name}
              className="inline-flex h-10 items-center gap-2 rounded-lg bg-action px-4 text-sm font-semibold text-on-action transition hover:opacity-90"
            >
              <Download size={16} />
              Download
            </a>
          )}
        </>
      }
    >
      {url ? (
        // eslint-disable-next-line @next/next/no-img-element -- data: URLs
        <img src={url} alt={r.file.name} className="max-h-[55vh] w-full rounded-lg bg-surface-low object-contain" />
      ) : (
        <div className="flex flex-col items-center justify-center gap-2 rounded-lg bg-surface-low py-10">
          <span className={cn("flex items-center justify-center rounded-2xl p-5", k.bg, k.text)}>
            <k.icon size={48} strokeWidth={1.25} />
          </span>
          <span className="font-mono text-xs font-bold tracking-wider text-fg-faint">.{ext(r.file.name)}</span>
          <p className="mt-1 max-w-xs text-center text-sm text-fg-muted">
            No preview for this file type. Only its details are stored in this demo.
          </p>
        </div>
      )}
      <dl className="mt-5 grid grid-cols-1 gap-x-6 gap-y-3 text-sm sm:grid-cols-2">
        <Detail label="Type">{k.label}</Detail>
        <Detail label="Size">
          <span className="font-mono">{r.file.sizeLabel}</span>
        </Detail>
        <Detail label="Uploaded by">{r.file.uploadedBy}</Detail>
        <Detail label="Uploaded">
          {dateLong(r.file.date)}, {time(r.file.date)}
        </Detail>
        <Detail label="Job">
          <Link href={`/jobs/${r.job.id}`} className="font-mono text-accent hover:underline">
            {r.job.id}
          </Link>{" "}
          <span className="text-fg-muted">{r.job.title}</span>
        </Detail>
        <Detail label="Customer">{r.job.customer}</Detail>
      </dl>
    </Modal>
  );
}

function Detail({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <dt className="label-caps">{label}</dt>
      <dd className="mt-0.5">{children}</dd>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Upload

const CAD_EXT = ["stl", "3dm", "obj", "step", "stp", "igs", "iges", "dwg", "dxf", "jcd", "glb", "gltf", "3mf", "ply", "fbx"];
const SHEET_EXT = ["xls", "xlsx", "csv", "tsv", "ods", "numbers"];
const AUDIO_EXT = ["mp3", "wav", "m4a", "aac", "ogg", "opus", "flac"];

function detectKind(f: File): FileKind {
  const e = f.name.split(".").pop()?.toLowerCase() ?? "";
  if (f.type.startsWith("image/")) return "image";
  if (f.type.startsWith("audio/") || AUDIO_EXT.includes(e)) return "audio";
  if (SHEET_EXT.includes(e)) return "sheet";
  if (CAD_EXT.includes(e)) return "cad";
  return "pdf";
}

const sizeLabel = (bytes: number) =>
  bytes >= 1_048_576 ? `${(bytes / 1_048_576).toFixed(1)} MB` : `${Math.max(1, Math.round(bytes / 1024))} KB`;

const readAsDataUrl = (f: Blob) =>
  new Promise<string>((resolve, reject) => {
    const r = new FileReader();
    r.onload = () => resolve(r.result as string);
    r.onerror = () => reject(r.error);
    r.readAsDataURL(f);
  });

/** Read an image as a data URL, downscaling large photos so localStorage doesn't overflow. */
async function readImage(f: File): Promise<string> {
  const src = await readAsDataUrl(f);
  if (f.size < 300_000 || f.type === "image/svg+xml" || f.type === "image/gif") return src;
  const img = await new Promise<HTMLImageElement>((resolve, reject) => {
    const i = new window.Image();
    i.onload = () => resolve(i);
    i.onerror = reject;
    i.src = src;
  });
  const scale = Math.min(1, 1600 / Math.max(img.width, img.height));
  const canvas = document.createElement("canvas");
  canvas.width = Math.round(img.width * scale);
  canvas.height = Math.round(img.height * scale);
  const ctx = canvas.getContext("2d");
  if (!ctx) return src;
  ctx.fillStyle = "#fff";
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
  const out = canvas.toDataURL("image/jpeg", 0.85);
  return out.length < src.length ? out : src;
}

function UploadModal({ jobs, onClose }: { jobs: Job[]; onClose: () => void }) {
  const addFile = useStore((s) => s.addFile);
  const toast = useToast();
  const [jobId, setJobId] = useState(jobs[0]?.id ?? "");
  const [file, setFile] = useState<File | null>(null);
  const [kind, setKind] = useState<FileKind>("image");
  const [dataUrl, setDataUrl] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const choose = async (f: File | undefined) => {
    setError(null);
    setDataUrl(null);
    setFile(f ?? null);
    if (!f) return;
    setKind(detectKind(f));
    if (!f.type.startsWith("image/")) return;
    setBusy(true);
    try {
      setDataUrl(await readImage(f));
    } catch {
      setError("Couldn’t read that image. The file details will still be saved.");
    } finally {
      setBusy(false);
    }
  };

  const submit = () => {
    if (!file || !jobId) return;
    try {
      addFile(jobId, { name: file.name, kind, dataUrl, sizeLabel: sizeLabel(file.size) });
    } catch {
      setError("Browser storage is full. Try a smaller file.");
      return;
    }
    toast(`Uploaded ${file.name} to ${jobId}`);
    onClose();
  };

  const k = KIND[kind];
  return (
    <Modal
      open
      onClose={onClose}
      title="Upload file"
      subtitle="Attach a file to a job. It appears in the job’s files and thread."
      footer={
        <>
          <Button variant="secondary" onClick={onClose}>
            Cancel
          </Button>
          <Button icon={<Upload size={16} />} disabled={!file || !jobId || busy} onClick={submit}>
            {busy ? "Reading…" : "Upload"}
          </Button>
        </>
      }
    >
      <div className="space-y-4">
        <Field label="Job">
          <Select value={jobId} onChange={(e) => setJobId(e.target.value)}>
            {jobs.map((j) => (
              <option key={j.id} value={j.id}>
                {j.id} — {j.title}
              </option>
            ))}
          </Select>
        </Field>

        <div>
          <span className="label-caps mb-1.5 block">File</span>
          <div className="relative flex flex-col items-center justify-center gap-2 rounded-xl border-2 border-dashed border-border-strong bg-surface-low px-4 py-7 text-center transition focus-within:border-accent hover:border-accent">
            <CloudUpload size={28} className="text-fg-faint" />
            <p className="text-sm">
              <span className="font-semibold text-accent">Choose a file</span> or drag it here
            </p>
            <p className="text-xs text-fg-faint">Images, CAD, PDF, spreadsheets or audio</p>
            <input
              type="file"
              aria-label="Choose a file"
              onChange={(e) => choose(e.target.files?.[0])}
              className="absolute inset-0 cursor-pointer opacity-0"
            />
          </div>
        </div>

        {file && (
          <div className="flex items-center gap-3 rounded-xl border border-border p-3">
            {dataUrl ? (
              <Thumb src={dataUrl} alt={file.name} className="size-14 shrink-0" />
            ) : (
              <div className={cn("flex size-14 shrink-0 items-center justify-center rounded-lg", k.bg, k.text)}>
                <k.icon size={26} strokeWidth={1.5} />
              </div>
            )}
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-semibold">{file.name}</p>
              <p className="font-mono text-xs text-fg-muted">{sizeLabel(file.size)}</p>
            </div>
            <div className="w-28 shrink-0">
              <Select aria-label="File type" value={kind} onChange={(e) => setKind(e.target.value as FileKind)}>
                {KINDS.map((x) => (
                  <option key={x} value={x}>
                    {KIND[x].label}
                  </option>
                ))}
              </Select>
            </div>
          </div>
        )}
        {error && <p className="text-sm text-danger">{error}</p>}
      </div>
    </Modal>
  );
}
