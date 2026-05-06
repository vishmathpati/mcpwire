import type { Metadata } from "next";
import Link from "next/link";
import { POSTS } from "./posts";

export const metadata: Metadata = {
  title: "Blog",
  description:
    "News, guides, and deep dives on Model Context Protocol, MCP servers, and the AI developer tools ecosystem.",
};

export default function BlogIndex() {
  const posts = [...POSTS].sort((a, b) => (a.date < b.date ? 1 : -1));
  return (
    <>
      <header className="page-hero container">
        <div className="tag">
          <span className="tag-dot" />
          <span>MCPBolt blog</span>
        </div>
        <h1>Signal, not noise</h1>
        <p className="sub">
          Long-form writing on Model Context Protocol, agentic AI tools, and the
          plumbing that actually makes developers productive.
        </p>
      </header>
      <div className="container">
        <div className="blog-grid">
          {posts.map((post) => (
            <Link key={post.slug} href={`/blog/${post.slug}`} className="blog-card">
              <div className="blog-card-meta">
                <span className="blog-card-category">{post.category}</span>
                <span>{new Date(post.date).toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" })}</span>
                <span>· {post.readTime}</span>
              </div>
              <h3>{post.title}</h3>
              <p>{post.description}</p>
              <div className="blog-card-read">Read post →</div>
            </Link>
          ))}
        </div>
      </div>
    </>
  );
}
