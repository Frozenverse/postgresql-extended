# PostgreSQL Extended
- **PostgreSQL 16**: Latest stable version
- **PostGIS 3**: Spatial and geographic objects for PostgreSQL
- **TimescaleDB 2**: Time-series database built on PostgreSQL
- **pgvector**: Vector similarity search for AI/ML embeddings
- **pg_search**: BM25 full-text search (Elasticsearch alternative)

## Quick Start

### Using Docker Compose (Recommended)

1. Build and start the container:
```bash
docker-compose up -d
```

2. Connect to the database:
```bash
docker exec -it postgres-postgis-timescale psql -U postgres -d mydb
```

3. Verify extensions are installed:
```sql
SELECT extname, extversion FROM pg_extension;
```

### Using Docker CLI

1. Build the image:
```bash
docker build -t postgres-postgis-timescale .
```

2. Run the container:
```bash
docker run -d \
  --name postgres-postgis-timescale \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=mydb \
  -p 5432:5432 \
  postgres-postgis-timescale
```

## Configuration

### Environment Variables

- `POSTGRES_DB`: Database name (default: mydb)
- `POSTGRES_USER`: Database user (default: postgres)
- `POSTGRES_PASSWORD`: Database password (required)

### Customizing Extensions

Edit `init-extensions.sql` to add or remove extensions. The file runs automatically when the database is first created.

## Usage Examples

### PostGIS Example

```sql
-- Create a table with a geometry column
CREATE TABLE locations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    geom GEOMETRY(Point, 4326)
);

-- Insert a point (longitude, latitude)
INSERT INTO locations (name, geom) 
VALUES ('San Francisco', ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 4326));

-- Find locations within 100km of a point
SELECT name 
FROM locations 
WHERE ST_DWithin(
    geom::geography,
    ST_SetSRID(ST_MakePoint(-122.4, 37.7), 4326)::geography,
    100000
);
```

### TimescaleDB Example

```sql
-- Create a regular table
CREATE TABLE sensor_data (
    time TIMESTAMPTZ NOT NULL,
    sensor_id INTEGER,
    temperature DOUBLE PRECISION,
    humidity DOUBLE PRECISION
);

-- Convert to a hypertable (TimescaleDB)
SELECT create_hypertable('sensor_data', 'time');

-- Insert time-series data
INSERT INTO sensor_data VALUES
    (NOW(), 1, 22.5, 45.2),
    (NOW() - INTERVAL '1 hour', 1, 21.8, 46.1);

-- Query with time-series functions
SELECT time_bucket('1 hour', time) AS hour,
       sensor_id,
       AVG(temperature) AS avg_temp
FROM sensor_data
GROUP BY hour, sensor_id
ORDER BY hour DESC;
```

### pgvector Example

```sql
-- Create a table for storing embeddings
CREATE TABLE documents (
    id SERIAL PRIMARY KEY,
    content TEXT,
    embedding vector(1536)  -- OpenAI embeddings are 1536 dimensions
);

-- Insert documents with embeddings
INSERT INTO documents (content, embedding) VALUES
    ('The cat sits on the mat', '[0.1, 0.2, 0.3, ...]'),  -- Replace with actual embeddings
    ('A dog plays in the park', '[0.2, 0.1, 0.4, ...]');

-- Create an index for faster similarity search
CREATE INDEX ON documents USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- Find similar documents using cosine similarity
SELECT content, 
       1 - (embedding <=> '[0.15, 0.18, 0.35, ...]'::vector) AS similarity
FROM documents
ORDER BY embedding <=> '[0.15, 0.18, 0.35, ...]'::vector
LIMIT 5;

-- Using different distance metrics:
-- L2 distance (Euclidean): <->
-- Inner product: <#>
-- Cosine distance: <=>

-- Example with L2 distance
SELECT content
FROM documents
ORDER BY embedding <-> '[0.15, 0.18, 0.35, ...]'::vector
LIMIT 5;
```

### pg_search Example

