import type { Metadata } from "next";
import { notFound } from "next/navigation";
import Link from "next/link";
import { POSTS, getPost } from "../posts";
import { POST_CONTENT } from "../content";

type RouteParams = { slug: string };

export async function generateStaticParams(): Promise<RouteParams[]> {
  return POSTS.map((p) => ({ slug: p.slug }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<RouteParams>;
}): Promise<Metadata> {
  const { slug } = await params;
  const post = getPost(slug);
  if (!post) return {};
  return {
    title: post.title,
    description: post.description,
    openGraph: {
      title: post.title,
      description: post.description,
      type: "article",
      publishedTime: post.date,
    },
  };
}

export default async function BlogPostPage({
  params,
}: {
  params: Promise<RouteParams>;
}) {
  const { slug } = await params;
  const post = getPost(slug);
  if (!post) notFound();

  const Content = POST_CONTENT[slug];

  const idx = POSTS.findIndex((p) => p.slug === slug);
  const prev = idx > 0 ? POSTS[idx - 1] : undefined;
  const next = idx < POSTS.length - 1 ? POSTS[idx + 1] : undefined;

  return (
    <article className="blog-shell container">
      <div className="blog-post-head">
        <div className="meta">
          <span style={{ color: "var(--accent)", fontWeight: 600 }}>{post.category}</span>
          {" · "}
          {new Date(post.date).toLocaleDateString("en-US", { month: "long", day: "numeric", year: "numeric" })}
          {" · "}
          {post.readTime} read
        </div>
        <h1>{post.title}</h1>
        <p className="lede">{post.description}</p>
      </div>
      <div className="blog-body prose">
        {Content ? <Content /> : <p>Post coming soon.</p>}
      </div>
      <div className="docs-pagination" style={{ maxWidth: 740, margin: "48px auto 0" }}>
        {prev ? (
          <Link className="docs-page-link" href={`/blog/${prev.slug}`}>
            <div className="label">← Older</div>
            <div className="title">{prev.title}</div>
          </Link>
        ) : <div />}
        {next ? (
          <Link className="docs-page-link next" href={`/blog/${next.slug}`}>
            <div className="label">Newer →</div>
            <div className="title">{next.title}</div>
          </Link>
        ) : <div />}
      </div>
    </article>
  );
}
