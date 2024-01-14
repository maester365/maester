import clsx from 'clsx';
import Heading from '@theme/Heading';
import styles from './styles.module.css';

const FeatureList = [
  {
    title: 'Ready made tests',
    Svg: require('@site/static/img/feature_tests.svg').default,
    description: (
      <>
        Maester comes with a collection of ready to use tests to
        help you get started with validating your tenant configuration.
      </>
    ),
  },
  {
    title: 'Easy to customize',
    Svg: require('@site/static/img/feature_customize.svg').default,
    description: (
      <>
        Since Maester is built using Pester and Microsoft Graph,
        you can write your own custom tests to validate the settings that are most important to you.
      </>
    ),
  },
  {
    title: 'Continous monitoring',
    Svg: require('@site/static/img/feature_monitor.svg').default,
    description: (
      <>
        Set up continous monitoring of your tenant configuration 
        using your favorite CI/CD pipeline. Configure alerts to get notified as soon as your 
        tenant configuration drifts away from your desired state.
      </>
    ),
  },
];

function Feature({Svg, title, description}) {
  return (
    <div className={clsx('col col--4')}>
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