```sql
-- Create a table with text content
CREATE TABLE articles (
    id SERIAL PRIMARY KEY,
    title TEXT,
    body TEXT,
    category TEXT,
    published_at TIMESTAMP,
    views INTEGER
);

-- Insert sample data
INSERT INTO articles (title, body, category, published_at, views) VALUES
    ('Introduction to PostgreSQL', 'PostgreSQL is a powerful open-source database...', 'Database', NOW(), 1000),
    ('Getting Started with Docker', 'Docker containers make deployment easy...', 'DevOps', NOW(), 500),
    ('Advanced SQL Techniques', 'Learn about window functions and CTEs...', 'Database', NOW(), 750);

-- Create a BM25 index for full-text search
CALL paradedb.create_bm25(
    index_name => 'articles_idx',
    table_name => 'articles',
    key_field => 'id',
    text_fields => paradedb.field('title') || paradedb.field('body'),
    numeric_fields => paradedb.field('views'),
    datetime_fields => paradedb.field('published_at')
);

-- Basic full-text search using BM25 ranking
SELECT * FROM articles_idx.search('postgresql OR docker');

-- Search with filters and sorting
SELECT * FROM articles_idx.search(
    query => 'database',
    limit_rows => 10
) WHERE category = 'Database';

-- Advanced search with boolean queries
SELECT * FROM articles_idx.search(
    '(title:postgresql OR body:sql) AND category:database'
);

-- Fuzzy search (handles typos)
SELECT * FROM articles_idx.search('postgre~');  -- Finds "PostgreSQL"

-- Phrase search
SELECT * FROM articles_idx.search('"open source database"');

-- Range queries on numeric/datetime fields
SELECT * FROM articles_idx.search('views:>500 AND published_at:[2024-01-01 TO 2025-12-31]');

-- Aggregations and faceting
SELECT category, COUNT(*) 
FROM articles_idx.search('database')
GROUP BY category;
```

### Combining Multiple Extensions

```sql
-- Create a table with both spatial and time-series data
CREATE TABLE weather_stations (
    time TIMESTAMPTZ NOT NULL,
    station_id INTEGER,
    location GEOMETRY(Point, 4326),
    temperature DOUBLE PRECISION,
    precipitation DOUBLE PRECISION
);

-- Convert to hypertable
SELECT create_hypertable('weather_stations', 'time');

-- Create spatial index
CREATE INDEX idx_weather_location ON weather_stations USING GIST(location);

-- Query: Find average temperature near a location over time
SELECT time_bucket('1 day', time) AS day,
       AVG(temperature) AS avg_temp
FROM weather_stations
WHERE ST_DWithin(
    location::geography,
    ST_SetSRID(ST_MakePoint(-122.4, 37.7), 4326)::geography,
    50000  -- 50km radius
)
AND time > NOW() - INTERVAL '7 days'
GROUP BY day
ORDER BY day DESC;
```

### Advanced: Semantic Search with Location and Time

```sql
-- Create a table for time-series documents with location and embeddings
CREATE TABLE articles (
    time TIMESTAMPTZ NOT NULL,
    title TEXT,
    content TEXT,
    location GEOMETRY(Point, 4326),
    embedding vector(1536)
);

-- Convert to hypertable for time-series optimization
SELECT create_hypertable('articles', 'time');

-- Create indexes
CREATE INDEX ON articles USING GIST(location);
CREATE INDEX ON articles USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- Insert sample data
INSERT INTO articles (time, title, content, location, embedding) VALUES
    (NOW(), 'Local Event', 'Community gathering in the park', 
     ST_SetSRID(ST_MakePoint(-122.4, 37.7), 4326), 
     '[0.1, 0.2, ...]'::vector);

-- Complex query: Find semantically similar articles near a location from the last week
WITH similar_docs AS (
    SELECT *, 
           1 - (embedding <=> '[0.15, 0.18, ...]'::vector) AS similarity
    FROM articles
    WHERE time > NOW() - INTERVAL '7 days'
    ORDER BY embedding <=> '[0.15, 0.18, ...]'::vector
    LIMIT 20
)
SELECT time_bucket('1 day', time) AS day,
       title,
       similarity,
       ST_Distance(location::geography, 
                   ST_SetSRID(ST_MakePoint(-122.4, 37.7), 4326)::geography) AS distance_meters
FROM similar_docs
WHERE ST_DWithin(
    location::geography,
    ST_SetSRID(ST_MakePoint(-122.4, 37.7), 4326)::geography,
    10000  -- 10km radius
)
ORDER BY similarity DESC, day DESC;
```

