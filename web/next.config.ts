import type { NextConfig } from "next";

const konfiguration: NextConfig = {
  reactStrictMode: true,
  // Die Anwendung liest ausschliesslich ueber die Rolle `authenticated`. Ein
  // Dienstschluessel gehoert nie ins Bundle - scripts/kein-dienstschluessel.mjs
  // prueft das nach jedem Build.
  env: {},
};

export default konfiguration;
