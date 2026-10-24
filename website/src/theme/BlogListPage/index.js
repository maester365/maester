// Swizzled from @docusaurus/theme-classic (BlogListPage) to show the blog as a grid of cards: the newest post
// as a wide card on the first page, then the rest in columns. Posts without an `image` in their front matter
// get the Maester flame on a dark tile instead of a picture.
import React from "react";
import clsx from "clsx";
import Link from "@docusaurus/Link";
import useDocusaurusContext from "@docusaurus/useDocusaurusContext";
import useBaseUrl from "@docusaurus/useBaseUrl";
import { PageMetadata, HtmlClassNameProvider, ThemeClassNames } from "@docusaurus/theme-common";
import Layout from "@theme/Layout";
import BlogListPaginator from "@theme/BlogListPaginator";
import SearchMetadata from "@theme/SearchMetadata";
import BlogListPageStructuredData from "@theme/BlogListPage/StructuredData";
import styles from "./styles.module.css";

const dateFormat = new Intl.DateTimeFormat("en-US", { day: "numeric", month: "short", year: "numeric", timeZone: "UTC" });

function PostImage({ image }) {
  const src = useBaseUrl(image ?? "");
  if (image) {
    return <img className={styles.image} src={src} alt="" loading="lazy" />;
  }
  return (
    <div className={styles.tile} aria-hidden="true">
      <img className={styles.tileLogo} src={useBaseUrl("/img/logo.svg")} alt="" />
    </div>
  );
}

function PostCard({ content, featured }) {
  const { metadata, assets, frontMatter } = content;
  const { permalink, title, description, date, readingTime, authors } = metadata;
  const image = assets.image ?? frontMatter.image;
  return (
    <article className={clsx(styles.card, featured && styles.featured)}>
      <Link to={permalink} className={styles.media} tabIndex={-1} aria-hidden="true">
        <PostImage image={image} />
      </Link>
      <div className={styles.body}>
        <p className={styles.meta}>
          <time dateTime={date}>{dateFormat.format(new Date(date))}</time>
          {readingTime ? <span> · {Math.max(1, Math.round(readingTime))} min read</span> : null}
        </p>
        <h2 className={styles.title}>
          <Link to={permalink}>{title}</Link>
        </h2>
        {description ? <p className={styles.description}>{description}</p> : null}
        {authors.length > 0 && (
          <div className={styles.authors}>
            {authors.map((a) => (
              <span key={a.key ?? a.name} className={styles.author}>
                {a.imageURL ? <img src={a.imageURL} alt="" className={styles.avatar} loading="lazy" /> : null}
                {a.name}
              </span>
            ))}
          </div>
        )}
      </div>
    </article>
  );
}

function BlogListPageMetadata({ metadata }) {
  const {
    siteConfig: { title: siteTitle },
  } = useDocusaurusContext();
  const { blogDescription, blogTitle, permalink } = metadata;
  const title = permalink === "/" ? siteTitle : blogTitle;
  return (
    <>
      <PageMetadata title={title} description={blogDescription} />
      <SearchMetadata tag="blog_posts_list" />
    </>
  );
}

export default function BlogListPage(props) {
  const { metadata, items } = props;
  const firstPage = metadata.page === 1;
  const [first, ...rest] = items;
  const featured = firstPage ? first : null;
  const grid = firstPage ? rest : items;
  return (
    <HtmlClassNameProvider className={clsx(ThemeClassNames.wrapper.blogPages, ThemeClassNames.page.blogListPage)}>
      <BlogListPageMetadata {...props} />
      <BlogListPageStructuredData {...props} />
      <Layout>
        <main className={clsx("container", styles.page)}>
          <header className={styles.header}>
            <h1>Blog</h1>
            <p>
              News, releases and guides from the Maester team. <Link to="/blog/archive">All posts by year</Link>
            </p>
          </header>
          {featured && <PostCard content={featured.content} featured />}
          <div className={styles.grid}>
            {grid.map(({ content }) => (
              <PostCard key={content.metadata.permalink} content={content} />
            ))}
          </div>
          <BlogListPaginator metadata={metadata} />
        </main>
      </Layout>
    </HtmlClassNameProvider>
  );
}