### Hybrid Search: Combining pg_search (BM25) with pgvector

```sql
-- Create a table for products with both text and embeddings
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name TEXT,
    description TEXT,
    category TEXT,
    price NUMERIC,
    embedding vector(1536)
);

-- Create BM25 index for keyword search
CALL paradedb.create_bm25(
    index_name => 'products_bm25',
    table_name => 'products',
    key_field => 'id',
    text_fields => paradedb.field('name') || paradedb.field('description'),
    numeric_fields => paradedb.field('price')
);

-- Create vector index for semantic search
CREATE INDEX ON products USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- Hybrid search: Combine keyword relevance with semantic similarity
WITH keyword_results AS (
    SELECT id, paradedb.score(id) as bm25_score
    FROM products_bm25.search('wireless headphones', limit_rows => 100)
),
semantic_results AS (
    SELECT id, 1 - (embedding <=> '[0.1, 0.2, ...]'::vector) as vector_score
    FROM products
    ORDER BY embedding <=> '[0.1, 0.2, ...]'::vector
    LIMIT 100
)
SELECT 
    p.*,
    COALESCE(k.bm25_score, 0) * 0.5 + COALESCE(s.vector_score, 0) * 0.5 as hybrid_score
FROM products p
LEFT JOIN keyword_results k ON p.id = k.id
LEFT JOIN semantic_results s ON p.id = s.id
WHERE k.id IS NOT NULL OR s.id IS NOT NULL
ORDER BY hybrid_score DESC
LIMIT 10;
```

## Use Cases

- **PostGIS**: Store and query geographic data (maps, locations, routes)
- **TimescaleDB**: Handle time-series data (metrics, IoT sensors, logs)
- **pgvector**: Semantic search, recommendation systems, RAG applications
- **pg_search**: Full-text search with relevance ranking, fuzzy matching, faceted search
- **Combined**: Build sophisticated applications like:
  - Location-based semantic search with time filtering
  - Content recommendation systems with geographic constraints
  - Real-time analytics dashboards with full-text search
  - E-commerce platforms with spatial, temporal, and semantic search

## Connecting from Applications

### Connection String
```
postgresql://postgres:postgres@localhost:5432/mydb
```

### Python (psycopg2)
```python
import psycopg2

conn = psycopg2.connect(
    host="localhost",
    port=5432,
    database="mydb",
    user="postgres",
    password="postgres"
)
```

### Node.js (pg)
```javascript
const { Client } = require('pg');

const client = new Client({
    host: 'localhost',
    port: 5432,
    database: 'mydb',
    user: 'postgres',
    password: 'postgres'
});

await client.connect();
```

## Data Persistence

Data is persisted in a Docker volume named `postgres_data`. To remove all data:

```bash
docker-compose down -v
```

## Troubleshooting

### Check if extensions are loaded
```bash
docker exec -it postgres-postgis-timescale psql -U postgres -d mydb -c "\dx"
```

### View logs
```bash
docker logs postgres-postgis-timescale
```

### Restart container
```bash
docker-compose restart
```

## Resources

- [PostGIS Documentation](https://postgis.net/documentation/)
- [TimescaleDB Documentation](https://docs.timescale.com/)
- [pgvector Documentation](https://github.com/pgvector/pgvector)
- [pg_search Documentation](https://docs.paradedb.com/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)