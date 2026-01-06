-- Package history database schema

CREATE TABLE IF NOT EXISTS package_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    package_name TEXT NOT NULL,
    generation_num INTEGER NOT NULL,
    profile_type TEXT NOT NULL,
    version TEXT NOT NULL,
    event TEXT NOT NULL,
    date TEXT NOT NULL,
    git_commit TEXT,
    store_path TEXT,
    generation_exists INTEGER DEFAULT 1,
    scan_timestamp TEXT NOT NULL,
    UNIQUE(package_name, generation_num, profile_type)
);

CREATE TABLE IF NOT EXISTS scan_metadata (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    scan_type TEXT NOT NULL,
    package_name TEXT,
    profile_type TEXT,
    total_generations INTEGER,
    packages_scanned INTEGER,
    scan_timestamp TEXT NOT NULL,
    duration_seconds INTEGER
);

CREATE INDEX IF NOT EXISTS idx_package_name ON package_history(package_name);
CREATE INDEX IF NOT EXISTS idx_generation ON package_history(generation_num);
CREATE INDEX IF NOT EXISTS idx_profile ON package_history(profile_type);
CREATE INDEX IF NOT EXISTS idx_exists ON package_history(generation_exists);
CREATE INDEX IF NOT EXISTS idx_date ON package_history(date);

