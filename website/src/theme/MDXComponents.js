import React from "react";
// Import the original mapper
import MDXComponents from "@theme-original/MDXComponents";
import { Icon } from "@iconify/react"; // Import the entire Iconify library.
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import { library } from "@fortawesome/fontawesome-svg-core";
import { fab } from "@fortawesome/free-brands-svg-icons";
import { fas } from "@fortawesome/free-solid-svg-icons";

export default {
  // Re-use the default mapping
  ...MDXComponents,
  FAIcon: FontAwesomeIcon, // Make the FontAwesomeIcon component available in MDX as <faicon />.
  IIcon: Icon, // Make the iconify Icon component available in MDX as <icon />.
};
