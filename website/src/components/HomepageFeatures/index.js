import clsx from "clsx";
import Heading from "@theme/Heading";
import styles from "./styles.module.css";

const FeatureList = [
  {
    title: "Ready made tests",
    Svg: require("@site/static/img/home/feature_tests.svg").default,
    description: (
      <>
        Maester comes with a collection of ready to use tests to help you get
        started with validating your tenant's security configuration.
      </>
    ),
  },
  {
    title: "Confidently make changes",
    Svg: require("@site/static/img/home/feature_regression.svg").default,
    description: (
      <>
        Worried about introducing changes that might break your tenant's
        security configuration? Run regression tests to validate every change.
      </>
    ),
  },
  {
    title: "Continuous monitoring",
    Svg: require("@site/static/img/home/feature_monitor.svg").default,
    description: (
      <>
        Set up continuous monitoring of your tenant configuration using your
        favorite CI/CD pipeline and alert if any test fails.
      </>
    ),
  },
  {
    title: "Easy to customize",
    Svg: require("@site/static/img/home/feature_customize.svg").default,
    description: (
      <>
        Since Maester is built using Pester and Microsoft Graph, you can write
        your own tests to validate your tenant's security configuration.
      </>
    ),
  },
  {
    title: "Configuration guidance",
    Svg: require("@site/static/img/home/feature_guidance.svg").default,
    description: (
      <>
        Each test in Maester comes with details of the configuration settings
        and guidance on how to remediate any issues found.
      </>
    ),
  },
  {
    title: "Entra ID Security Config Analyzer",
    Svg: require("@site/static/img/home/feature_eidsca.svg").default,
    description: (
      <>
        Maester natively integrates Entra ID Security Config Analyzer to provide
        a comprehensive set of Entra ID checks that map to the MITRE ATT&CK framework.
      </>
    ),
  },
];

function Feature({ Svg, title, description }) {
  return (
    <div className={clsx("col col--4")}>
      <div className="text--center">
        <Svg className={styles.featureSvg} role="img" />
      </div>
      <div className="text--center padding-horiz--md">
        <Heading as="h3">{title}</Heading>
        <p>{description}</p>
      </div>
    </div>
  );
}

export default function HomepageFeatures() {
  return (
    <section className={styles.features}>
      <div className="container">
        <div className="row">
          {FeatureList.map((props, idx) => (
            <Feature key={idx} {...props} />
          ))}
        </div>
      </div>
    </section>
  );
}
