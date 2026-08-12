import { z } from "zod";

/**
 * 釣果情報の新規登録用スキーマ。
 * 指示書58項の原則により、原文(original_text)と情報源URLを必須とし、
 * AIによる推測を混在させない「事実ベース」の投稿経路として扱う。
 */
export const createFishingReportSchema = z.object({
  sourceId: z.number().int().positive().optional(),
  sourceUrl: z.string().url("有効なURLを入力してください"),
  originalText: z.string().min(1, "原文を入力してください").max(5000),
  fishingDate: z.string().datetime().optional(),
  publishedAt: z.string().datetime().optional(),
  prefectureId: z.number().int().positive(),
  cityId: z.number().int().positive().optional(),
  fishingSpotId: z.number().int().positive().optional(),
  fishSpeciesId: z.number().int().positive(),
  catchCount: z.number().int().nonnegative().optional(),
  minSize: z.number().nonnegative().optional(),
  maxSize: z.number().nonnegative().optional(),
  averageSize: z.number().nonnegative().optional(),
  sizeUnit: z.enum(["cm", "mm", "kg", "g"]).optional(),
  fishingMethodId: z.number().int().positive().optional(),
  baitRaw: z.string().max(200).optional(),
  lureRaw: z.string().max(200).optional(),
  tackleRawText: z.string().max(2000).optional(),
  timeOfDay: z.string().max(50).optional(),
});

export type CreateFishingReportInput = z.infer<typeof createFishingReportSchema>;
