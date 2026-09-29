import { JobDetailView } from "@/components/views/job-detail-view";

export const metadata = { title: "Job" };

export default async function Page(props: PageProps<"/jobs/[id]">) {
  const { id } = await props.params;
  return <JobDetailView id={decodeURIComponent(id)} />;
}
