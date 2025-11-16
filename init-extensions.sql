-- Enable PostGIS extension (includes geometry, geography, and raster support)
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;

-- Enable TimescaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Enable pgvector extension (for vector similarity search)
CREATE EXTENSION IF NOT EXISTS vector;

-- Enable pg_search extension (for BM25 full-text search)
CREATE EXTENSION IF NOT EXISTS pg_search;

-- Display installed extensions
SELECT extname, extversion FROM pg_extension;