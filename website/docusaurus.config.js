// @ts-check
// `@type` JSDoc annotations allow editor autocompletion and type checking
// (when paired with `@ts-check`).
// There are various equivalent ways to declare your Docusaurus config.
// See: https://docusaurus.io/docs/api/docusaurus-config

import { themes as prismThemes } from "prism-react-renderer";

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: "Maester",
  tagline: "Your Microsoft Security test automation framework!",
  favicon: "img/favicon.ico",

  // Set the production url of your site here
  url: "https://maester.dev",
  // Set the /<baseUrl>/ pathname under which your site is served
  // For GitHub pages deployment, it is often '/<projectName>/'
  baseUrl: "/",

  // GitHub pages deployment config.
  // If you aren't using GitHub pages, you don't need these.
  organizationName: "maester365", // Usually your GitHub org/user name.
  projectName: "maester", // Usually your repo name.

  onBrokenLinks: "throw",
  onBrokenMarkdownLinks: "warn",

  // Even if you don't use internationalization, you can use this field to set
  // useful metadata like html lang. For example, if your site is Chinese, you
  // may want to replace "en" with "zh-Hans".
  i18n: {
    defaultLocale: "en",
    locales: ["en"],
  },

  markdown: {
    mermaid: true,
  },
  themes: [
    "@docusaurus/theme-mermaid",
    "@easyops-cn/docusaurus-search-local",
  ],

  plugins: [
    [
      "posthog-docusaurus",
      {
        apiKey: "phc_VxA235FsdurMGycf9DHjlUeZeIhLuC7r11Ptum0WjRK",
        appUrl: "https://us.i.posthog.com", // optional, defaults to "https://us.i.posthog.com"
        enableInDevelopment: false, // optional
      },
    ],
  ],

  presets: [
    [
      "classic",
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          sidebarPath: "./sidebars.js",
          editUrl: "https://github.com/maester365/maester/tree/main/website",
        },
        blog: {
          blogSidebarTitle: 'All posts',
          blogSidebarCount: 'ALL',
        },
        theme: {
          customCss: "./src/css/custom.css",
        },
        googleTagManager: {
          containerId: 'GTM-TXV8GGWT',
        },
        gtag: {
          trackingID: 'G-LKBLBBCLH0',
          anonymizeIP: true,
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      // Replace with your project's social card
      image: "img/maester-social-card.jpg",
      navbar: {
        title: "Maester",
        logo: {
          alt: "Maester Logo",
          src: "img/logo.svg",
        },
        items: [
          {
            type: "docSidebar",
            sidebarId: "siteSidebar",
            position: "left",
            label: "Docs",
          },
          {
            type: "doc",
            position: "left",
            docId: "tests/overview",
            label: "Tests",
          },
          {
            type: "doc",
            position: "left",
            docId: "commands/commands-overview",
            label: "Commands",
          },
          { to: 'blog', label: 'Blog', position: 'left' },
          {
            "aria-label": "GitHub Repository",
            className: "navbar--github-link",
            href: "https://github.com/maester365/maester",
            position: "right",
          },
        ],
      },
      footer: {
        style: "dark",
        links: [
          {
            title: "Docs",
            items: [
              {
                label: "Tests",
                to: "/docs/intro",
              },
            ],
          },
          {
            title: "Community",
            items: [
              {
                label: "Discord",
                href: "https://discord.maester.dev/",
              },
              {
                label: "Twitter",
                href: "https://twitter.com/maester365",
              },
            ],
          },
          {
            title: "More",
            items: [
              {
                label: "Bluesky",
                href: "https://bsky.app/profile/maester.dev",
              },
              {
                label: "GitHub",
                href: "https://github.com/maester365/maester",
              },
            ],
          },
        ],
        copyright: `Copyright © ${new Date().getFullYear()} Maester Team`,
      },
      prism: {
        theme: prismThemes.shadesOfPurple,
        darkTheme: prismThemes.shadesOfPurple,
        additionalLanguages: ["powershell"],
      },
      colorMode: {
        defaultMode: "light",
        disableSwitch: false,
        respectPrefersColorScheme: true,
      },
    }),
};

export default config;
