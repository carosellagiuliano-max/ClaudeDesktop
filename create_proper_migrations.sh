#!/bin/bash

# Create a file without views
echo "-- PART A: All tables, functions, triggers (NO VIEWS)" > migrations_part_a.sql
echo "-- Run this FIRST" >> migrations_part_a.sql
echo "" >> migrations_part_a.sql

# Create a file with only views  
echo "-- PART B: All views" > migrations_part_b.sql
echo "-- Run this SECOND (after Part A)" >> migrations_part_b.sql
echo "" >> migrations_part_b.sql

# Process each migration file
for file in supabase/migrations/*.sql; do
    echo "-- ================================================" >> migrations_part_a.sql
    echo "-- From: $file" >> migrations_part_a.sql
    echo "-- ================================================" >> migrations_part_a.sql
    
    # Use awk to separate views from other content
    awk '
    BEGIN { in_view = 0; view_content = "" }
    /^CREATE VIEW/ || /^CREATE OR REPLACE VIEW/ { 
        in_view = 1
        view_content = $0 "\n"
        next
    }
    in_view == 1 {
        view_content = view_content $0 "\n"
        if (/;[[:space:]]*$/) {
            print view_content >> "migrations_part_b.sql"
            print "" >> "migrations_part_b.sql"
            in_view = 0
            view_content = ""
        }
        next
    }
    /^COMMENT ON VIEW/ {
        print >> "migrations_part_b.sql"
        print "" >> "migrations_part_b.sql"
        next
    }
    { print >> "migrations_part_a.sql" }
    ' "$file"
done

echo "Done! Created migrations_part_a.sql and migrations_part_b.sql"
