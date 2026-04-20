-- CreateTable
CREATE TABLE "SchemaMigrationAudit" (
    "id" TEXT NOT NULL,
    "migrationName" TEXT NOT NULL,
    "appliedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "targetRole" TEXT NOT NULL,

    CONSTRAINT "SchemaMigrationAudit_pkey" PRIMARY KEY ("id")
);
