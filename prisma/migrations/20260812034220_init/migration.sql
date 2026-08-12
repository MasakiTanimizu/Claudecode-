-- CreateTable
CREATE TABLE "prefectures" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "name_kana" TEXT,
    "is_active" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "prefectures_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cities" (
    "id" SERIAL NOT NULL,
    "prefecture_id" INTEGER NOT NULL,
    "name" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "cities_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "fishing_spots" (
    "id" SERIAL NOT NULL,
    "prefecture_id" INTEGER NOT NULL,
    "city_id" INTEGER,
    "name" TEXT NOT NULL,
    "latitude" DECIMAL(9,6),
    "longitude" DECIMAL(9,6),
    "spot_type" TEXT,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "fishing_spots_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "fish_species" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "name_kana" TEXT,
    "category" TEXT,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "fish_species_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "fishing_methods" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "fishing_methods_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "baits" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "category" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "baits_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "lures" (
    "id" SERIAL NOT NULL,
    "maker" TEXT,
    "name" TEXT NOT NULL,
    "lure_type" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "lures_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "rods" (
    "id" SERIAL NOT NULL,
    "maker" TEXT,
    "name" TEXT NOT NULL,
    "length" TEXT,
    "action" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "rods_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "reels" (
    "id" SERIAL NOT NULL,
    "maker" TEXT,
    "name" TEXT NOT NULL,
    "size" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "reels_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sources" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "url" TEXT NOT NULL,
    "source_type" TEXT NOT NULL,
    "fetch_method" TEXT,
    "fetch_allowed" BOOLEAN NOT NULL DEFAULT false,
    "trust_score" INTEGER NOT NULL DEFAULT 50,
    "last_fetched_at" TIMESTAMP(3),
    "last_error" TEXT,
    "notes" TEXT,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "sources_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "fishing_reports" (
    "id" SERIAL NOT NULL,
    "source_id" INTEGER,
    "source_url" TEXT NOT NULL,
    "published_at" TIMESTAMP(3),
    "fishing_date" TIMESTAMP(3),
    "prefecture_id" INTEGER NOT NULL,
    "city_id" INTEGER,
    "fishing_spot_id" INTEGER,
    "fish_species_id" INTEGER NOT NULL,
    "catch_count" INTEGER,
    "min_size" DECIMAL(6,2),
    "max_size" DECIMAL(6,2),
    "average_size" DECIMAL(6,2),
    "size_unit" TEXT,
    "size_estimation_method" TEXT NOT NULL DEFAULT 'UNKNOWN',
    "fishing_method_id" INTEGER,
    "bait_id" INTEGER,
    "bait_raw" TEXT,
    "lure_id" INTEGER,
    "lure_raw" TEXT,
    "rod_id" INTEGER,
    "reel_id" INTEGER,
    "line_raw" TEXT,
    "leader_raw" TEXT,
    "tackle_raw_text" TEXT,
    "time_of_day" TEXT,
    "original_text" TEXT NOT NULL,
    "confidence_score" DECIMAL(5,2) NOT NULL DEFAULT 50,
    "is_duplicate" BOOLEAN NOT NULL DEFAULT false,
    "duplicate_of_id" INTEGER,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "fishing_reports_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "images" (
    "id" SERIAL NOT NULL,
    "fishing_report_id" INTEGER NOT NULL,
    "url" TEXT NOT NULL,
    "license_note" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "images_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ai_analysis" (
    "id" SERIAL NOT NULL,
    "fishing_report_id" INTEGER NOT NULL,
    "model_name" TEXT NOT NULL,
    "model_version" TEXT NOT NULL,
    "input" JSONB NOT NULL,
    "output" JSONB NOT NULL,
    "confidence" DECIMAL(5,2) NOT NULL,
    "executed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ai_analysis_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ai_predictions" (
    "id" SERIAL NOT NULL,
    "fish_species_id" INTEGER NOT NULL,
    "fishing_spot_id" INTEGER,
    "target_date" DATE NOT NULL,
    "expectation_score" INTEGER NOT NULL,
    "basis" JSONB NOT NULL,
    "model_name" TEXT NOT NULL,
    "model_version" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ai_predictions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "weather" (
    "id" SERIAL NOT NULL,
    "fishing_spot_id" INTEGER NOT NULL,
    "observed_at" TIMESTAMP(3) NOT NULL,
    "temperature" DECIMAL(4,1),
    "water_temperature" DECIMAL(4,1),
    "precipitation" DECIMAL(5,1),
    "condition" TEXT,
    "wind_speed" DECIMAL(4,1),
    "wind_direction" TEXT,
    "wave_height" DECIMAL(4,1),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "weather_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "tide" (
    "id" SERIAL NOT NULL,
    "fishing_spot_id" INTEGER NOT NULL,
    "date" DATE NOT NULL,
    "tide_type" TEXT,
    "high_tide_times" JSONB,
    "low_tide_times" JSONB,
    "moon_age" DECIMAL(4,1),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "tide_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "news" (
    "id" SERIAL NOT NULL,
    "news_date" DATE NOT NULL,
    "title" TEXT NOT NULL,
    "body_markdown" TEXT NOT NULL,
    "highlights" JSONB,
    "published_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "news_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "users" (
    "id" SERIAL NOT NULL,
    "email" TEXT NOT NULL,
    "display_name" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notifications" (
    "id" SERIAL NOT NULL,
    "user_id" INTEGER NOT NULL,
    "type" TEXT NOT NULL,
    "message" TEXT NOT NULL,
    "is_read" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_fishing_logs" (
    "id" SERIAL NOT NULL,
    "user_id" INTEGER NOT NULL,
    "fishing_date" TIMESTAMP(3) NOT NULL,
    "fishing_spot_id" INTEGER,
    "fish_species_id" INTEGER,
    "catch_count" INTEGER,
    "size" DECIMAL(6,2),
    "comment" TEXT,
    "trust_score" DECIMAL(5,2) NOT NULL DEFAULT 50,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_fishing_logs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "prefectures_name_key" ON "prefectures"("name");

-- CreateIndex
CREATE UNIQUE INDEX "cities_prefecture_id_name_key" ON "cities"("prefecture_id", "name");

-- CreateIndex
CREATE UNIQUE INDEX "fish_species_name_key" ON "fish_species"("name");

-- CreateIndex
CREATE UNIQUE INDEX "fishing_methods_name_key" ON "fishing_methods"("name");

-- CreateIndex
CREATE UNIQUE INDEX "baits_name_key" ON "baits"("name");

-- CreateIndex
CREATE UNIQUE INDEX "sources_url_key" ON "sources"("url");

-- CreateIndex
CREATE INDEX "fishing_reports_fishing_date_idx" ON "fishing_reports"("fishing_date");

-- CreateIndex
CREATE INDEX "fishing_reports_fish_species_id_idx" ON "fishing_reports"("fish_species_id");

-- CreateIndex
CREATE INDEX "fishing_reports_fishing_spot_id_idx" ON "fishing_reports"("fishing_spot_id");

-- CreateIndex
CREATE INDEX "fishing_reports_prefecture_id_idx" ON "fishing_reports"("prefecture_id");

-- CreateIndex
CREATE INDEX "ai_predictions_target_date_idx" ON "ai_predictions"("target_date");

-- CreateIndex
CREATE INDEX "weather_fishing_spot_id_observed_at_idx" ON "weather"("fishing_spot_id", "observed_at");

-- CreateIndex
CREATE UNIQUE INDEX "tide_fishing_spot_id_date_key" ON "tide"("fishing_spot_id", "date");

-- CreateIndex
CREATE UNIQUE INDEX "news_news_date_key" ON "news"("news_date");

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- AddForeignKey
ALTER TABLE "cities" ADD CONSTRAINT "cities_prefecture_id_fkey" FOREIGN KEY ("prefecture_id") REFERENCES "prefectures"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "fishing_spots" ADD CONSTRAINT "fishing_spots_prefecture_id_fkey" FOREIGN KEY ("prefecture_id") REFERENCES "prefectures"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "fishing_spots" ADD CONSTRAINT "fishing_spots_city_id_fkey" FOREIGN KEY ("city_id") REFERENCES "cities"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "fishing_reports" ADD CONSTRAINT "fishing_reports_source_id_fkey" FOREIGN KEY ("source_id") REFERENCES "sources"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "fishing_reports" ADD CONSTRAINT "fishing_reports_prefecture_id_fkey" FOREIGN KEY ("prefecture_id") REFERENCES "prefectures"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "fishing_reports" ADD CONSTRAINT "fishing_reports_city_id_fkey" FOREIGN KEY ("city_id") REFERENCES "cities"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "fishing_reports" ADD CONSTRAINT "fishing_reports_fishing_spot_id_fkey" FOREIGN KEY ("fishing_spot_id") REFERENCES "fishing_spots"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "fishing_reports" ADD CONSTRAINT "fishing_reports_fish_species_id_fkey" FOREIGN KEY ("fish_species_id") REFERENCES "fish_species"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "fishing_reports" ADD CONSTRAINT "fishing_reports_fishing_method_id_fkey" FOREIGN KEY ("fishing_method_id") REFERENCES "fishing_methods"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "fishing_reports" ADD CONSTRAINT "fishing_reports_bait_id_fkey" FOREIGN KEY ("bait_id") REFERENCES "baits"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "fishing_reports" ADD CONSTRAINT "fishing_reports_lure_id_fkey" FOREIGN KEY ("lure_id") REFERENCES "lures"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "fishing_reports" ADD CONSTRAINT "fishing_reports_rod_id_fkey" FOREIGN KEY ("rod_id") REFERENCES "rods"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "fishing_reports" ADD CONSTRAINT "fishing_reports_reel_id_fkey" FOREIGN KEY ("reel_id") REFERENCES "reels"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "images" ADD CONSTRAINT "images_fishing_report_id_fkey" FOREIGN KEY ("fishing_report_id") REFERENCES "fishing_reports"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_analysis" ADD CONSTRAINT "ai_analysis_fishing_report_id_fkey" FOREIGN KEY ("fishing_report_id") REFERENCES "fishing_reports"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_predictions" ADD CONSTRAINT "ai_predictions_fish_species_id_fkey" FOREIGN KEY ("fish_species_id") REFERENCES "fish_species"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_predictions" ADD CONSTRAINT "ai_predictions_fishing_spot_id_fkey" FOREIGN KEY ("fishing_spot_id") REFERENCES "fishing_spots"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "weather" ADD CONSTRAINT "weather_fishing_spot_id_fkey" FOREIGN KEY ("fishing_spot_id") REFERENCES "fishing_spots"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tide" ADD CONSTRAINT "tide_fishing_spot_id_fkey" FOREIGN KEY ("fishing_spot_id") REFERENCES "fishing_spots"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_fishing_logs" ADD CONSTRAINT "user_fishing_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_fishing_logs" ADD CONSTRAINT "user_fishing_logs_fishing_spot_id_fkey" FOREIGN KEY ("fishing_spot_id") REFERENCES "fishing_spots"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_fishing_logs" ADD CONSTRAINT "user_fishing_logs_fish_species_id_fkey" FOREIGN KEY ("fish_species_id") REFERENCES "fish_species"("id") ON DELETE SET NULL ON UPDATE CASCADE;
