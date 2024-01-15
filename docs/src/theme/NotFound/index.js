import React, { useEffect, useState } from "react";
import { translate } from "@docusaurus/Translate";
import { PageMetadata } from "@docusaurus/theme-common";
import Layout from "@theme/Layout";
import NotFoundContent from "@theme/NotFound/Content";
import BrowserOnly from "@docusaurus/BrowserOnly";

import { useHistory } from "react-router-dom";

export default function Index() {
  const title = translate({
    id: "theme.NotFound.title",
    message: "Page Not Found",
  });

  const [hasChecked, setHasChecked] = useState(false);
  const [hasMounted, setHasMounted] = useState(false);

  const history = useHistory();

  useEffect(() => {
    setHasMounted(true);
    const currentUrl = window.location.href;
    if (window.location.pathname.includes("/t/")) {
      const segments = window.location.pathname.split("/");
      const last = segments.pop() || segments.pop(); // Handle potential trailing slash
      console.log("Last: " + last);
      let target = "";
      if (last.startsWith("ID")) {
        target = "/";
      } else if (last.startsWith("AADSC")) {
        target = "/AADSC/";
      } else {
        target = "/"; //Not a known test let's redirect to root to error out gracefully.
      }

      const newUrl = currentUrl.replace("/t/", `/docs/tests${target}`);
      console.log("Redirecting " + newUrl);
      window.history.replaceState({}, "", newUrl);
      const relativePath = new URL(newUrl).pathname;
      history.push(relativePath);
    }
  }, [history]);

  if (!hasMounted) {
    return null;
  }

  if (hasChecked) {
    return (
      <>
        <BrowserOnly fallback={<div></div>}>
          <PageMetadata title={title} />
          <Layout>
            <NotFoundContent />
          </Layout>
        </BrowserOnly>
      </>
    );
  }
}
