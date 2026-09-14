# Drop-in: memory-safe Prisma db push

Copy to a monorepo as `scripts/prisma-push-safe.mjs`, then:

```json
"push": "node ../../scripts/prisma-push-safe.mjs"
```

Adjust `schemaPath` / `prismaJs` paths if your layout differs from `packages/database/prisma/schema.prisma`.

See the source file next to this README.
