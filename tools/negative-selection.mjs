export function selectNegativeChecks(checks, packages) {
  for (const name of packages) {
    if (!checks.some(check => check.package === name)) {
      throw new Error("Unknown negative-control package: " + name);
    }
  }
  return packages.length === 0 ? checks : checks.filter(check => packages.includes(check.package));
}
