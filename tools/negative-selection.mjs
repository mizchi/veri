export function negativeControlTimeout(check, env = process.env) {
  const minimum = env.VERI_NEGATIVE_TIMEOUT_MS === undefined
    ? 60_000 : Number(env.VERI_NEGATIVE_TIMEOUT_MS);
  if (!Number.isInteger(minimum) || minimum <= 0 || minimum > 3_600_000) {
    throw new Error('Invalid VERI_NEGATIVE_TIMEOUT_MS');
  }
  return Math.max(check.timeoutMs ?? 60_000, minimum);
}

export function selectNegativeChecks(checks, packages) {
  for (const name of packages) {
    if (!checks.some(check => check.package === name)) {
      throw new Error("Unknown negative-control package: " + name);
    }
  }
  return packages.length === 0 ? checks : checks.filter(check => packages.includes(check.package));
}

export function shardNegativeChecks(checks, shard, total) {
  if (!Number.isInteger(total) || total <= 0 || total > checks.length ||
      !Number.isInteger(shard) || shard < 0 || shard >= total) {
    throw new Error('Invalid negative-control shard');
  }
  return checks.filter((_, index) => index % total === shard);
}
